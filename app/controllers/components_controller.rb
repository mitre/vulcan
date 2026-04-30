# frozen_string_literal: true

##
# Components for project relationships.
#
class ComponentsController < ApplicationController
  include Exportable
  include UploadValidatable

  EXPORT_ERROR_TITLE = 'Export error'
  NO_FILE_PROVIDED = 'No file provided'
  CONTROL_NOT_FOUND_TITLE = 'Control not found'

  before_action :set_component, only: %i[show update destroy export preview_spreadsheet_update apply_spreadsheet_update triage]
  before_action :set_component_basic, only: %i[find based_on_same_srg histories comments]
  before_action :set_project, only: %i[show create history triage]
  before_action :set_component_permissions, only: %i[show triage]
  before_action :set_rule, only: %i[show]
  before_action :authorize_admin_project, only: %i[create]
  before_action :authorize_admin_component, only: %i[destroy]
  before_action :authorize_author_component, only: %i[update preview_spreadsheet_update apply_spreadsheet_update]
  before_action :check_permission_to_update_slackchannel, only: %i[update]
  before_action :check_admin_for_advanced_fields, only: %i[update]
  before_action :authorize_component_access, only: %i[show export find histories comments triage]
  before_action :authorize_logged_in, only: %i[search index based_on_same_srg bulk_export detect_srg]
  before_action :authorize_compare_access, only: %i[compare]
  before_action :authorize_viewer_project, only: %i[history]
  before_action :validate_component_upload, only: %i[create detect_srg]

  def index
    components = Component.with_severity_counts
                          .eager_load(:based_on)
                          .where(released: true)

    respond_to do |format|
      format.html { @components_json = ComponentBlueprint.render(components, view: :index) }
      format.json { @components_json = components } # Jbuilder uses the relation
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
    respond_to do |format|
      format.html do
        view = @effective_permissions ? :editor : :show
        @component_json = ComponentBlueprint.render(@component, view: view, **blueprint_render_options)
        @project_json = @component.project.to_json
      end
      format.json do
        if @effective_permissions
          # Editor refresh: use blueprint directly so the refreshComponent() response
          # shape exactly matches the initial render and nothing drifts (e.g.,
          # memberships losing their MembershipBlueprint name/email decoration).
          render json: ComponentBlueprint.render(@component, view: :editor, **blueprint_render_options)
        else
          # Non-member: jbuilder produces a BenchmarkViewer-specific lightweight
          # rule shape that the :show blueprint view does not.
          render :show
        end
      end
    end
  end

  def create
    component = create_or_duplicate
    # When importing from an existing spreadsheet, some errors are set before
    # save, this makes sure those errors are shown and not overwritten by the
    # component validators.
    # Suppress auditing during initial save of duplicated components —
    # original audit history is copied in bulk by duplicate_reviews_and_history.
    # This avoids creating 200+ redundant audit records per rule.
    is_duplicate = component_create_params[:duplicate] || component_create_params[:copy_component]
    Audited.auditing_enabled = false if is_duplicate
    begin
      if component.errors.empty? && component.save
        Audited.auditing_enabled = true
        component.admin_name = component_create_params[:admin_name].presence || current_user.name
        component.admin_email = component_create_params[:admin_email].presence || current_user.email
        component.duplicate_reviews_and_history(component_create_params[:id])
        component.create_rule_satisfactions if component_create_params[:file]
        component.rules_count = component.rules.where(deleted_at: nil).size
        if component_create_params[:slack_channel_id].present?
          component.component_metadata_attributes = { data: {
            'Slack Channel ID' => component_create_params[:slack_channel_id]
          } }
        end
        component.save
        safely_notify('create_component') { send_slack_notification(:create_component, component) } if Settings.slack.enabled
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
    ensure
      Audited.auditing_enabled = true
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
    # Render is intentionally OUTSIDE the transaction. Calling render inside
    # the block was a latent DoubleRenderError trap: if the transaction's
    # commit phase raised (e.g. deadlock, serialization failure), the rescue
    # below would call render a second time and surface a 500 to the user.
    ActiveRecord::Base.transaction do
      rule_ids = Rule.unscoped.where(component_id: @component.id).ids

      if rule_ids.any?
        # Bulk-delete dependent records first (avoid N+1 destroy callbacks)
        Review.where(rule_id: rule_ids).delete_all
        AdditionalAnswer.where(rule_id: rule_ids).delete_all
        RuleSatisfaction.where(rule_id: rule_ids).or(RuleSatisfaction.where(satisfied_by_rule_id: rule_ids)).delete_all
        Audited::Audit.where(auditable_type: 'BaseRule', auditable_id: rule_ids).delete_all
        Check.where(base_rule_id: rule_ids).delete_all
        DisaRuleDescription.where(base_rule_id: rule_ids).delete_all
        RuleDescription.where(base_rule_id: rule_ids).delete_all
        Rule.unscoped.where(id: rule_ids).delete_all
      end

      @component.destroy!
      send_slack_notification(:remove_component, @component) if Settings.slack.enabled
    end

    render json: { toast: 'Successfully removed component from project.' }
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
    unless %i[csv inspec xccdf json_archive].include?(export_type)
      render json: {
        toast: {
          title: EXPORT_ERROR_TITLE,
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
          perform_export(
            exportable: @component, mode: :working_copy, format: :csv,
            filename: "#{@component.project.name}-#{@component.prefix}.csv"
          )
        when :inspec
          export_mode = params[:mode]&.to_sym || :published_stig
          perform_export(
            exportable: @component, mode: export_mode, format: :inspec,
            filename: "#{@component[:name].tr(' ', '-')}-#{version}#{release}-stig-baseline.zip"
          )
        when :xccdf
          perform_export(
            exportable: @component, mode: :published_stig, format: :xccdf,
            filename: "#{@component[:name].tr(' ', '-')}-#{version}#{release}-xccdf.xml"
          )
        when :json_archive
          perform_export(
            exportable: @component, mode: :backup, format: :json_archive,
            filename: "vulcan-backup-#{@component[:name].tr(' ', '-')}-#{version}#{release}.zip"
          )
        end
      end
      # JSON responses are just used to validate ahead of time that this
      # component can actually be exported
      format.json { render json: { status: :ok } }
    end
  end

  def bulk_export
    export_type = params[:type]&.to_sym

    unless %i[csv xccdf inspec].include?(export_type)
      render json: {
        toast: {
          title: EXPORT_ERROR_TITLE,
          message: "Unsupported export type: #{export_type}",
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    component_ids = params[:component_ids]&.split(',')&.map(&:to_i)
    if component_ids.blank?
      render json: {
        toast: {
          title: EXPORT_ERROR_TITLE,
          message: 'No components selected for export.',
          variant: 'danger'
        }
      }, status: :bad_request
      return
    end

    components = Component.where(id: component_ids, released: true)

    respond_to do |format|
      format.html do
        case export_type
        when :csv
          perform_export(
            exportable: components.to_a, mode: :working_copy, format: :csv,
            zip_filename: 'components_export.zip'
          )
        when :xccdf
          perform_export(
            exportable: components.to_a, mode: :published_stig, format: :xccdf,
            zip_filename: 'components_export.zip'
          )
        when :inspec
          perform_export(
            exportable: components.to_a, mode: :published_stig, format: :inspec,
            zip_filename: 'components_inspec.zip'
          )
        else
          head :unprocessable_entity
        end
      end
      format.json { render json: { status: :ok } }
    end
  end

  def histories
    return head :not_found unless @component

    render json: @component.histories(50)
  end

  # GET /components/:id/triage — full-page triage view for a single
  # component's public-comment queue. Renders an HTML page that mounts a
  # Vue app (ComponentTriagePage). The Vue app fetches rows from the
  # JSON endpoint at GET /components/:id/comments. Replaces the legacy
  # comments slideover (PR #717 follow-on).
  #
  # HTML-only — JSON requests return 406, since the data lives on the
  # /components/:id/comments JSON endpoint.
  def triage
    respond_to do |format|
      format.html do
        @component_json = ComponentBlueprint.render(@component, view: :show)
        @project_json = @component.project.to_json
      end
      # Explicit 406 for non-HTML formats so the catch-all StandardError
      # rescue doesn't turn a missing-template into a 500.
      format.any { head :not_acceptable }
    end
  end

  # Paginated triage table backing the public-comment-review workflow (PR #717).
  # Returns { rows: [...], pagination: {...} }. DISA-native vocab on the wire
  # (triage_status / section keys); frontend translates via triageVocabulary.js.
  #
  # Sets Cache-Control: no-store so concurrent triagers cannot get a stale
  # snapshot from a browser/proxy cache during a public-comment window.
  def comments
    return head :not_found unless @component

    result = @component.paginated_comments(
      triage_status: params[:triage_status].presence || 'pending',
      section: params[:section].presence,
      rule_id: params[:rule_id].presence,
      author_id: params[:author_id].presence,
      query: params[:q].presence,
      page: params[:page].presence || 1,
      per_page: params[:per_page].presence || 25,
      resolved: params[:resolved].presence || 'all'
    )

    response.headers['Cache-Control'] = 'no-store'
    render json: result
  end

  def based_on_same_srg
    return head :not_found unless @component&.based_on

    srg_title = @component.based_on.title
    accessible_project_ids = current_user.available_projects.ids
    render json: Component.where(based_on: SecurityRequirementsGuide.where(title: srg_title))
                          .where.not(id: params[:id])
                          .where(project_id: accessible_project_ids)
                          .or(Component.where(based_on: SecurityRequirementsGuide.where(title: srg_title))
                                       .where.not(id: params[:id])
                                       .where(released: true))
                          .distinct
                          .order(:project_id)
                          .joins(:project)
                          .select('components.id, components.name, components.version, components.prefix, ' \
                                  'components.release, components.project_id, projects.name AS project_name')
                          .map(&:attributes)
  end

  def compare
    base_component = Component.find_by(id: params[:id])
    diff_component = Component.find_by(id: params[:diff_id])
    return head :not_found unless base_component && diff_component

    base = base_component.rules.pluck(:rule_id, :inspec_control_file).to_h
    diff = diff_component.rules.pluck(:rule_id, :inspec_control_file).to_h
    render json: base.keys.union(diff.keys).sort.index_with { |rule_id|
      { base: base[rule_id], diff: diff[rule_id], changed: base[rule_id] != diff[rule_id] }
    }
  end

  def history
    history = []
    components = @project.components.where(name: params[:name])
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

  def detect_srg
    file = params[:file]
    unless file
      render json: { error: NO_FILE_PROVIDED }, status: :unprocessable_entity
      return
    end

    srg_ids = SpreadsheetParser.peek_srg_ids(file)
    if srg_ids.empty?
      render json: { error: 'No SRG IDs found in spreadsheet' }, status: :unprocessable_entity
      return
    end

    # Find which SRGs these rule IDs belong to
    rules = SrgRule.where(version: srg_ids).includes(:security_requirements_guide)
    srgs = rules.map(&:security_requirements_guide).uniq

    if srgs.empty?
      render json: { error: 'Could not identify a matching SRG for the IDs in this spreadsheet' },
             status: :unprocessable_entity
    elsif srgs.size > 1
      names = srgs.map { |s| "#{s.title} (#{s.version})" }.join(', ')
      render json: { error: "SRG IDs map to multiple SRGs: #{names}. Please select manually." },
             status: :unprocessable_entity
    else
      srg = srgs.first
      render json: { id: srg.id, srg_id: srg.srg_id, title: srg.title, version: srg.version }
    end
  end

  def preview_spreadsheet_update
    file = params[:file]
    unless file
      render json: { error: NO_FILE_PROVIDED }, status: :unprocessable_entity
      return
    end

    result = @component.update_from_spreadsheet(file)
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result
    end
  end

  def apply_spreadsheet_update
    file = params[:file]
    unless file
      render json: { error: NO_FILE_PROVIDED }, status: :unprocessable_entity
      return
    end

    result = @component.apply_spreadsheet_update(file, current_user)
    if result[:success]
      render json: { toast: "Successfully updated #{result[:count]} rules from spreadsheet." }
    elsif result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def find
    find_param = params.require(:find).downcase
    component_id = params.require(:id)

    rules = Component.find_by(id: component_id).rules
    checks = Check.where(base_rule: rules).where('LOWER(content) LIKE ?', "%#{find_param}%")
    descriptions = DisaRuleDescription.where(base_rule: rules).where(
      'LOWER(vuln_discussion) LIKE ? OR LOWER(mitigations) LIKE ?', "%#{find_param}%", "%#{find_param}%"
    )
    rules = rules.where(
      "LOWER(title) LIKE ? OR
      LOWER(fixtext) LIKE ? OR
      LOWER(vendor_comments) LIKE ? OR
      LOWER(status_justification) LIKE ? OR
      LOWER(artifact_description) LIKE ? OR
      id IN (?) ", "%#{find_param}%", "%#{find_param}%", "%#{find_param}%", "%#{find_param}%",
      "%#{find_param}%", checks.pluck(:base_rule_id) | descriptions.pluck(:base_rule_id)
    )
                 .order(:rule_id)

    render json: RuleBlueprint.render_as_hash(rules, view: :editor)
  end

  private

  # Render options shared by ComponentBlueprint calls — surfaces
  # pending_comment_count + pending_comment_counts so the page header
  # banner (CommentPeriodBanner) and any per-rule callouts have the
  # accurate count. Without this, the blueprint defaults to zero.
  def blueprint_render_options
    { pending_comment_counts: Component.pending_comment_counts([@component.id]) }
  end

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

  # Defines the set_component method.
  def set_component
    # Loads a Component object with associated rules, reviews,
    # descriptions, checks and additional answers where ID is equal to params id.
    @component = Component.eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
              :additional_answers,
              { satisfies: :srg_rule },
              { satisfied_by: :srg_rule },
              { srg_rule: %i[disa_rule_descriptions rule_descriptions checks] }]
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
            title: CONTROL_NOT_FOUND_TITLE,
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
      @rule_json = RuleBlueprint.render(@rule, view: :editor)

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
              title: CONTROL_NOT_FOUND_TITLE,
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

  # Lightweight component loader for actions that don't need eager-loaded rules
  def set_component_basic
    @component = Component.find_by(id: params[:id])
    return if @component.present?

    message = 'The requested component could not be found.'
    respond_to do |format|
      format.html do
        flash.alert = message
        redirect_back(fallback_location: root_path)
      end
      format.json do
        render json: {
          toast: { title: CONTROL_NOT_FOUND_TITLE, message: message, variant: 'danger' }
        }, status: :not_found
      end
    end
  end

  # Authorize access to component based on released status:
  # - Released components: any authenticated user
  # - Unreleased components: must be project/component member
  def authorize_component_access
    if @component&.released
      authorize_logged_in
    else
      authorize_viewer_component
    end
  end

  # Authorize admin for advanced_fields changes on update
  def check_admin_for_advanced_fields
    return if params.dig(:component, :advanced_fields).nil?

    authorize_admin_component
  end

  # Authorize access to both components in a compare operation
  def authorize_compare_access
    base = Component.find_by(id: params[:id])
    diff = Component.find_by(id: params[:diff_id])

    [base, diff].each do |component|
      next if component.nil?
      next if component.released

      @component = component
      authorize_viewer_component
    end
  end

  def check_permission_to_update_slackchannel
    slack_id = params.dig(:component, :component_metadata_attributes, :data, 'Slack Channel ID')
    return if slack_id.blank?

    authorize_admin_component
  end

  def component_update_params
    # rubocop:disable Rails/StrongParametersExpect -- params.expect breaks nested array attributes (issue #692)
    params.require(:component).permit(
      :released, :name, :version, :release, :title, :prefix,
      :description, :admin_name, :admin_email, :advanced_fields,
      :comment_phase, :comment_period_starts_at, :comment_period_ends_at,
      additional_questions_attributes: [:id, :name, :question_type, :_destroy, { options: [] }],
      component_metadata_attributes: { data: {} }
    )
    # rubocop:enable Rails/StrongParametersExpect
  end

  def validate_component_upload
    file = params.dig(:component, :file)
    return if file.blank? # no file = creating from SRG, not spreadsheet import

    validate_upload_size(file, 50.megabytes) && validate_upload_type(file, %w[.xlsx .csv])
  end

  def component_create_params
    # rubocop:disable Rails/StrongParametersExpect -- params.expect breaks nested array attributes (issue #692)
    params.require(:component).permit(
      :id, :duplicate, :copy_component, :component_id, :project_id,
      :security_requirements_guide_id, :name, :prefix, :version, :release,
      :title, :description, :admin_name, :admin_email, :file, :slack_channel_id
    )
    # rubocop:enable Rails/StrongParametersExpect
  end
end
