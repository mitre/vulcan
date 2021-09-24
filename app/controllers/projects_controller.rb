# frozen_string_literal: true

##
# Controller for application projects.
#
class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show update destroy]
  before_action :authorize_admin_project, only: %i[destroy]
  before_action :authorize_logged_in, only: %i[index]

  def index
    @projects = current_user.available_projects.alphabetical
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @project }
    end
  end

  def new
    @srgs = SecurityRequirementsGuide.latest.map do |srg|
      srg['title'] = "#{srg['title']} #{srg['version']}"
      srg
    end
  end

  def create
    project = Project.new(
      name: new_project_params[:name],
      based_on: SecurityRequirementsGuide.find(new_project_params[:srg_id]),
      prefix: new_project_params[:prefix]
    )

    # First save ensures base Project is acceptable.
    if project.save
      # Create rules
      if Project.from_mapping(Xccdf::Benchmark.parse(project.based_on.xml), project.id)
        redirect_to action: 'index'
      else
        flash.alert = 'Unable to create project. An error occured parsing the selected SRG'
        redirect_to action: 'new'
      end
    else
      flash.alert = "Unable to create project. #{project.errors.full_messages}"
      redirect_to action: 'new'
    end
  rescue ActiveRecord::RecordNotFound
    flash.alert = 'Unable to create project. Could not find Security Requirements Guide'
    redirect_to action: 'new'
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

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def new_project_params
    params.require(:project).permit(:name, :prefix, :srg_id)
  end

  def project_params
    params.require(:project).permit(project_metadata_attributes: { data: {} })
  end
end
