# frozen_string_literal: true

##
# Controller for application projects.
#
class ProjectsController < ApplicationController
  include ExportHelper
  include ProjectMemberConstants

  before_action :set_project, only: %i[show update destroy export]
  before_action :set_project_permissions, only: %i[show]
  before_action :authorize_admin_project, only: %i[update destroy]
  before_action :authorize_viewer_project, only: %i[show]
  before_action :authorize_logged_in, only: %i[index new search]
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

  def new; end

  def create
    project = Project.new(
      name: new_project_params[:name],
      description: new_project_params[:description],
      memberships_attributes: [{ user: current_user, role: PROJECT_MEMBER_ADMINS }],
      visibility: new_project_params[:visibility]
    )
    if new_project_params[:slack_channel_id].present?
      project.project_metadata_attributes = { data: { 'Slack Channel ID' => new_project_params[:slack_channel_id] } }
    end

    # First save ensures base Project is acceptable.
    if project.save
      send_slack_notification(:create_project, project) if Settings.slack.enabled
      redirect_to project
    else
      flash.alert = "Unable to create project. #{project.errors.full_messages}"
      redirect_to action: 'new'
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
      flash.notice = 'Successfully removed project.'
    else
      flash.alert = "Unable to remove project. #{@project.errors.full_messages}"
    end
    redirect_to action: 'index'
  end

  def export
    # Using class variable @@components_to_export here to save params[:component_ids] value in memory,
    # because format.html below triggers a redirect to this same action controller
    # causing to lose the :component_ids param.

    # rubocop:disable Style/ClassVars
    @@components_to_export = params[:component_ids] || @@components_to_export
    # rubocop:enable Style/ClassVars

    export_type = params[:type]&.to_sym

    # Other export types will be included in the future
    unless %i[disa_excel excel xccdf inspec].include?(export_type)
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
        when :disa_excel
          is_disa_export = true
          workbook = export_excel(@project, @@components_to_export, is_disa_export)
          send_data workbook.read_string, filename: "#{@project.name}_DISA.xlsx"
        when :excel
          is_disa_export = false
          workbook = export_excel(@project, @@components_to_export, is_disa_export)
          send_data workbook.read_string, filename: "#{@project.name}.xlsx"
        when :xccdf
          send_data export_xccdf_project(@project).string, filename: "#{@project.name}.zip"
        when :inspec
          send_data export_inspec_project(@project).string, filename: "#{@project.name}_inspec.zip"
        end
      end
      # JSON responses are just used to validate ahead of time that this
      # component can actually be exported
      format.json { render json: { status: :ok } }
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def new_project_params
    params.require(:project).permit(:name, :description, :visibility, :slack_channel_id)
  end

  def project_params
    params.require(:project).permit(
      :name,
      :description,
      :visibility,
      project_metadata_attributes: { data: {} }
    )
  end

  def check_permission_to_update
    condition = project_params[:project_metadata_attributes]&.dig('data', 'Slack Channel ID').present? ||
                project_params[:visibility].present?
    authorize_admin_project if condition
  end

  def project_name_changed?(current_project_name)
    project_params['name'].present? && project_params['name'] != current_project_name
  end

  def project_visibility_changed?(current_project_visibility)
    project_params[:visibility].present? && project_params[:visibility] != current_project_visibility
  end
end
