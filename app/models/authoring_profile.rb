# frozen_string_literal: true

# The authoring-profile registry.
#
# ONE frozen Ruby table keyed by Component#document_type carrying the
# per-profile CONFIGURATION variance: status vocabulary, field-config key,
# parent-eligibility policy, editor panel set. Behavioral variance rides
# the STI classes (Rule vs SrgRule) — this registry is routing metadata,
# never a policy dispatcher, and never a DB table. Adding a third profile
# means adding a row here, not a migration.
class AuthoringProfile
  attr_reader :key, :statuses, :field_config_key, :parent_eligibility, :panels

  def initialize(key:, statuses:, field_config_key:, parent_eligibility:, panels:)
    @key = key
    @statuses = statuses.freeze
    @field_config_key = field_config_key
    @parent_eligibility = parent_eligibility
    @panels = panels.freeze
    freeze
  end

  # SRG vocabulary is exactly three values: bare 'Applicable' never joins
  # a shared flat status list, and relocation is a record, not a 'Moved'
  # status.
  SRG_STATUSES = [
    'Not Yet Determined',
    'Applicable',
    'Not Applicable'
  ].freeze

  REGISTRY = {
    'stig' => new(
      key: 'stig',
      statuses: RuleConstants::STATUSES,
      field_config_key: 'stig',
      # STIG components may derive from any catalog SRG (today's behavior).
      parent_eligibility: :any_srg,
      # Editor surfaces that exist only for Rule-backed requirements.
      panels: %i[satisfies inspec stig_answers]
    ),
    'srg' => new(
      key: 'srg',
      statuses: SRG_STATUSES,
      field_config_key: 'srg',
      # SRG components derive from the non-public core SRGs only.
      parent_eligibility: :core_srgs,
      # No Rule-only panels — satisfies et al. are structurally absent.
      panels: []
    )
  }.freeze

  private_class_method :new

  def self.for(key)
    REGISTRY.fetch(key.to_s)
  end

  def self.keys
    REGISTRY.keys
  end
end
