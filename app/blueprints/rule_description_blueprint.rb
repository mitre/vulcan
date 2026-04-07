# frozen_string_literal: true

# Serializes RuleDescription for rule detail views.
class RuleDescriptionBlueprint < Blueprinter::Base
  identifier :id

  field :description

  field :_destroy do |_rd, _options|
    false
  end
end
