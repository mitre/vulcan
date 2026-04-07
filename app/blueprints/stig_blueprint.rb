# frozen_string_literal: true

# Serializes STIG records. XML column is NEVER included — it's multi-MB
# and only needed for export (which uses Stig.find directly).
class StigBlueprint < Blueprinter::Base
  identifier :id

  # === Default: fields shared by all views ===
  fields :stig_id, :name, :title, :version, :benchmark_date

  field :severity_counts do |stig, _options|
    stig.severity_counts_hash
  end

  # === Index view: listing page ===
  view :index do
    # Default fields + severity_counts are sufficient
  end

  # === Show view: detail page ===
  view :show do
    field :description

    association :stig_rules, blueprint: StigRuleBlueprint do |stig, _options|
      stig.stig_rules
    end
  end
end
