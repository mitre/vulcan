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
    @rules = @component.rules.eager_load(:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
                                         :additional_answers,
                                         { satisfies: :srg_rule, satisfied_by: :srg_rule },
                                         srg_rule: %i[disa_rule_descriptions rule_descriptions checks])
    @rules_json = RuleBlueprint.render(@rules, view: :editor)
    @component_json = ComponentBlueprint.render(@component, view: :editor)
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
    render json: RuleBlueprint.render_as_hash(@rule, view: :editor)
  end

  def related_rules
    srg_id = @rule.version
    rules = Rule.where(version: srg_id).where.not(id: @rule.id).where.not(component_id: @rule.component_id).eager_load(
      :disa_rule_descriptions, :checks, :component
    )
    stig_rules = StigRule.where(srg_id: srg_id).eager_load(:disa_rule_descriptions, :checks, :stig)
    rules = rules.filter { |r| r.component.all_users.include?(current_user) } unless current_user.admin?
    stig_parents = StigBlueprint.render_as_hash(stig_rules.map(&:stig).uniq, view: :index)
    components = rules.map(&:component).uniq
    ActiveRecord::Associations::Preloader.new(records: components, associations: :project).call
    component_parents = ComponentBlueprint.render_as_hash(components, view: :related)
    parents = (stig_parents + component_parents)

    all_rules = StigRuleBlueprint.render_as_hash(stig_rules) +
                RuleBlueprint.render_as_hash(rules, view: :editor)

    render json: { rules: all_rules, parents: parents }
  end

  def create
    rule = create_or_duplicate
    if rule.save
      # multi-key response (toast +
      # data). Inline the canonical toast object since render_toast
      # doesn't support piggybacking extra response keys.
      render json: {
        toast: { title: 'Control created.', message: ['Successfully created control.'], variant: 'success' },
        data: RuleBlueprint.render_as_hash(rule, view: :editor)
      }
    else
      render json: {
        toast: {
          title: 'Could not create control.',
          message: rule.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  def update
    if @rule.update(rule_update_params)
      render_toast(title: 'Control updated.',
                   message: 'Successfully updated control.',
                   variant: 'success', status: :ok)
    else
      render json: {
        toast: {
          title: 'Could not update control.',
          message: @rule.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
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
      @rule.additional_answers.destroy_all
      @rule.reviews.destroy_all
      @rule.satisfied_by.destroy_all
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
      toast: {
        title: 'Could not delete control.',
        message: 'A database error prevented the delete from completing. The control was not modified.',
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end

  def revert
    Rule.revert(@rule, params[:audit_id], params[:fields], params[:audit_comment])
    # Save the rule to trigger callbacks (update inspec)
    @rule.save
    render_toast(title: 'History reverted.',
                 message: 'Successfully reverted history for control.',
                 variant: 'success', status: :ok)
  rescue RuleRevertError => e
    render json: {
      toast: {
        title: 'Could not revert history.',
        message: e.message,
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end

  def section_locks
    section = params[:section]
    locked = ActiveModel::Type::Boolean.new.cast(params[:locked])
    comment = params[:comment]

    return render json: { error: "Invalid section: #{section}" }, status: :unprocessable_entity unless RuleConstants::LOCKABLE_SECTION_NAMES.include?(section)

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
      rule: RuleBlueprint.render_as_hash(@rule, view: :editor),
      toast: { title: locked ? 'Section locked.' : 'Section unlocked.',
               message: ["#{section} #{locked ? 'locked' : 'unlocked'}"],
               variant: 'success' }
    }
  end

  def bulk_section_locks
    sections = Array(params[:sections])
    locked = ActiveModel::Type::Boolean.new.cast(params[:locked])
    comment = params[:comment]

    invalid = sections - RuleConstants::LOCKABLE_SECTION_NAMES
    return render json: { error: "Invalid sections: #{invalid.join(', ')}" }, status: :unprocessable_entity if invalid.any?

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
      rule: RuleBlueprint.render_as_hash(@rule, view: :editor),
      toast: { title: "Sections #{action_word.downcase}.",
               message: ["#{action_word} #{sections.size} sections"],
               variant: 'success' }
    }
  end

  private

  def authorize_section_lock
    return if current_user&.can_review_component?(@component)

    raise(NotAuthorizedError, 'You are not authorized to manage section locks on this component')
  end

  def create_or_duplicate
    if authorize_author_project.nil? && rule_create_params[:duplicate]
      rule = Rule.find(rule_create_params[:id])
      rule.update_single_rule_clone(true)
      new_rule = rule.amoeba_dup
      new_rule.rule_id = nil
      new_rule
    elsif authorize_admin_project.nil?
      srg = SecurityRequirementsGuide.find_by(id: @component.security_requirements_guide_id)
      db_srg_rule = srg.srg_rules.eager_load(:disa_rule_descriptions, :checks, :rule_descriptions, :references)
                       .where('ident LIKE ?', '%CCI-000366%').first

      rule = Rule.new(
        component: @component,
        srg_rule: db_srg_rule,
        rule_id: (@component.rules.order(:rule_id).pluck(:rule_id).last.to_i + 1).to_s.rjust(6, '0'),
        status: 'Not Yet Determined',
        rule_severity: 'unknown',
        rule_weight: db_srg_rule&.rule_weight || '10.0',
        version: db_srg_rule&.version,
        title: db_srg_rule&.title,
        ident: db_srg_rule&.ident || 'CCI-000366',
        ident_system: db_srg_rule&.ident_system,
        fixtext: db_srg_rule&.fixtext,
        fixtext_fixref: db_srg_rule&.fixtext_fixref,
        fix_id: db_srg_rule&.fix_id
      )
      rule.disa_rule_descriptions.build(db_srg_rule.disa_rule_descriptions.map { |d| d.attributes.except('id', 'base_rule_id') }) if db_srg_rule&.disa_rule_descriptions&.any?
      rule.checks.build(db_srg_rule.checks.map { |c| c.attributes.except('id', 'base_rule_id') }) if db_srg_rule&.checks&.any?
      rule.references.build(db_srg_rule.references.map { |r| r.attributes.except('id', 'base_rule_id') }) if db_srg_rule&.references&.any?
      rule.audits.build(Audited.audit_class.create_initial_rule_audit_from_mapping(@component.id))

      rule
    end
  end

  def rule_create_params
    params.expect(rule: %i[duplicate id])
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

  def manage_lock_params
    params.expect(rule: [:locked])
  end

  def revert_params
    params.permit(:audit_id, :field)
  end

  def set_rule
    @rule = Rule.find(params[:id])
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
