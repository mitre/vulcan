# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  include ExportHelper

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
  before_action :authorize_logged_in, only: %i[search]
  before_action :authorize_logged_in, only: %i[show], if: -> { @component.released }

  def index
    @components_json = Component.eager_load(:based_on).where(released: true).to_json
  end

  def search
    query = params[:q]
    components = Component.joins(:project, :based_on)
                          .tap do |o|
      unless current_user.admin
        o.left_joins(project: :memberships)
         .where({ memberships: { user_id: current_user.id } })
      end
    end
                          .and(SecurityRequirementsGuide.where(srg_id: query))
                          .or(Component.where(released: true).and(SecurityRequirementsGuide.where(srg_id: query)))
                          .limit(100)
                          .distinct
                          .pluck(:id, :name)
    render json: {
      components: components
    }
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
    # When importing from an existing spreadsheet, some errors are set before
    # save, this makes sure those errors are shown and not overwritten by the
    # component validators.
    if component.errors.empty? && component.save
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
    export_type = params[:type]&.to_sym

    # Other export types will be included in the future
    unless %i[csv inspec].include?(export_type)
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
        when :csv
          send_data @component.csv_export, filename: "#{@component.project.name}-#{@component.prefix}.csv"
        when :inspec
          version = @component[:version] ? "V#{@component[:version]}" : ''
          release = @component[:release] ? "R#{@component[:release]}" : ''
          filename = "#{@component[:name].tr(' ', '-')}-#{version}#{release}-stig-baseline.zip"
          send_data export_inspec_component(@component).string, filename: filename
        end
      end
      # JSON responses are just used to validate ahead of time that this
      # component can actually be exported
      format.json { render json: { status: :ok } }
    end
  end

  def compare
    base = Component.find_by(id: params[:id]).rules.pluck(:rule_id, :inspec_control_file).to_h
    diff = Component.find_by(id: params[:diff_id]).rules.pluck(:rule_id, :inspec_control_file).to_h
    render json: base.keys.union(diff.keys).sort.index_with { |rule_id| { base: base[rule_id], diff: diff[rule_id] } }
  end

  private

  def create_or_duplicate
    if component_create_params[:duplicate]
      @project.components.find(component_create_params[:id])
              .duplicate(new_name: component_create_params[:name],
                         new_prefix: component_create_params[:prefix],
                         new_version: component_create_params[:version],
                         new_release: component_create_params[:release],
                         new_title: component_create_params[:title],
                         new_description: component_create_params[:description])
    elsif component_create_params[:component_id]
      Component.find(component_create_params[:component_id]).overlay(@project.id)
    elsif component_create_params[:file]
      # Create a new component from the provided parameters and then pass the spreadsheet
      # to the component for further parsing
      component = @project.components.new(component_create_params.except(:id, :duplicate, :file))
      component.from_spreadsheet(component_create_params[:file])
      component
    else
      Component.new(component_create_params.except(:id, :duplicate, :component_id, :file).merge({ project: @project }))
    end
  end

  def set_component
    @component = Component.eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
              :additional_answers, :satisfies, :satisfied_by, {
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
      :name,
      :version,
      :release,
      :title,
      :description,
      :advanced_fields,
      additional_questions_attributes: [:id, :name, :question_type, :_destroy, { options: [] }],
      component_metadata_attributes: { data: {} }
    )
  end

  def component_create_params
    params.require(:component).permit(
      :id,
      :duplicate,
      :component_id,
      :security_requirements_guide_id,
      :name,
      :prefix,
      :version,
      :release,
      :title,
      :description,
      :file,
      file: {}
    )
  end
end
