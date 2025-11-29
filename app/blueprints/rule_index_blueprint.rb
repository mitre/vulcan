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
         :review_requestor_id

  # Computed field: is this rule merged (satisfied by another)?
  field :is_merged do |rule|
    rule.satisfied_by.any?
  end
end
