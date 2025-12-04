# frozen_string_literal: true

# Slim serializer for Rule - used in list/index views
# Only includes fields needed for table display
class RuleIndexBlueprint < Blueprinter::Base
  identifier :id

  fields :rule_id,
         :version,
         :title,
         :status,
         :rule_severity,
         :locked,
         :review_requestor_id,
         :changes_requested,
         :updated_at

  # Computed field: is this rule merged (satisfied by another)?
  field :is_merged do |rule|
    rule.satisfied_by.any?
  end

  # Computed field: count of rules this rule satisfies
  field :satisfies_count do |rule|
    rule.satisfies.size
  end

  # Slim list of rules this rule satisfies (for expanded row display)
  # Only returns id and rule_id to keep payload small
  field :satisfies_rules do |rule|
    rule.satisfies.map { |r| { id: r.id, rule_id: r.rule_id, title: r.title } }
  end

  # Slim list of rules that satisfy this rule (parent references for merged rules)
  # Only returns id and rule_id for navigation
  field :satisfied_by do |rule|
    rule.satisfied_by.map { |r| { id: r.id, rule_id: r.rule_id, title: r.title } }
  end
end
