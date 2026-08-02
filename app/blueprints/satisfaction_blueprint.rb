# frozen_string_literal: true

# Lightweight blueprint for Rule satisfaction relationships (satisfies).
class SatisfactionBlueprint < Blueprinter::Base
  identifier :id
  field :rule_id

  # A Rule answers for its SRG identifier by reaching its source requirement.
  # Declared so every linked row is fetched in one go — without it, each
  # satisfaction link on each requirement resolves its own, one at a time.
  field :srg_id, preload: :srg_rule do |rule, _options|
    rule.srg_identifier
  end
end
