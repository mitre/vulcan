# frozen_string_literal: true

# Serializes relocation backlog rows: the proposal plus enough source
# identity to act on it (the component-prefixed requirement name, the
# owning component, and who requested the move), and the adjudication
# outcome for retained declines — the source author reads the rationale
# here.
class RequirementRelocationBlueprint < Blueprinter::Base
  identifier :id

  fields :source_rule_id, :target_technology_token, :created_at,
         :declined_at, :adjudication_rationale

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

  field :declined_by_name do |record, _options|
    record.declined_by&.name
  end
end
