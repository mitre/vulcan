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
                          methods: %i[histories memberships metadata inherited_memberships available_members rules
                                      reviews]
                        )
                      else
                        @component.to_json(methods: %i[rules reviews])
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
      component.duplicate_reviews_and_history(component_create_params[:id])
      component.create_rule_satisfactions if component_create_params[:file]
      component.rules_count = component.rules.where(deleted_at: nil).size
      component.save
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
    ActiveRecord::Base.transaction do
      # Soft deleted rules must be destroyed in order for component to be destroyed
      Rule.unscoped.where(component_id: @component.id).destroy_all
      @component.destroy!
      render json: { toast: 'Successfully removed component from project.' }
    end
  rescue StandardError
    render json: {
      toast: {
        title: 'Error',
        message: 'Could not remove component from project.',
        variant: 'danger'
      }
    }, status: :unprocessable_entity
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

  def based_on_same_srg
    srg_title = Component.find(params[:id]).based_on.title
    render json: Component.where(based_on: SecurityRequirementsGuide.where(title: srg_title))
                          .where.not(id: params[:id])
                          .order(:project_id)
                          .joins(:project)
                          .select('components.id, components.name, components.version, components.prefix, '\
                                  'components.release, projects.name AS project_name')
                          .map(&:attributes)
  end

  def compare
    base = Component.find_by(id: params[:id]).rules.pluck(:rule_id, :inspec_control_file).to_h
    diff = Component.find_by(id: params[:diff_id]).rules.pluck(:rule_id, :inspec_control_file).to_h
    render json: base.keys.union(diff.keys).sort.index_with { |rule_id|
      { base: base[rule_id], diff: diff[rule_id], changed: base[rule_id] != diff[rule_id] }
    }
  end

  def history
    history = []
    components = Project.find_by(id: params[:project_id]).components.where(name: params[:name])
                        .where.not(version: nil).where.not(release: nil).order(:version, :release)
    components.each_with_index do |component, idx|
      # nothing to compare first component to
      unless idx.zero?
        prev_component = components[idx - 1]
        base = prev_component.rules.eager_load(:satisfied_by, :checks, :disa_rule_descriptions)
                             .map(&:basic_fields).index_by { |r| r[:rule_id] }
        diff = component.rules.eager_load(:satisfied_by, :checks, :disa_rule_descriptions)
                        .map(&:basic_fields).index_by { |r| r[:rule_id] }
        changes = {}

        # added
        (diff.keys - base.keys).each do |rule_id|
          changes[rule_id] = { change: 'added', diff: diff[rule_id] }
        end

        # removed
        (base.keys - diff.keys).each do |rule_id|
          changes[rule_id] = { change: 'removed', base: base[rule_id] }
        end

        # updated
        base.keys.intersection(diff.keys)
            .filter { |rule_id| base[rule_id] != diff[rule_id] }
            .each do |rule_id|
              changes[rule_id] = { change: 'updated', base: base[rule_id], diff: diff[rule_id] }
            end

        history << {
          baseComponent: prev_component,
          diffComponent: component,
          changes: changes
        }
      end

      history << { component: component }
    end

    render json: history
  end

  def find
    find = params.require(:find)
    component_id = params.require(:id)

    rules = Component.find_by(id: component_id).rules
    checks = Check.where(base_rule: rules).where('content like ?', "%#{find.downcase}%")
    descriptions = DisaRuleDescription.where(base_rule: rules).where('vuln_discussion like ?', "%#{find.downcase}%")
    rules = rules.where('title like ?', "%#{find.downcase}%").or(
      rules.where('fixtext LIKE ?', "%#{find.downcase}%").or(
        rules.where('vendor_comments LIKE ?', "%#{find.downcase}%").or(
          rules.where(id: checks.pluck(:base_rule_id) | descriptions.pluck(:base_rule_id))
        )
      )
    ).order(:rule_id)

    render json: rules
  end

  private

  def create_or_duplicate
    if component_create_params[:duplicate] || component_create_params[:copy_component]
      Component.find(component_create_params[:id])
               .duplicate(new_name: component_create_params[:name],
                          new_prefix: component_create_params[:prefix],
                          new_version: component_create_params[:version],
                          new_release: component_create_params[:release],
                          new_title: component_create_params[:title],
                          new_description: component_create_params[:description],
                          new_project_id: component_create_params[:project_id],
                          new_srg_id: component_create_params[:security_requirements_guide_id])
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
      :copy_component,
      :component_id,
      :project_id,
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
