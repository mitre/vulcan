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
  before_action :authorize_logged_in, only: %i[index new create search]

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
      redirect_to project
    else
      flash.alert = "Unable to create project. #{project.errors.full_messages}"
      redirect_to action: 'new'
    end
  end

  # Update project and response with json
  def update
    if @project.update(project_params)
      render json: { toast: 'Project updated successfully' }
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
      flash.notice = 'Successfully removed project.'
    else
      flash.alert = "Unable to remove project. #{@project.errors.full_messages}"
    end
    redirect_to action: 'index'
  end

  def export
    export_type = params[:type]&.to_sym

    # Other export types will be included in the future
    unless %i[excel xccdf inspec].include?(export_type)
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
        when :excel
          workbook = export_excel(@project)
          send_data workbook.read_string, filename: "#{@project.name}.xlsx"
        when :xccdf
          send_data export_xccdf(@project).string, filename: "#{@project.name}.zip"
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
end
