# frozen_string_literal: true

##
# Controller for application projects.
#
class ProjectsController < ApplicationController
  include Exportable
  include ProjectMemberConstants
  include UploadValidatable

  IMPORT_ERROR_TITLE = 'Import error'

  before_action :set_project, only: %i[show update destroy export import_backup histories triage comments]
  before_action :set_project_permissions, only: %i[show triage]
  before_action :authorize_admin_project, only: %i[update destroy import_backup]
  before_action :authorize_viewer_project, only: %i[show export histories triage comments]
  before_action :authorize_logged_in, only: %i[index search]
  before_action :authorize_admin_or_create_permission_enabled, only: %i[create create_from_backup]
  before_action :check_permission_to_update, only: %i[update]
  before_action -> { validate_upload(:file, max_size: 100.megabytes, allowed_types: %w[.zip]) },
                only: %i[import_backup create_from_backup]

  def index
    projects = current_user.available_projects.preload(:memberships).alphabetical.to_a
    # Batch-load access requests to avoid N+1 per-project find_by
    project_ids = projects.map(&:id)
    ar_by_project = current_user.access_requests
                                .where(project_id: project_ids)
                                .index_by(&:project_id)
    # Batch-load comment counts (single GROUP BY with FILTER aggregate) so
    # the row "Comments" column never triggers per-project queries.
    # Returns { pid => { pending: N, total: M } }.
    comment_counts = Project.comment_counts(project_ids)
    # Resolve the deep-link target server-side: when a project has exactly
    # one component with pending comments, the row link goes straight to
    # that component (one click → triage panel — no intermediate-page bounce).
    pending_comment_targets = Project.pending_comment_target_components(project_ids)
    @projects = ProjectIndexBlueprint.render_as_hash(
      projects,
      current_user: current_user,
      access_requests_by_project: ar_by_project,
      comment_counts: comment_counts,
      pending_comment_target_components: pending_comment_targets
    )
    respond_to do |format|
      format.html
      format.json { render json: @projects }
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
    # Batch-load pending-comment counts keyed by component_id so the
    # component cards and the project-level total render without N+1 (PR #717).
    component_ids = @project.components.pluck(:id)
    pending_comment_counts = Component.pending_comment_counts(component_ids)
    @project_json = ProjectBlueprint.render(
      @project,
      view: :show,
      pending_comment_counts: pending_comment_counts
    )
    respond_to do |format|
      format.html
      format.json { render body: @project_json, content_type: 'application/json' }
    end
  end

  def histories
    return head :not_found unless @project

    render json: @project.histories(50)
  end

  # GET /projects/:id/triage — full-page aggregate triage view across
  # all components in the project. Renders an HTML page that mounts a
  # Vue app (ProjectTriagePage). The Vue app fetches rows from the JSON
  # endpoint at GET /projects/:id/comments. PR #717 follow-on.
  #
  # HTML-only — JSON requests return 406, since the data lives on the
  # /projects/:id/comments JSON endpoint.
  def triage
    respond_to do |format|
      format.html do
        @project.current_user = current_user
        @project_json = ProjectBlueprint.render(@project, view: :show)
      end
      format.any { head :not_acceptable }
    end
  end

  # GET /projects/:id/comments — paginated triage rows aggregated across
  # all the project's components. Same row shape as the per-component
  # endpoint, plus component_id + component_name per row so the table
  # can show which component each comment belongs to.
  #
  # Sets Cache-Control: no-store so concurrent triagers cannot get a
  # stale snapshot from a browser/proxy cache.
  def comments
    return head :not_found unless @project

    result = @project.paginated_comments(
      triage_status: params[:triage_status].presence || 'pending',
      section: params[:section].presence,
      component_id: params[:component_id].presence,
      author_id: params[:author_id].presence,
      query: params[:q].presence,
      page: params[:page].presence || 1,
      per_page: params[:per_page].presence || 25,
      resolved: params[:resolved].presence || 'all'
    )
    response.headers['Cache-Control'] = 'no-store'
    render json: result
  end

  def create
    project = Project.new(
      name: new_project_params[:name],
      description: new_project_params[:description],
      memberships_attributes: [{ user: current_user, role: ROLE_ADMIN }],
      visibility: new_project_params[:visibility]
    )
    project.project_metadata_attributes = { data: { 'Slack Channel ID' => new_project_params[:slack_channel_id] } } if new_project_params[:slack_channel_id].present?

    # First save ensures base Project is acceptable.
    if project.save
      safely_notify('create_project') { send_slack_notification(:create_project, project) } if Settings.slack.enabled

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
          safely_notify("update_project_#{type}") { send_slack_notification(type, @project) }
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
      safely_notify('remove_project') { send_slack_notification(:remove_project, @project) } if Settings.slack.enabled
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
    # Stash component_ids in session so it survives the format.html redirect
    # back to this action (which loses query params). Session is per-user,
    # unlike the old @@class_variable which was shared across all threads.
    session[:components_to_export] = params[:component_ids] if params[:component_ids].present?

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
          csv_mode_options = export_mode_options
          if components.size == 1
            perform_export(
              exportable: components.first, mode: :working_copy, format: :csv,
              filename: "#{@project.name}-#{components.first.prefix}.csv",
              mode_options: csv_mode_options
            )
          else
            perform_export(
              exportable: components.to_a, mode: :working_copy, format: :csv,
              zip_filename: "#{@project.name}.zip",
              mode_options: csv_mode_options
            )
          end
        when :excel
          mode = export_mode || :working_copy
          filename = mode == :vendor_submission ? "#{@project.name}_DISA.xlsx" : "#{@project.name}.xlsx"
          perform_export(
            exportable: @project, mode: mode, format: :excel,
            component_ids: resolve_component_ids,
            filename: filename,
            mode_options: export_mode_options
          )
        when :xccdf
          perform_export(
            exportable: @project, mode: export_mode || :published_stig, format: :xccdf,
            component_ids: resolve_component_ids,
            zip_filename: "#{@project.name}.zip"
          )
        when :inspec
          perform_export(
            exportable: @project, mode: export_mode || :published_stig, format: :inspec,
            component_ids: resolve_component_ids,
            zip_filename: "#{@project.name}_inspec.zip"
          )
        when :json_archive
          perform_export(
            exportable: @project, mode: :backup, format: :json_archive,
            component_ids: resolve_component_ids,
            zip_filename: "vulcan-backup-#{@project.name}-#{Date.current}.zip",
            formatter_options: { include_srg: params[:include_srg] == 'true' }
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
        toast: { title: IMPORT_ERROR_TITLE, message: 'No file provided', variant: 'danger' }
      }, status: :bad_request
      return
    end

    dry_run = params[:dry_run] == 'true'
    include_reviews = params[:include_reviews] != 'false'
    include_memberships = params[:include_memberships] == 'true'
    component_filter = nil
    if params[:component_filter].present?
      begin
        component_filter = JSON.parse(params[:component_filter])
      rescue JSON::ParserError
        render json: { toast: { title: 'Invalid request', message: 'component_filter must be valid JSON', variant: 'danger' } },
               status: :bad_request
        return
      end
    end

    result = Import::JsonArchiveImporter.new(
      zip_file: file,
      project: @project,
      dry_run: dry_run,
      include_reviews: include_reviews,
      include_memberships: include_memberships,
      component_filter: component_filter
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

  def create_from_backup
    file = params[:file]
    unless file
      render json: {
        toast: { title: IMPORT_ERROR_TITLE, message: 'No file provided', variant: 'danger' }
      }, status: :bad_request
      return
    end

    dry_run = params[:dry_run] == 'true'
    include_reviews = params[:include_reviews] != 'false'
    include_memberships = params[:include_memberships] == 'true'
    project_name = params[:project_name].presence
    project_description = params[:project_description].presence || ''
    project_visibility = Project.visibilities.key?(params[:project_visibility]) ? params[:project_visibility] : 'discoverable'

    if dry_run
      perform_create_from_backup_dry_run(file, include_reviews, include_memberships)
    else
      perform_create_from_backup(file, include_reviews, include_memberships,
                                 project_name, project_description, project_visibility)
    end
  end

  private

  def perform_create_from_backup_dry_run(file, include_reviews, include_memberships)
    project_defaults = extract_project_defaults(file)

    # Dry-run no longer writes to DB — use unsaved project (no conflicts possible for new project)
    temp_project = Project.new(name: 'Preview')

    result = Import::JsonArchiveImporter.new(
      zip_file: file,
      project: temp_project,
      dry_run: true,
      include_reviews: include_reviews,
      include_memberships: include_memberships
    ).call

    if result.success?
      render json: {
        summary: result.summary,
        warnings: result.warnings,
        project_defaults: project_defaults
      }
    else
      render json: {
        toast: {
          title: 'Preview failed',
          message: result.errors.join('; '),
          variant: 'danger'
        },
        warnings: result.warnings,
        project_defaults: project_defaults
      }, status: :unprocessable_entity
    end
  end

  def perform_create_from_backup(file, include_reviews, include_memberships,
                                 project_name, project_description, project_visibility)
    unless project_name
      render json: {
        toast: { title: IMPORT_ERROR_TITLE, message: 'Project name is required', variant: 'danger' }
      }, status: :unprocessable_entity
      return
    end

    project = nil
    result = nil

    ActiveRecord::Base.transaction do
      project = Project.create!(
        name: project_name,
        description: project_description,
        visibility: project_visibility,
        memberships_attributes: [{ user: current_user, role: ROLE_ADMIN }]
      )

      result = Import::JsonArchiveImporter.new(
        zip_file: file,
        project: project,
        dry_run: false,
        include_reviews: include_reviews,
        include_memberships: include_memberships
      ).call

      raise ActiveRecord::Rollback unless result.success?
    end

    if result&.success?
      render json: {
        redirect_url: project_path(project),
        summary: result.summary,
        toast: 'Project created from backup successfully.'
      }
    else
      render json: {
        toast: {
          title: 'Import failed',
          message: result&.errors&.join('; ') || 'Unknown error',
          variant: 'danger'
        },
        warnings: result&.warnings || []
      }, status: :unprocessable_entity
    end
  end

  def extract_project_defaults(file)
    file_data = file.respond_to?(:read) ? file.read : file
    file.rewind if file.respond_to?(:rewind)

    defaults = { name: 'Restored Project', description: '', visibility: 'discoverable' }

    Zip::File.open_buffer(file_data) do |zip|
      project_entry = zip.find_entry('project.json')
      if project_entry
        project_json = JSON.parse(zip.read('project.json'))
        defaults[:name] = project_json['name'] if project_json['name'].present?
        defaults[:description] = project_json['description'] if project_json['description'].present?
        defaults[:visibility] = project_json['visibility'] if project_json['visibility'].present?
      end
    end

    defaults
  rescue Zip::Error, JSON::ParserError
    defaults
  end

  def set_project
    @project = Project.find(params[:id])
  end

  def new_project_params
    params.expect(project: %i[name description visibility slack_channel_id])
  end

  def project_params
    # rubocop:disable Rails/StrongParametersExpect -- params.expect breaks partial param payloads
    params.require(:project).permit(
      :name, :description, :visibility,
      project_metadata_attributes: { data: {} }
    )
    # rubocop:enable Rails/StrongParametersExpect
  end

  def check_permission_to_update
    slack_id = params.dig(:project, :project_metadata_attributes, :data, 'Slack Channel ID')
    condition = slack_id.present? || params.dig(:project, :visibility).present?
    authorize_admin_project if condition
  end

  # Parse session[:components_to_export] from comma-separated string to integer array.
  # Returns nil if not set (exports all components).
  def export_mode_options
    options = {}
    options[:exclude_satisfied_by] = true if params[:exclude_satisfied_by] == 'true'
    options
  end

  def resolve_component_ids
    value = session.delete(:components_to_export)
    return nil if value.blank?

    value.split(',').map(&:to_i)
  end

  def project_name_changed?(current_project_name)
    project_params['name'].present? && project_params['name'] != current_project_name
  end

  def project_visibility_changed?(current_project_visibility)
    project_params[:visibility].present? && project_params[:visibility] != current_project_visibility
  end
end
