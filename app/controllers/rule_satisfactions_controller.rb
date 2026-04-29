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

      # Save the rule to trigger callbacks (update inspec). Inside the
      # transaction so a save failure rolls back the join-table insert.
      @satisfied_by_rule.save!
      success = true
    end

    if success
      render json: { toast: "Successfully marked #{@rule.version} as satisfied by #{@satisfied_by_rule.version}." }
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

      # Save the rule to trigger callbacks (update inspec). Inside the
      # transaction so a save failure rolls back the join-table delete.
      @satisfied_by_rule.save!
      success = true
    end

    if success
      render json: { toast: "#{@rule.version} is no longer marked as satisfied by #{@satisfied_by_rule.version}." }
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
end
