# frozen_string_literal: true

# Blueprint for satisfied_by relationships — includes fixtext and component_prefix
# so the frontend can render "Satisfied by PREFIX-RULE_ID" without extra lookups.
class SatisfiedByBlueprint < SatisfactionBlueprint
  field :fixtext

  field :component_prefix do |rule, _options|
    rule.component&.prefix
  end
end
