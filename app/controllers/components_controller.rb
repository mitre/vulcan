# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  before_action :set_component, only: %i[show update destroy export]
  before_action :set_project, only: %i[show create]
  before_action :set_component_permissions, only: %i[show]

  before_action :authorize_admin_project, only: %i[create]
  before_action :authorize_admin_component, only: %i[destroy]
  before_action :authorize_author_component, only: %i[update]
  before_action :authorize_admin_component, only: %i[update], if: lambda {
    params.require(:component).permit(:advanced_fields)[:advanced_fields].present?
  }
  before_action :authorize_viewer_component, only: %i[show], if: -> { @component.released == false }
  before_action :authorize_logged_in, only: %i[show], if: -> { @component.released }

  def index
    @components_json = Component.eager_load(:based_on).where(released: true).to_json
  end

  def show
    @component_json = if @effective_permissions
                        @component.to_json(
                          methods: %i[histories memberships metadata inherited_memberships available_members rules]
                        )
                      else
                        @component.to_json(methods: %i[rules])
                      end

    @project_json = @component.project.to_json
    respond_to do |format|
      format.html
      format.json { render json: @component_json }
    end
  end

  def create
    component = create_or_duplicate
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

  def export
    if @component.released
      send_data @component.csv_export, filename: "#{@component.project.name}-#{@component.prefix}.csv"
    else
      render json: {
        toast: {
          title: 'Export error',
          message: 'Cannot export a component that is not released',
          variant: 'danger'
        }
      }, status: :bad_request
    end
  end

  private

  def create_or_duplicate
    if component_create_params[:duplicate]
      @project.components.find(component_create_params[:id]).duplicate(new_version: component_create_params[:version],
                                                                       new_prefix: component_create_params[:prefix])
    else
      Component.new(component_create_params.except(:id, :duplicate).merge({ project: @project }))
    end
  end

  def set_component
    @component = Component.eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks, :satisfies, :satisfied_by, {
        srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
      }]
    ).find(params[:id])
  end

  def set_project
    @project = Project.find(params[:project_id] || @component.project_id)
  end

  def component_update_params
    params.require(:component).permit(
      :released,
      :version,
      :advanced_fields,
      component_metadata_attributes: { data: {} }
    )
  end

  def component_create_params
    params.require(:component).permit(
      :id,
      :duplicate,
      :prefix,
      :security_requirements_guide_id,
      :version
    )
  end
end
