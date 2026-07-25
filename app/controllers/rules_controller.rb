# frozen_string_literal: true

##
# Controller for project rules.
#
class RulesController < ApplicationController
  before_action :set_rule, only: %i[show update destroy revert related_rules section_locks bulk_section_locks]
  before_action :set_component, only: %i[index show create update revert related_rules section_locks bulk_section_locks]
  before_action :set_project, only: %i[index show create update revert related_rules section_locks bulk_section_locks]
  before_action :set_project_permissions, only: %i[index]
  before_action :authorize_viewer_component, only: %i[index show related_rules]
  before_action :authorize_author_component, only: %i[create update revert]
  before_action :authorize_admin_project, only: %i[destroy]
  before_action :authorize_section_lock, only: %i[section_locks bulk_section_locks]
  before_action :authorize_logged_in, only: %i[search]

  def index
    # Kind-routed: the editor page serves the component's requirements —
    # authored SrgRules for srg-kind (they carry none of the Rule-only
    # associations), Rules for stig-kind.
    if @component.document_type == 'srg'
      @rules = @component.authored_srg_rules
                         .eager_load(:reviews, :disa_rule_descriptions, :rule_descriptions,
                                     :checks, :derived_from)
      @rules_json = AuthoredSrgRuleBlueprint.render(@rules, view: :editor)
    else
      @rules = @component.rules.eager_load(:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
                                           :additional_answers,
                                           { satisfies: :srg_rule, satisfied_by: :srg_rule },
                                           srg_rule: %i[disa_rule_descriptions rule_descriptions checks])
      @rules_json = RuleBlueprint.render(@rules, view: :editor)
    end
    @component_json = ComponentBlueprint.render(@component, view: :editor, current_user: current_user)
    respond_to do |format|
      format.html
      format.json { render body: @rules_json, content_type: 'application/json' }
    end
  end

  def search
    query = params[:q]
    rules = Rule.joins(component: :project)
                .tap do |o|
      unless current_user.admin
        o.left_joins(component: [{ project: :memberships }])
         .where({ memberships: { user_id: current_user.id } })
      end
    end
                .and(Rule.where(version: query))
                .or(Component.where(released: true).and(Rule.where(version: query)))
                .limit(100)
                .distinct
                .pluck(:id, :rule_id, Component.arel_table[:id], Component.arel_table[:prefix])
    render json: {
      rules: rules
    }
  end

  def show
    summary = Reaction.summary(@rule.reviews.map(&:id), current_user&.id)
    blueprint = @rule.is_a?(SrgRule) ? AuthoredSrgRuleBlueprint : RuleBlueprint
    render json: blueprint.render_as_json(@rule, view: :editor, reactions_summary: summary)
  end

  def related_rules
    # Related-rule search keys off the Rule's SRG version linkage;
    # authored requirements have no equivalent surface yet.
    return render_not_found unless @rule.is_a?(Rule)

    srg_id = @rule.version
    rules = Rule.where(version: srg_id).where.not(id: @rule.id).where.not(component_id: @rule.component_id).eager_load(
      :disa_rule_descriptions, :checks, :component
    )
    stig_rules = StigRule.where(srg_id: srg_id).eager_load(:disa_rule_descriptions, :checks, :stig)
    rules = rules.filter { |r| r.component.all_users.include?(current_user) } unless current_user.admin?
    stig_parents = StigBlueprint.render_as_json(stig_rules.map(&:stig).uniq, view: :index)
    components = rules.map(&:component).uniq
    ActiveRecord::Associations::Preloader.new(records: components, associations: :project).call
    component_parents = ComponentBlueprint.render_as_json(components, view: :related)
    parents = (stig_parents + component_parents)

    all_rules = StigRuleBlueprint.render_as_json(stig_rules) +
                RuleBlueprint.render_as_json(rules, view: :editor)

    render json: { rules: all_rules, parents: parents }
  end

  def create
    # One kind-routed create: a stig component creates a Rule, an srg
    # component creates an authored SrgRule — the correct STI class
    # through the seam, so a class-Rule row never lands on an srg
    # component (counted by rules_count, invisible to requirements and
    # backups). Content applies at creation — one call, both kinds.
    requirement = rule_create_params[:duplicate] ? duplicate_requirement : build_blank_requirement
    return if performed?

    apply_creation_content(requirement)
    if requirement.save
      # multi-key response (toast +
      # data). Inline the canonical toast object since render_toast
      # doesn't support piggybacking extra response keys.
      render json: {
        toast: Toast.new(title: 'Control created.', message: ['Successfully created control.'], variant: 'success'),
        data: serialized_requirement(requirement)
      }
    else
      render json: {
        toast: Toast.new(
          title: 'Could not create control.',
          message: requirement.errors.full_messages,
          variant: 'danger'
        )
      }, status: :unprocessable_content
    end
  end

  def update
    permitted = rule_update_params
    # Authored SrgRules carry no additional answers; the rest of the
    # permitted set is shared base_rules content.
    permitted = permitted.except(:additional_answers_attributes) unless @rule.is_a?(Rule)
    if @rule.update(permitted)
      render_toast(title: 'Control updated.',
                   message: 'Successfully updated control.',
                   variant: 'success', status: :ok)
    else
      render json: {
        toast: Toast.new(
          title: 'Could not update control.',
          message: @rule.errors.full_messages,
          variant: 'danger'
        )
      }, status: :unprocessable_content
    end
  end

  def destroy
    warnings = []
    warnings << 'This control was locked.' if @rule.locked
    warnings << 'This control was under review.' if @rule.review_requestor_id.present?

    # Wrap soft-delete + dependent cleanup in a single transaction so a
    # failure in any destroy_all rolls back the rule's deleted_at column.
    # Without this, a mid-cleanup failure left the rule soft-deleted with
    # orphan additional_answers / reviews / satisfied_by rows.
    Rule.transaction do
      # rubocop:disable Rails/SkipsModelValidations -- soft-delete must bypass validations/callbacks
      @rule.update_columns(deleted_at: Time.zone.now, updated_at: Time.zone.now)
      # rubocop:enable Rails/SkipsModelValidations
      @rule.reviews.destroy_all
      if @rule.is_a?(Rule)
        # Rule-only dependents and the Rule-only counter cache — authored
        # SrgRules have neither (their count is a live scoped query).
        @rule.additional_answers.destroy_all
        @rule.satisfied_by.destroy_all
        # Soft-delete bypasses the counter_cache callbacks (they only track
        # hard create/destroy), so recount from the association — Rule's
        # default scope already excludes deleted rows.
        Component.reset_counters(@rule.component_id, :rules)
      end
    end

    Rails.logger.warn("Rule #{@rule.rule_id} (id=#{@rule.id}) deleted by #{current_user.email}: #{warnings.join(' ')}") if warnings.any?

    message = 'Successfully deleted control.'
    message += " Warning: #{warnings.join(' ')}" if warnings.any?
    render_toast(title: 'Control deleted.',
                 message: message,
                 variant: warnings.any? ? 'warning' : 'success',
                 status: :ok)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
    Rails.logger.error("Rule destroy failed for rule_id=#{@rule.id} user=#{current_user.id}: #{e.message}")
    render json: {
      toast: Toast.new(
        title: 'Could not delete control.',
        message: 'A database error prevented the delete from completing. The control was not modified.',
        variant: 'danger'
      )
    }, status: :unprocessable_content
  end

  def revert
    # History revert is Rule machinery; no authored-requirement revert
    # path exists yet.
    return render_not_found unless @rule.is_a?(Rule)

    Rule.revert(@rule, params[:audit_id], params[:fields], params[:audit_comment])
    # Save the rule to trigger callbacks (update inspec)
    @rule.save
    render_toast(title: 'History reverted.',
                 message: 'Successfully reverted history for control.',
                 variant: 'success', status: :ok)
  rescue RuleRevertError => e
    render json: {
      toast: Toast.new(
        title: 'Could not revert history.',
        message: e.message,
        variant: 'danger'
      )
    }, status: :unprocessable_content
  end

  def section_locks
    section = params[:section]
    locked = ActiveModel::Type::Boolean.new.cast(params[:locked])
    comment = params[:comment]

    return render json: { error: "Invalid section: #{section}" }, status: :unprocessable_content unless RuleConstants::LOCKABLE_SECTION_NAMES.include?(section)

    fields = @rule.locked_fields.dup
    if locked
      fields[section] = true
    else
      fields.delete(section)
    end

    @rule.audit_comment = comment.presence || "#{locked ? 'Locked' : 'Unlocked'} section: #{section}"
    @rule.update!(locked_fields: fields)

    # multi-key response (rule + toast).
    render json: {
      rule: serialized_requirement(@rule),
      toast: Toast.new(title: locked ? 'Section locked.' : 'Section unlocked.',
                       message: ["#{section} #{locked ? 'locked' : 'unlocked'}"],
                       variant: 'success')
    }
  end

  def bulk_section_locks
    sections = Array(params[:sections])
    locked = ActiveModel::Type::Boolean.new.cast(params[:locked])
    comment = params[:comment]

    invalid = sections - RuleConstants::LOCKABLE_SECTION_NAMES
    return render json: { error: "Invalid sections: #{invalid.join(', ')}" }, status: :unprocessable_content if invalid.any?

    fields = @rule.locked_fields.dup
    sections.each do |section|
      if locked
        fields[section] = true
      else
        fields.delete(section)
      end
    end

    action_word = locked ? 'Locked' : 'Unlocked'
    @rule.audit_comment = comment.presence || "#{action_word} sections: #{sections.join(', ')}"
    @rule.update!(locked_fields: fields)

    # multi-key response (rule + toast).
    render json: {
      rule: serialized_requirement(@rule),
      toast: Toast.new(title: "Sections #{action_word.downcase}.",
                       message: ["#{action_word} #{sections.size} sections"],
                       variant: 'success')
    }
  end

  private

  def authorize_section_lock
    return if current_user&.can_review_component?(@component)

    raise(NotAuthorizedError, 'You are not authorized to manage section locks on this component')
  end

  # Duplication is an author action; the source must live in THIS
  # component — an unscoped find would let an author on one component
  # inject clones into another. The copy mechanic is per-class: amoeba
  # for Rule, dup_with_nested_records for SrgRule (amoeba retypes an
  # SrgRule to Rule by design — never use it for authored copies).
  def duplicate_requirement
    authorize_author_project
    source = @component.requirements.find(rule_create_params[:id])
    copy = if source.is_a?(SrgRule)
             source.dup_with_nested_records
           else
             source.update_single_rule_clone(true)
             source.amoeba_dup
           end
    copy.rule_id = nil
    copy
  end

  # Blank/content create is a project-admin action on both kinds.
  def build_blank_requirement
    authorize_admin_project
    if @component.document_type == 'srg'
      # Net-new authored requirements have no derived_from to inherit
      # severity from — medium (CAT II) is the DISA-conventional default,
      # the same value the STIG path inherits from its baseline row.
      # Overridable in the same request via rule_severity.
      return @component.authored_srg_rules.new(status: RuleConstants::STATUS_NYD, rule_severity: 'medium')
    end

    build_rule_from_template
  end

  # A new STIG control seeds from the source SRG's CCI-000366 baseline
  # row — severity and weight are INHERITED from it, never fabricated
  # (an out-of-vocabulary placeholder made every blank create 422).
  def build_rule_from_template
    srg = SecurityRequirementsGuide.find_by(id: @component.security_requirements_guide_id)
    template = if srg
                 srg.srg_rules
                    .eager_load(:disa_rule_descriptions, :checks, :rule_descriptions, :references)
                    .find_by('ident LIKE ?', '%CCI-000366%')
               end
    if template.nil?
      render json: {
        toast: Toast.new(title: 'Could not create control.',
                         message: ['The source SRG has no CCI-000366 baseline requirement to seed a new control from.'],
                         variant: 'danger')
      }, status: :unprocessable_content
      return
    end

    rule = Rule.new(
      component: @component,
      srg_rule: template,
      status: RuleConstants::STATUS_NYD,
      rule_severity: template.rule_severity,
      rule_weight: template.rule_weight || '10.0',
      version: template.version,
      title: template.title,
      ident: template.ident,
      ident_system: template.ident_system,
      fixtext: template.fixtext,
      fixtext_fixref: template.fixtext_fixref,
      fix_id: template.fix_id
    )
    build_template_nested_records(rule, template)
    # No manual audit build here: the bulk-shaped initial audit (user_type
    # System) exists for import paths that bypass callbacks — an
    # interactive save gets its real create audit from audited, with the
    # acting user attributed.
    rule
  end

  # Template nested records seed only the associations the request does
  # not provide — provided nested attributes REPLACE the defaults, they
  # never land beside them.
  def build_template_nested_records(rule, template)
    provided = rule_content_params(rule)
    # References carry no request surface, so the template's always seed.
    %i[disa_rule_descriptions checks references].each do |assoc|
      rows = template.public_send(assoc)
      next if rows.none? || provided[:"#{assoc}_attributes"].present?

      rule.public_send(assoc).build(rows.map { |r| r.attributes.except('id', 'base_rule_id') })
    end
  end

  # The one-call content surface, uniform across modes: provided nested
  # attributes replace the would-be defaults or copied records.
  def apply_creation_content(requirement)
    content = rule_content_params(requirement)
    %i[checks disa_rule_descriptions rule_descriptions].each do |assoc|
      requirement.public_send(:"#{assoc}=", []) if content[:"#{assoc}_attributes"].present?
    end
    requirement.assign_attributes(content)
  end

  def rule_create_params
    params.expect(rule: %i[duplicate id])
  end

  # The update-equivalent content surface at creation — the ONE permit
  # list (rule_update_params) with the persistence keys stripped from
  # nested records (nothing exists yet to target). Numbering is
  # server-owned: rule_id is never in the permit list.
  def rule_content_params(requirement)
    permitted = rule_update_params
    permitted = permitted.except(:additional_answers_attributes) unless requirement.is_a?(Rule)
    %i[checks_attributes rule_descriptions_attributes
       disa_rule_descriptions_attributes additional_answers_attributes].each do |key|
      next if permitted[key].blank?

      permitted[key] = permitted[key].map { |attrs| attrs.except(:id, :_destroy) }
    end
    permitted
  end

  def rule_update_params
    # Rails 8: Use require.permit for nested array attributes (checks_attributes, etc.)
    # params.expect doesn't handle nested arrays well - causes them to be filtered out
    # See: https://github.com/mitre/vulcan/issues/692
    # rubocop:disable Rails/StrongParametersExpect -- params.expect breaks nested attributes (issue #692)
    params.require(:rule).permit(
      :status, :status_justification, :artifact_description, :vendor_comments,
      :rule_severity, :rule_weight, :version, :title, :ident, :ident_system, :fixtext,
      :fix_id, :fixtext_fixref, :audit_comment, :inspec_control_body, :inspec_control_file,
      :inspec_control_body_lang, :inspec_control_file_lang,
      checks_attributes: %i[id system content_ref_name content_ref_href content _destroy],
      rule_descriptions_attributes: %i[id description _destroy],
      additional_answers_attributes: %i[id additional_question_id answer],
      disa_rule_descriptions_attributes: %i[
        id vuln_discussion false_positives false_negatives documentable mitigations_available
        mitigations poam_available poam severity_override_guidance potential_impacts
        third_party_tools mitigation_control responsibility ia_controls _destroy
      ]
    )
    # rubocop:enable Rails/StrongParametersExpect
  end

  def set_rule
    # Requirement rows of any STI type (Rule or authored SrgRule) — a
    # Rule-classed find would 404 reads/updates of authored requirements.
    @rule = BaseRule.where(deleted_at: nil).where.not(component_id: nil).find(params[:id])
  end

  # Kind-routed editor serialization for a single requirement row.
  def serialized_requirement(rule)
    blueprint = rule.is_a?(SrgRule) ? AuthoredSrgRuleBlueprint : RuleBlueprint
    blueprint.render_as_json(rule, view: :editor)
  end

  def set_component
    @component = if @rule
                   @rule.component
                 else
                   Component.find(params[:component_id] || params.dig(:rule, :component_id))
                 end
  end

  def set_project
    @project = if @component
                 @component.project
               else
                 Project.includes({ rules: %i[reviews checks disa_rule_descriptions rule_descriptions
                                              additional_answers] })
                        .find(@component.project_id || params[:project_id] || params.dig(:rule, :project_id))
               end
  end
end
