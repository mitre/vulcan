# frozen_string_literal: true

##
# Controller for application projects.
#
class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show update destroy]
  before_action :authorize_admin_project, only: %i[destroy]
  before_action :authorize_logged_in, only: %i[index]

  def index
    @projects = current_user.available_projects.alphabetical.select(:id, :name, :updated_at, :project_members_count)
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @project }
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

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(project_metadata_attributes: { data: {} })
  end
end
