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
      # STIG components derive from derived (non-core) SRGs only — the
      # cores are the authors' non-public raw material, never a valid
      # STIG base.
      parent_eligibility: :derived_srgs,
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

  def self.profile?(key)
    REGISTRY.key?(key.to_s)
  end

  # Per-profile parent eligibility — the ONE kind-difference in the
  # multi-parent model. Expressed as policy so a third profile adds a row
  # and (at most) a new policy symbol, never a hard-coded kind pair.
  def parent_eligible?(srg)
    case parent_eligibility
    when :core_srgs then srg.core
    when :derived_srgs then !srg.core
    else raise ArgumentError, "unknown parent_eligibility policy: #{parent_eligibility.inspect}"
    end
  end

  # Human wording for eligibility failures, per policy.
  def parent_eligibility_requirement
    case parent_eligibility
    when :core_srgs then 'a core SRG family'
    when :derived_srgs then 'a derived (non-core) SRG family'
    else raise ArgumentError, "unknown parent_eligibility policy: #{parent_eligibility.inspect}"
    end
  end
end
