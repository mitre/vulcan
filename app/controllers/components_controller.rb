# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  before_action :set_project, only: %i[create]
  before_action :set_component, only: %i[destroy]
  before_action :authorize_admin_project

  def create
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
