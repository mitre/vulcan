# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  before_action :set_project, only: %i[create]
  before_action :set_component, only: %i[destroy]
  before_action :authorize_admin_project, only: %i[create destroy]
  before_action :authorize_logged_in, only: %i[index]

  def index
    @projects = current_user.available_projects.components.alphabetical
  end

  def new
    @srgs = SecurityRequirementsGuide.latest.map do |srg|
      srg['title'] = "#{srg['title']} #{srg['version']}"
      srg
    end
  end

  def create
    # If not an Vulcan admin, then we must ensure that the current_user has
    # sufficient permissions on the child project.
    unless current_user.admin
      has_permissions = ProjectMember.find_by(user_id: current_user.id, project_id: @project.id).present?
      raise(NotAuthorizedError, 'You are not authorized to add this project as a component') unless has_permissions
    end

    component = Component.new(component_params.merge({ project: @project }))
    if component.save
      render json: { toast: 'Successfully added component to project.' }
    else
      render json: {
        toast: {
          title: 'Could not add component to project.',
          message: component.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @component.destroy
      render json: { toast: 'Successfully removed component from project.' }
    else
      render json: {
        toast: {
          title: 'Could not remove component from project.',
          message: @component.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  private

  def set_component
    @component = Component.find(params[:id])
  end

  def set_project
    @project = Project.find(params[:project_id])
  end

  def component_params
    params.require(:component).permit(:child_project_id)
  end
end
