# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  before_action :set_component, only: %i[show update destroy]
  before_action :set_project, only: %i[show create]
  before_action :set_component_permissions, only: %i[show]

  before_action :authorize_admin_project, only: %i[create]
  before_action :authorize_admin_component, only: %i[destroy]
  before_action :authorize_author_component, only: %i[update]
  before_action :authorize_viewer_component, only: %i[show], if: -> { @component.released == false }
  before_action :authorize_logged_in, only: %i[show], if: -> { @component.released }

  def index
    @components_json = Component.eager_load(:based_on).where(released: true).to_json
  end

  def show
    @component_json = @component.to_json(
      methods: %i[histories memberships inherited_memberships available_members rules]
    )
    @project_json = @component.project.to_json
  end

  def create
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
