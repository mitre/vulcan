# frozen_string_literal: true

# Serializes relocation backlog rows: the marker plus enough source
# identity to act on it (the component-prefixed requirement name, the
# owning component, and who requested the move).
class RequirementRelocationBlueprint < Blueprinter::Base
  identifier :id

  fields :source_rule_id, :target_technology_token, :created_at

  field :source_displayed_name do |record, _options|
    "#{record.source_rule.component.prefix}-#{record.source_rule.rule_id}"
  end

  field :component_id do |record, _options|
    record.source_rule.component_id
  end

  field :component_name do |record, _options|
    record.source_rule.component.name
  end

  field :requested_by_name do |record, _options|
    record.requested_by&.name
  end
end
