# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  include ExportHelper

  before_action :set_component, only: %i[show update destroy export]
  before_action :set_project, only: %i[show create]
  before_action :set_component_permissions, only: %i[show]
  before_action :set_rule, only: %i[show]
  before_action :authorize_admin_project, only: %i[create]
  before_action :authorize_admin_component, only: %i[destroy]
  before_action :authorize_author_component, only: %i[update]
  before_action :check_permission_to_update_slackchannel, only: %i[update]
  # Require admin for advanced_fields updates (separate callback to avoid overwriting destroy authorization)
  before_action :authorize_admin_for_advanced_fields, only: %i[update]

  before_action :authorize_viewer_component, only: %i[show], if: -> { @component.released == false }
  before_action :authorize_logged_in, only: %i[search]
  before_action :authorize_logged_in_for_released_show, only: %i[show]

  def index
    @components = Component.eager_load(:based_on).where(released: true)
                           .select(:id, :name, :prefix, :version, :release, :title, :released, :created_at, :project_id, :security_requirements_guide_id)
    respond_to do |format|
      format.html { @components_json = @components.to_json }
      format.json { render json: @components }
    end
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
                                      reviews admins all_users]
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
    # Note: XCCDF imports save early (need ID for from_mapping), so check persisted? too
    if component.errors.empty? && (component.save || component.persisted?)
      component.admin_name = component_create_params[:admin_name].presence || current_user.name
      component.admin_email = component_create_params[:admin_email].presence || current_user.email
      component.duplicate_reviews_and_history(component_create_params[:id])
      component.create_rule_satisfactions if component_create_params[:file] && !component_create_params[:file].original_filename.end_with?('.xml')
      component.rules_count = component.rules.where(deleted_at: nil).size
      if component_create_params[:slack_channel_id].present?
        component.component_metadata_attributes = { data: {
          'Slack Channel ID' => component_create_params[:slack_channel_id]
        } }
      end
      component.save
      send_slack_notification(:create_component, component) if Settings.slack.enabled
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
      send_slack_notification(:remove_component, @component) if Settings.slack.enabled
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
    unless %i[csv inspec xccdf].include?(export_type)
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
        version = @component[:version] ? "V#{@component[:version]}" : ''
        release = @component[:release] ? "R#{@component[:release]}" : ''

        case export_type
        when :csv
          send_data @component.csv_export, filename: "#{@component.project.name}-#{@component.prefix}.csv"
        when :inspec
          filename = "#{@component[:name].tr(' ', '-')}-#{version}#{release}-stig-baseline.zip"
          send_data export_inspec_component(@component).string, filename: filename
        when :xccdf
          filename = "#{@component[:name].tr(' ', '-')}-#{version}#{release}-xccdf.xml"
          send_data export_xccdf_component(@component), filename: filename
        end
      end
      # JSON responses are just used to validate ahead of time that this
      # component can actually be exported
      format.json { render json: { status: :ok } }
    end
  end

  def based_on_same_srg
    component = Component.find(params[:id])
    srg_title = component.based_on&.title
    return render json: [] if srg_title.nil?

    render json: Component.where(based_on: SecurityRequirementsGuide.where(title: srg_title))
                          .where.not(id: params[:id])
                          .order(:project_id)
                          .joins(:project)
                          .select('components.id, components.name, components.version, components.prefix, ' \
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
    find_param = params.require(:find)
    component = Component.find(params.require(:id))

    # Use pg_search gem for advanced full-text search
    # Features: partial word matching, fuzzy/typo tolerance, relevance ranking
    # Searches across: title, fixtext, vendor_comments, status_justification, artifact_description,
    #                  checks.content, disa_rule_descriptions (vuln_discussion, mitigations)
    rules = Rule.where(component_id: component.id)
                .search_content(find_param)
                .with_pg_search_rank
                .limit(200)

    # Use Blueprinter for efficient JSON serialization
    render json: RuleBlueprint.render(rules)
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
      # Create a new component from the provided parameters
      component = @project.components.new(component_create_params.except(:id, :duplicate, :file))
      file = component_create_params[:file]

      # Detect file type and route to appropriate import method
      Rails.logger.info "File type: #{file.content_type}, filename: #{file.original_filename}"
      if file.content_type.in?(['application/xml', 'text/xml']) || file.original_filename.end_with?('.xml')
        Rails.logger.info 'Routing to from_xccdf'
        # XCCDF import requires component to be saved first (needs ID for from_mapping)
        # But we need to extract prefix first before validation
        parsed_benchmark = Xccdf::Benchmark.parse(file.read)
        component.name ||= parsed_benchmark.title&.first || 'Imported Component'

        # Extract prefix from first rule
        if parsed_benchmark.group&.any?
          first_group = parsed_benchmark.group.first
          first_rule_id = first_group.rule&.first&.id
          if first_rule_id
            prefix_match = first_rule_id.match(/SV-([A-Z]+-\d+)-/)
            component.prefix = prefix_match[1] if prefix_match
          end
        end

        component.skip_import_srg_rules = true
        component.save! # Save with prefix

        # Rewind file and import
        file.rewind
        component.from_xccdf(file)
      else
        Rails.logger.info 'Routing to from_spreadsheet'
        component.from_spreadsheet(file)
      end
      Rails.logger.info "Component errors: #{component.errors.full_messages}"
      component
    else
      Component.new(component_create_params.except(:id, :duplicate, :component_id, :file).merge({ project: @project }))
    end
  end

  # Defines the set_component method.
  def set_component
    # Loads a Component object with associated rules, reviews,
    # descriptions, checks and additional answers where ID is equal to params id.
    @component = Component.eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
              :additional_answers, :satisfies, :satisfied_by, {
                srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
              }]
    ).find_by(id: params[:id])

    # Returns out of the method If the Component instance variable does exist.
    return if @component.present?

    message = 'The requested component could not be found.'
    respond_to do |format|
      # Return an HTML response with an alert flash message if request format is HTML.
      format.html do
        flash.alert = message
        redirect_back(fallback_location: root_path)
      end
      # Return a JSON response with a toast message if request formt is JSON.
      format.json do
        render json: {
          toast: {
            title: 'Control not found',
            message: message,
            variant: 'danger'
          }
        }, status: :not_found
      end
    end
  end

  # This function sets the rule based on the specified parameters
  def set_rule
    # Extracts the last 6 digits from the stig_id parameter
    stig_id = params[:stig_id]&.last(6)

    # Returns out of the function if stig ID is blank or empty
    return if stig_id.blank?

    # Queries the Rule model with component_id and rule_id as arguments to find a specific rule.
    @rule = Rule.find_by(component_id: params[:id], rule_id: stig_id)

    # If a record for the rule exists, set the instance variable @rule_json to the rule's JSON attribute
    if @rule.present?
      @rule_json = @rule.to_json

      # Else, create an error message and respond to either HTML or JSON requests
    else
      message = 'The requested component and control combination could not be found.'
      respond_to do |format|
        flash.alert = message

        # If html format is requested, redirect back to default page
        format.html do
          redirect_back(fallback_location: root_path)
        end
        format.json do
          # Render a json response in a toast message format
          # as well as setting status code of the response to not_found (404)
          render json: {
            toast: {
              title: 'Control not found',
              message: message,
              variant: 'danger'
            }
          }, status: :not_found
        end
      end
    end
  end

  def set_project
    @project = Project.find(params[:project_id] || @component.project_id)
  end

  def check_permission_to_update_slackchannel
    return if component_update_params[:component_metadata_attributes]&.dig('data', 'Slack Channel ID').blank?

    authorize_admin_component
  end

  # Require admin permissions when updating advanced_fields
  # This is a separate method to avoid overwriting the authorize_admin_component callback for :destroy
  def authorize_admin_for_advanced_fields
    return unless params.dig(:component, :advanced_fields).present?

    authorize_admin_component
  end

  # Require login for viewing released components
  # Separate method to avoid overwriting authorize_logged_in for :search
  def authorize_logged_in_for_released_show
    return unless @component.released

    authorize_logged_in
  end

  def component_update_params
    params.expect(
      component: [:released,
                  :name,
                  :version,
                  :release,
                  :title,
                  :prefix,
                  :description,
                  :admin_name,
                  :admin_email,
                  :advanced_fields,
                  { additional_questions_attributes: [:id, :name, :question_type, :_destroy, { options: [] }],
                    component_metadata_attributes: { data: {} } }]
    )
  end

  def component_create_params
    params.expect(
      component: [:id,
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
                  :admin_name,
                  :admin_email,
                  :file,
                  :slack_channel_id,
                  { file: {} }]
    )
  end
end
