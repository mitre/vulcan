# frozen_string_literal: true

# Serializes SecurityRequirementsGuide records. XML column is NEVER included.
class SrgBlueprint < Blueprinter::Base
  identifier :id

  fields :srg_id, :name, :title, :version

  field :severity_counts do |srg, _options|
    srg.severity_counts_hash
  end

  view :index do
    # Default fields + severity_counts
  end

  view :show do
    field :release_date

    association :srg_rules, blueprint: SrgRuleBlueprint do |srg, _options|
      srg.srg_rules
    end
  end
end
