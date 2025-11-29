# frozen_string_literal: true

# Full serializer for Rule - used in detail/show views
# Includes all fields and associations needed for editing
class RuleBlueprint < Blueprinter::Base
  identifier :id

  # Core fields
  fields :rule_id,
         :version,
         :title,
         :status,
         :status_justification,
         :artifact_description,
         :vendor_comments,
         :fixtext,
         :fixtext_fixref,
         :fix_id,
         :ident,
         :ident_system,
         :legacy_ids,
         :rule_severity,
         :rule_weight,
         :locked,
         :changes_requested,
         :review_requestor_id,
         :component_id,
         :srg_rule_id,
         :inspec_control_body,
         :inspec_control_file,
         :created_at,
         :updated_at

  # Computed fields
  field :is_merged do |rule|
    rule.satisfied_by.any?
  end

  # Associations
  association :reviews, blueprint: ReviewBlueprint
  association :disa_rule_descriptions, blueprint: DisaRuleDescriptionBlueprint
  association :checks, blueprint: CheckBlueprint
  association :satisfies, blueprint: RuleSatisfactionBlueprint
  association :satisfied_by, blueprint: RuleSatisfactionBlueprint

  # SRG info
  field :srg_info do |rule|
    { version: rule.srg_rule&.security_requirements_guide&.version }
  end

  # SRG rule attributes
  field :srg_rule_attributes do |rule|
    SrgRuleBlueprint.render_as_hash(rule.srg_rule) if rule.srg_rule
  end

  # History/changelog data for revert functionality
  # Returns formatted audits via VulcanAudit#format
  field :histories do |rule|
    rule.histories(50)
  end
end
