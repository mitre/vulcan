# frozen_string_literal: true

##
# Controller for rule satisfactions.
#
class RuleSatisfactionsController < ApplicationController
  before_action :set_component_and_rules
  before_action :authorize_author_component

  def create
    success = false
    Rule.transaction do
      raise ActiveRecord::Rollback unless @rule.satisfies.empty? && (@rule.satisfied_by << @satisfied_by_rule)

      apply_adnm_status(@rule, @satisfied_by_rule)

      @satisfied_by_rule.save!
      success = true
    end

    if success
      render_toast(title: 'Satisfied-by recorded.',
                   message: "Successfully marked #{@rule.version} as satisfied by #{@satisfied_by_rule.version}.",
                   variant: 'success', status: :ok)
    else
      render_satisfaction_failure('mark', @rule.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
    Rails.logger.error("RuleSatisfaction create failed for rule_id=#{@rule.id}: #{e.message}")
    render_satisfaction_failure('mark', ['A database error prevented the change from being applied.'])
  end

  def destroy
    success = false
    Rule.transaction do
      raise ActiveRecord::Rollback unless @rule.satisfied_by.delete(@satisfied_by_rule)

      revert_adnm_status(@rule)

      @satisfied_by_rule.save!
      success = true
    end

    if success
      render_toast(title: 'Satisfied-by removed.',
                   message: "#{@rule.version} is no longer marked as satisfied by #{@satisfied_by_rule.version}.",
                   variant: 'success', status: :ok)
    else
      render_satisfaction_failure('unmark', @rule.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
    Rails.logger.error("RuleSatisfaction destroy failed for rule_id=#{@rule.id}: #{e.message}")
    render_satisfaction_failure('unmark', ['A database error prevented the change from being applied.'])
  end

  private

  def render_satisfaction_failure(verb, message)
    render json: {
      toast: {
        title: "Could not #{verb} #{@rule.version} as satisfied by #{@satisfied_by_rule.version}.",
        message: message,
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end

  def set_component_and_rules
    @rule = Rule.find(params[:rule_id])
    @satisfied_by_rule = Rule.find(params[:satisfied_by_rule_id])
    @component = @rule.component
  end

  def apply_adnm_status(child, parent)
    parent_label = "#{parent.component.prefix}-#{parent.rule_id}"
    parent_title = parent.title.presence || parent.srg_rule&.title || parent_label

    child.update!(
      status: 'Applicable - Does Not Meet',
      status_justification: "This requirement is addressed by #{parent_label} (#{parent_title}).",
      audit_comment: "Auto-set ADNM: satisfied by #{parent_label} (was: #{child.status})"
    )

    drd = child.disa_rule_descriptions.first_or_create!
    drd.update!(
      mitigations: "This requirement is fully mitigated by #{parent_label}. " \
                   'With the implementation of this mitigation, the overall risk is fully mitigated.'
    )
  end

  def revert_adnm_status(child)
    original_status = find_pre_nesting_status(child)

    child.update!(
      status: original_status,
      status_justification: nil,
      audit_comment: "Reverted to #{original_status}: satisfaction removed"
    )

    drd = child.disa_rule_descriptions.first
    drd&.update!(mitigations: nil)
  end

  def find_pre_nesting_status(child)
    nesting_audit = child.audits
                         .where("comment LIKE 'Auto-set ADNM:%'")
                         .order(created_at: :desc)
                         .first

    if nesting_audit&.comment&.match(/\(was: (.+)\)/)
      Regexp.last_match(1)
    else
      'Not Yet Determined'
    end
  end
end
