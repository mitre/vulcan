# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  before_action :set_component, only: %i[show update destroy]
  before_action :set_project, only: %i[show create]
  before_action :set_project_permissions, only: %i[show]
  before_action :authorize_admin_project, only: %i[create destroy]
  before_action :authorize_author_project, only: %i[show update]

  def show
    @component_json = @component.to_json(
      methods: %i[histories rules]
    )
    @project_json = @component.project.to_json
  end

  def create
    # If not an Vulcan admin, then we must ensure that the current_user has
    # sufficient permissions on a component overlay's project.
    if component_create_params[:component_id] && !current_user.admin
      overlayed_component_project_id = Component.find_by(id: component_create_params[:component_id]).pluck(:project_id)
      has_permissions = ProjectMember.find_by(user_id: current_user.id,
                                              project_id: overlayed_component_project_id).present?
      raise(NotAuthorizedError, 'You are not authorized to add this component to your project.') unless has_permissions
    end

    component = Component.new(component_create_params.merge({ project: @project }))
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

  def update
    if @component.update(component_update_params)
      render json: { toast: 'Successfully updated component.' }
    else
      render json: {
        toast: {
          title: 'Could not update component.',
          message: @component.errors.full_messages,
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
    @project = Project.find(params[:project_id] || @component.project_id)
  end

  def component_update_params
    params.require(:component).permit(
      :released,
      :version
    )
  end

  def component_create_params
    params.require(:component).permit(
      :component_id,
      :prefix,
      :security_requirements_guide_id,
      :version
    )
  end
end
