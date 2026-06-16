# frozen_string_literal: true

# Serializes SecurityRequirementsGuide records. XML column is NEVER included.
class SrgBlueprint < Blueprinter::Base
  identifier :id

  fields :srg_id, :name, :title, :version, :release_date

  field :severity_counts do |srg, _options|
    srg.severity_counts_hash
  end

  field :is_latest do |srg, _options|
    srg.latest?
  end

  field :latest_available_version do |srg, _options|
    srg.latest? ? nil : srg.latest_for_family&.version
  end

  field :latest_available_id do |srg, _options|
    srg.latest? ? nil : srg.latest_for_family&.id
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
