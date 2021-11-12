# frozen_string_literal: true

##
# Controller for project rules.
#
class RulesController < ApplicationController
  before_action :set_rule, only: %i[show update destroy revert]
  before_action :set_component, only: %i[index show create update revert]
  before_action :set_project, only: %i[index show create update revert]
  before_action :set_project_permissions, only: %i[index]
  before_action :authorize_author_component, only: %i[index show create update revert]
  before_action :authorize_admin_component, only: %i[destroy]

  def index
    @rules = @component.rules.eager_load(:reviews, :disa_rule_descriptions, :rule_descriptions, :checks, :satisfies,
                                         :satisfied_by, srg_rule: %i[disa_rule_descriptions rule_descriptions checks])
  end

  def show
    render json: @rule.to_json(methods: %i[histories satisfies satisfied_by])
  end

  def create
    rule = create_or_duplicate
    if rule.save
      render json: { toast: 'Successfully created control.',
                     data: rule.to_json(methods: %i[histories satisfies satisfied_by]) }
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
      render json: { toast: 'Successfully updated control.' }
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
    if @rule.destroy
      render json: { toast: 'Successfully deleted control.' }
    else
      render json: {
        toast: {
          title: 'Could not delete control.',
          message: @rule.errors.full_messages,
          variant: 'danger'
        }
      }, status: :unprocessable_entity
    end
  end

  def revert
    Rule.revert(@rule, params[:audit_id], params[:fields], params[:audit_comment])
    render json: { toast: 'Successfully reverted history for control.' }
  rescue RuleRevertError => e
    render json: {
      toast: {
        title: 'Could not revert history.',
        message: e.message,
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end

  private

  def create_or_duplicate
    if authorize_author_project.nil? && rule_create_params[:duplicate]
      rule = Rule.find(rule_create_params[:id]).amoeba_dup
      rule.rule_id = nil
      rule
    elsif authorize_admin_project.nil?
      Rule.new(rule_create_params.except(:duplicate).merge({
                                                             component: @component,
                                                             status: 'Not Yet Determined',
                                                             rule_severity: 'unknown'
                                                           }))
    end
  end

  def rule_create_params
    params.require(:rule).permit(:duplicate, :id)
  end

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
                 Project.includes({ rules: %i[reviews checks disa_rule_descriptions rule_descriptions] })
                        .find(@component.project_id || params[:project_id] || params.dig(:rule, :project_id))
               end
  end
end
