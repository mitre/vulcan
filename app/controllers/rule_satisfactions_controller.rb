# frozen_string_literal: true

##
# Controller for rule satisfactions.
#
class RuleSatisfactionsController < ApplicationController
  before_action :set_component_and_rules
  before_action :authorize_author_component

  def create
    if @rule.satisfies.empty? && (@rule.satisfied_by << @satisfied_by_rule)
      # Save the rule to trigger callbacks (update inspec)
      @satisfied_by_rule.save
      render json: { toast: "Successfully marked #{@rule.version} as satisfied by #{@satisfied_by_rule.version}." }
    else
      render json: {
        toast: {
          title: "Could not mark #{@rule.version} as satisfied by #{@satisfied_by_rule.version}.",
          message: @rule.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @rule.satisfied_by.delete(@satisfied_by_rule)
      # Save the rule to trigger callbacks (update inspec)
      @satisfied_by_rule.save
      render json: { toast: "#{@rule.version} is no longer marked as satisfied by #{@satisfied_by_rule.version}." }
    else
      render json: {
        toast: {
          title: "Could not unmark #{@rule.version} as satisfied by #{@satisfied_by_rule.version}.",
          message: @rule.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  def set_component_and_rules
    @rule = Rule.find(params[:rule_id])
    @satisfied_by_rule = Rule.find(params[:satisfied_by_rule_id])
    @component = @rule.component
  end
end
