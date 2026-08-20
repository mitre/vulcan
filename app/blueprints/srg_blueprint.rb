# frozen_string_literal: true

# Serializes SecurityRequirementsGuide records. XML column is NEVER included.
class SrgBlueprint < Blueprinter::Base
  identifier :id

  # core: whether this is a core SRG (the non-public raw material
  # SRG-kind components derive from) — drives the creation-flow source
  # picker's eligibility filtering.
  fields :srg_id, :name, :title, :version, :release_date, :core

  field :severity_counts do |srg, _options|
    srg.severity_counts_hash
  end

  # Currency fields read from a batched `currency:` option when present
  # (SecurityRequirementsGuide.currency_for) — the catalog index passes it so
  # the whole page costs one query instead of ~3-5 per row. The per-record
  # fallback keeps single-record renders (which pass no option) correct.
  field :is_latest do |srg, options|
    entry = options[:currency]&.dig(srg.id)
    entry ? entry[:is_latest] : srg.latest?
  end

  field :latest_available_version do |srg, options|
    entry = options[:currency]&.dig(srg.id)
    next entry[:latest_available_version] if entry

    srg.latest? ? nil : srg.latest_release&.version
  end

  field :latest_available_id do |srg, options|
    entry = options[:currency]&.dig(srg.id)
    next entry[:latest_available_id] if entry

    srg.latest? ? nil : srg.latest_release&.id
  end

  view :index do
    # Default fields + severity_counts
  end

  # === Latest view: dropdown population ===
  # Reference identity only — no per-record severity/currency queries.
  view :latest do
    excludes :severity_counts, :is_latest, :latest_available_version, :latest_available_id, :release_date,
             :core
  end

  view :show do
    association :srg_rules, blueprint: SrgRuleBlueprint do |srg, _options|
      BaseRule.canonical_sort(srg.srg_rules)
    end
  end
end
