# frozen_string_literal: true

# Blueprint for satisfied_by relationships — includes fixtext and component_prefix
# so the frontend can render "Satisfied by PREFIX-RULE_ID" without extra lookups.
class SatisfiedByBlueprint < SatisfactionBlueprint
  field :fixtext

  # Reaches the owning component for its prefix. This is the second dependency
  # under a satisfaction link, separate from the source requirement inherited
  # from the parent blueprint — fixing one without the other leaves the row
  # still fetching per link.
  field :component_prefix, preload: :component do |rule, _options|
    rule.component&.prefix
  end
end
