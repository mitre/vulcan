# frozen_string_literal: true

# Lightweight blueprint for Rule satisfaction relationships (satisfies).
class SatisfactionBlueprint < Blueprinter::Base
  identifier :id
  field :rule_id
  field :srg_id do |rule, _options|
    rule.srg_rule&.version
  end
end
