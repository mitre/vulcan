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
    @projects = current_user.available_projects.alphabetical
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
    @project_json = @project.stats
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
    unless %i[excel].include?(export_type)
      render json: {
        toast: {
          title: 'Export error',
          message: "Unsupported export type: #{export_type}",
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    if @project.components.where(released: true).size.zero?
      render json: {
        toast: {
          title: 'Export error',
          message: 'Project does not include any released components',
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    respond_to do |format|
      format.html do
        workbook = export_excel(@project)
        send_data workbook.read_string, filename: "#{@project.name}.xlsx"
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
    params.require(:project).permit(project_metadata_attributes: { data: {} })
  end
end
