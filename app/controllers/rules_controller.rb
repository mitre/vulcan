# frozen_string_literal: true

##
# Controller for project rules.
#
class RulesController < ApplicationController
  before_action :set_rule, only: %i[show update manage_lock]
  before_action :set_project, only: %i[index show update manage_lock]
  before_action :authorize_edit_project, only: %i[index update show]
  before_action :authorize_review_project, only: %i[manage_lock]

  def index
    @rules = @project.rules
  end

  def show
    render json: @rule
  end

  def update
    if @rule.update(rule_update_params)
      render json: { notice: 'Successfully updated rule.' }
    else
      render json: { alert: "Could not update rule. #{@rule.errors.full_messages}" }
    end
  end

  def manage_lock
    return if @rule.locked == manage_lock_params[:locked]

    # rubocop:disable Rails/SkipsModelValidations
    @rule.update_attribute(:locked, manage_lock_params[:locked])
    # rubocop:enable Rails/SkipsModelValidations
    render json: { notice: "Successfully #{manage_lock_params[:locked] ? 'locked' : 'unlocked'} rule." }
  end

  private

  def rule_update_params
    params.require(:rule).permit(:description)
  end

  def manage_lock_params
    params.require(:rule).permit(:locked)
  end

  def set_rule
    @rule = Rule.find(params[:id])
  end

  def set_project
    @project = if @rule
                 @rule.project
               else
                 Project.find(params[:project_id])
               end
  end
end
