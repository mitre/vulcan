# frozen_string_literal: true

##
# Controller for project rules.
#
class RulesController < ApplicationController
  before_action :set_rule, only: %i[show update manage_lock revert]
  before_action :set_project, only: %i[index show update manage_lock revert]
  before_action :set_project_permissions, only: %i[index]
  before_action :authorize_author_project, only: %i[index update show revert]
  before_action :authorize_review_project, only: %i[manage_lock]

  def index
    @rules = @project.rules
  end

  def show
    render json: @rule
  end

  def update
    if @rule.update(rule_update_params)
      render json: { notice: 'Successfully updated control.' }
    else
      render json: { alert: "Could not update control. #{@rule.errors.full_messages}" }
    end
  rescue RuleLockedError => e
    render json: { alert: e.message }
  end

  def manage_lock
    return if @rule.locked == manage_lock_params[:locked]

    # rubocop:disable Rails/SkipsModelValidations
    @rule.update_attribute(:locked, manage_lock_params[:locked])
    # rubocop:enable Rails/SkipsModelValidations
    render json: { notice: "Successfully #{manage_lock_params[:locked] ? 'locked' : 'unlocked'} control." }
  end

  def revert
    Rule.revert(@rule, params[:audit_id], params[:fields], params[:audit_comment])
    render json: { notice: 'Successfully reverted history for control.' }
  rescue RuleRevertError => e
    render json: { alert: e.message }
  end

  private

  def rule_update_params
    params.require(:rule).permit(
      :status, :status_justification, :artifact_description, :vendor_comments,
      :rule_severity, :rule_weight, :version, :title, :ident, :ident_system, :fixtext,
      :fix_id, :fixtext_fixref, :audit_comment,
      checks_attributes: %i[id system content_ref_name content_ref_href content _destroy],
      rule_descriptions_attributes: %i[id description _destroy],
      disa_rule_descriptions_attributes: %i[
        id vuln_discussion false_positives false_negatives documentable mitigations
        severity_override_guidance potential_impacts third_party_tools mitigation_control
        responsibility ia_controls _destroy
      ]
    )
  end

  def manage_lock_params
    params.require(:rule).permit(:locked)
  end

  def revert_params
    params.permit(:audit_id, :field)
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

  def set_project_permissions
    @project_permissions = current_user&.project_permissions(@project)
  end
end
