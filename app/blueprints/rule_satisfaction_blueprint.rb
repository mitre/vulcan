# frozen_string_literal: true

class RuleSatisfactionBlueprint < Blueprinter::Base
  identifier :id

  fields :rule_id,
         :title,
         :fixtext
end
