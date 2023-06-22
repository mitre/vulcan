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
  before_action :check_permission_to_update_slackchannel, only: %i[update]

  def index
    @projects = current_user.available_projects.eager_load(:memberships).alphabetical.as_json(methods: %i[memberships])
    @projects.each do |project|
      project['admin'] = project['memberships'].any? do |m|
        m['role'] == PROJECT_MEMBER_ADMINS && m['user_id'] == current_user.id
      end
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
      methods: %i[histories memberships metadata components available_components available_members details]
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
      memberships_attributes: [{ user: current_user, role: PROJECT_MEMBER_ADMINS }]
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
    current_project_name = @project.name
    if @project.update(project_params)
      if project_name_changed?(current_project_name, project_params)
        render json: { toast: 'Project renamed successfully' }
        send_slack_notification(:rename_project, @project) if Settings.slack.enabled
      else
        render json: { toast: 'Project updated successfully' }
      end
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
    # Using class variable @@components_to_export here to save params[:components_type] value in memory,
    # because format.html below triggers a redirect to this same action controller
    # causing to lose the :components_type param.

    # rubocop:disable Style/ClassVars
    @@components_to_export = params[:components_type] || @@components_to_export
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
    params.require(:project).permit(:name, :slack_channel_id)
  end

  def project_params
    params.require(:project).permit(
      :name,
      project_metadata_attributes: { data: {} }
    )
  end

  def check_permission_to_update_slackchannel
    authorize_admin_project if project_params[:project_metadata_attributes][:data]['Slack Channel ID'].present?
  end

  def project_name_changed?(current_project_name, project_params)
    project_params['name'].present? && project_params['name'] != current_project_name
  end
end
