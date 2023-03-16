# frozen_string_literal: true

##
# Controller for application projects.
#
class ProjectsController < ApplicationController
  include ExportHelper
  include ProjectMemberConstants
  include SlackNotificationsHelper
  before_action :set_project, only: %i[show update destroy export]
  before_action :set_project_permissions, only: %i[show]
  before_action :authorize_admin_project, only: %i[update destroy]
  before_action :authorize_viewer_project, only: %i[show]
  before_action :authorize_logged_in, only: %i[index new search]
  before_action :authorize_admin_or_create_permission_enabled, only: %i[create]

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

    # First save ensures base Project is acceptable.
    if project.save
      if Settings.slack.enabled
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:create_project, project)
        )
      end
      redirect_to project
    else
      flash.alert = "Unable to create project. #{project.errors.full_messages}"
      redirect_to action: 'new'
    end
  end

  # Update project and response with json
  def update
    old_project_name = @project.name
    if @project.update(project_params)
      render json: { toast: 'Project updated successfully' }
      if Settings.slack.enabled
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:rename_project, @project, old_project_name)
        )
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
      if Settings.slack.enabled
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:remove_project, @project)
        )
      end
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
    params.require(:project).permit(:name)
  end

  def project_params
    params.require(:project).permit(
      :name,
      project_metadata_attributes: { data: {} }
    )
  end

  def slack_notification_params(notification_type, project, old_project_name = nil)
    notification_type_prefix = notification_type.to_s.match(/^(create|rename|remove)/)[1]
    fields = [
      GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
      PROJECT_NOTIFICATION_FIELDS[:generate_project_label],
      PROJECT_NOTIFICATION_FIELDS[:generate_initiated_by_label]
    ]
    fields << PROJECT_NOTIFICATION_FIELDS[:generate_old_project_name_label] if notification_type == :rename_project
    headers = {
      create_project: 'Vulcan New Project Creation',
      rename_project: 'Vulcan Project Renaming',
      remove_project: 'Vulcan Project Removal'
    }
    icons = {
      create_project: ':white_check_mark:',
      rename_project: ':loudspeaker:',
      remove_project: ':x:'
    }
    header = headers[notification_type]
    {
      icon: icons[notification_type],
      header: header,
      fields: fields.map do |field|
        label, value = field.values_at(:label, :value)
        label_content = label.respond_to?(:call) ? label.call(notification_type_prefix) : label
        value_content = if value.respond_to?(:call)
                          value.call(notification_type_prefix, project, old_project_name, current_user)
                        else
                          value
                        end
        { label: label_content, value: value_content }
      end
    }
  end
end
