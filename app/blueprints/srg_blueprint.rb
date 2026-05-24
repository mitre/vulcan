# frozen_string_literal: true

# Serializes SecurityRequirementsGuide records. XML column is NEVER included.
class SrgBlueprint < Blueprinter::Base
  identifier :id

  fields :srg_id, :name, :title, :version, :release_date

  field :severity_counts do |srg, _options|
    srg.severity_counts_hash
  end

  view :index do
    # Default fields + severity_counts
  end

  view :show do
    association :srg_rules, blueprint: SrgRuleBlueprint do |srg, _options|
      srg.srg_rules
    end
  end
end
