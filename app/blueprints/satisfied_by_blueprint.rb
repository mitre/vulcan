# frozen_string_literal: true

# Blueprint for satisfied_by relationships — includes fixtext in addition to base fields.
class SatisfiedByBlueprint < SatisfactionBlueprint
  field :fixtext
end
