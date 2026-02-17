# frozen_string_literal: true

##
# Controller for application projects.
#
class ProjectsController < ApplicationController
  include Exportable
  include ProjectMemberConstants

  before_action :set_project, only: %i[show update destroy export import_backup]
  before_action :set_project_permissions, only: %i[show]
  before_action :authorize_admin_project, only: %i[update destroy import_backup]
  before_action :authorize_viewer_project, only: %i[show export]
  before_action :authorize_logged_in, only: %i[index search]
  before_action :authorize_admin_or_create_permission_enabled, only: %i[create]
  before_action :check_permission_to_update, only: %i[update]

  def index
    @projects = current_user.available_projects.eager_load(:memberships).alphabetical.as_json(methods: %i[memberships])
    @projects.each do |project|
      project['admin'] = project['memberships'].any? do |m|
        m['role'] == PROJECT_MEMBER_ADMINS && m['user_id'] == current_user.id
      end
      project['is_member'] = project['memberships'].any? do |m|
        m['user_id'] == current_user.id
      end || current_user.admin
      project['access_request_id'] = current_user.access_requests.find_by(project_id: project['id'])&.id
    end
    respond_to do |format|
      format.html
      format.json do
        render json: @projects
      end
    end
  end

  def search
    query = params[:q]
    projects = current_user.available_projects
                           .joins(components: :based_on)
                           .and(SecurityRequirementsGuide.where(srg_id: query))
                           .limit(10)
                           .distinct
                           .pluck(:id, :name)
    render json: {
      projects: projects
    }
  end

  def show
    # Setting current_user allows `available_components` to be filtered down only to the
    # projects that a user has permissions to access
    @project.current_user = current_user
    @project_json = @project.to_json(
      methods: %i[histories memberships metadata components available_components available_members details users
                  access_requests]
    )
    respond_to do |format|
      format.html
      format.json { render json: @project_json }
    end
  end

  def create
    project = Project.new(
      name: new_project_params[:name],
      description: new_project_params[:description],
      memberships_attributes: [{ user: current_user, role: PROJECT_MEMBER_ADMINS }],
      visibility: new_project_params[:visibility]
    )
    project.project_metadata_attributes = { data: { 'Slack Channel ID' => new_project_params[:slack_channel_id] } } if new_project_params[:slack_channel_id].present?

    # First save ensures base Project is acceptable.
    if project.save
      send_slack_notification(:create_project, project) if Settings.slack.enabled

      respond_to do |format|
        format.html { redirect_to project }
        format.json { render json: { redirect_url: project_path(project), toast: 'Successfully created project' } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to create project. #{project.errors.full_messages}"
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not create project.',
              message: project.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  # Update project and response with json
  def update
    notification_types = []
    notification_types << :rename_project if project_name_changed?(@project.name)
    notification_types << :change_visibility if project_visibility_changed?(@project.visibility)
    if @project.update(project_params)
      if Settings.slack.enabled
        notification_types.each do |type|
          send_slack_notification(type, @project)
        end
      end
      render json: { toast: 'Successfully updated project' }
    else
      render json: {
        toast: {
          title: 'Could not update project.',
          message: @project.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @project.destroy
      send_slack_notification(:remove_project, @project) if Settings.slack.enabled
      respond_to do |format|
        format.html do
          flash.notice = 'Successfully removed project.'
          redirect_to action: 'index'
        end
        format.json { render json: { toast: 'Successfully removed project.' } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to remove project. #{@project.errors.full_messages}"
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not remove project.',
              message: @project.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def export
    # Using class variable @@components_to_export here to save params[:component_ids] value in memory,
    # because format.html below triggers a redirect to this same action controller
    # causing to lose the :component_ids param.

    # rubocop:disable Style/ClassVars
    @@components_to_export = params[:component_ids] if params[:component_ids].present?
    # rubocop:enable Style/ClassVars

    export_type = params[:type]&.to_sym
    export_mode = params[:mode]&.to_sym

    # Legacy support: disa_excel → vendor_submission + excel
    if export_type == :disa_excel
      export_type = :excel
      export_mode = :vendor_submission
    end

    unless %i[csv excel xccdf inspec json_archive].include?(export_type)
      render json: {
        toast: {
          title: 'Export error',
          message: "Unsupported export type: #{export_type}",
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    respond_to do |format|
      format.html do
        case export_type
        when :csv
          component_ids = resolve_component_ids
          components = component_ids ? @project.components.where(id: component_ids) : @project.components
          if components.size == 1
            perform_export(
              exportable: components.first, mode: :working_copy, format: :csv,
              filename: "#{@project.name}-#{components.first.prefix}.csv"
            )
          else
            perform_export(
              exportable: components.to_a, mode: :working_copy, format: :csv,
              zip_filename: "#{@project.name}.zip"
            )
          end
        when :excel
          mode = export_mode || :working_copy
          filename = mode == :vendor_submission ? "#{@project.name}_DISA.xlsx" : "#{@project.name}.xlsx"
          perform_export(
            exportable: @project, mode: mode, format: :excel,
            component_ids: resolve_component_ids,
            filename: filename
          )
        when :xccdf
          perform_export(
            exportable: @project, mode: export_mode || :published_stig, format: :xccdf,
            component_ids: resolve_component_ids,
            zip_filename: "#{@project.name}.zip"
          )
        when :inspec
          perform_export(
            exportable: @project, mode: :published_stig, format: :inspec,
            component_ids: resolve_component_ids,
            zip_filename: "#{@project.name}_inspec.zip"
          )
        when :json_archive
          perform_export(
            exportable: @project, mode: :backup, format: :json_archive,
            component_ids: resolve_component_ids,
            zip_filename: "vulcan-backup-#{@project.name}-#{Date.current}.zip"
          )
        end
      end
      # JSON responses are just used to validate ahead of time that this
      # component can actually be exported
      format.json { render json: { status: :ok } }
    end
  end

  def import_backup
    file = params[:file]
    unless file
      render json: {
        toast: { title: 'Import error', message: 'No file provided', variant: 'danger' }
      }, status: :bad_request
      return
    end

    dry_run = params[:dry_run] == 'true'
    include_reviews = params[:include_reviews] != 'false'

    result = Import::JsonArchiveImporter.new(
      zip_file: file,
      project: @project,
      dry_run: dry_run,
      include_reviews: include_reviews
    ).call

    if result.success?
      render json: {
        toast: dry_run ? 'Dry run complete. No records were created.' : 'Backup restored successfully.',
        summary: result.summary,
        warnings: result.warnings
      }
    else
      render json: {
        toast: {
          title: 'Import failed',
          message: result.errors.join('; '),
          variant: 'danger'
        },
        warnings: result.warnings
      }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def new_project_params
    params.expect(project: %i[name description visibility slack_channel_id])
  end

  def project_params
    params.expect(
      project: [:name,
                :description,
                :visibility,
                { project_metadata_attributes: { data: {} } }]
    )
  end

  def check_permission_to_update
    condition = project_params[:project_metadata_attributes]&.dig('data', 'Slack Channel ID').present? ||
                project_params[:visibility].present?
    authorize_admin_project if condition
  end

  # Parse @@components_to_export from comma-separated string to integer array.
  # Returns nil if not set (exports all components).
  def resolve_component_ids
    return nil unless defined?(@@components_to_export) && @@components_to_export.present?

    @@components_to_export.split(',').map(&:to_i)
  end

  def project_name_changed?(current_project_name)
    project_params['name'].present? && project_params['name'] != current_project_name
  end

  def project_visibility_changed?(current_project_visibility)
    project_params[:visibility].present? && project_params[:visibility] != current_project_visibility
  end
end
