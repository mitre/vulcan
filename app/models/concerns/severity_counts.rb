# frozen_string_literal: true

##
# SeverityCounts - Shared concern for models with severity-categorized rules
#
# Provides severity aggregation methods for Component, STIG, and SRG models.
# Auto-generates a `with_severity_counts` scope based on model type.
# Heavy columns (xml, binary) are excluded from the SELECT to prevent
# memory blowout on index pages.
#
# Usage:
#   class Component < ApplicationRecord
#     include SeverityCounts
#     def rules_association; rules; end  # Define association to query
#   end
#
module SeverityCounts
  extend ActiveSupport::Concern

  ##
  # Override as_json to include severity_counts by default
  #
  # Models can still extend this by calling super and merging additional fields.
  # Pass include_severity_counts: false in options to skip.
  def as_json(options = {})
    return super if options[:include_severity_counts] == false

    super.merge({ severity_counts: severity_counts_hash })
  end

  # Column types that are never needed on index/list pages and can be
  # multi-MB per row. Excluding them from `with_severity_counts` prevents
  # Heroku dyno memory blowout (R14/R15) on endpoints like GET /stigs.
  # Models without these column types are unaffected (all columns loaded).
  # Uses ActiveRecord's abstract `type` (not adapter-specific `sql_type`)
  # so it works across databases (Postgres xml/bytea, MySQL blob, etc.).
  HEAVY_COLUMN_TYPES = %i[xml binary].freeze

  included do
    ##
    # Auto-generate with_severity_counts scope based on model type
    #
    # Detects model type and creates appropriate SQL subqueries.
    # Automatically excludes heavy columns (xml, binary) from the SELECT
    # to prevent memory blowout on index pages. Use `Stig.find(id)` (no
    # scope) when you need the full record including xml for export/download.
    scope :with_severity_counts, lambda {
      table = table_name
      rule_type = "#{name.gsub('SecurityRequirementsGuide', 'Srg')}Rule" # Component->ComponentRule, Stig->StigRule, SRG->SrgRule
      rule_type = 'Rule' if name == 'Component' # Component uses 'Rule', not 'ComponentRule'

      # Determine foreign key condition based on model
      fk_condition = case name
                     when 'Component'
                       "base_rules.component_id = #{table}.id AND base_rules.deleted_at IS NULL"
                     when 'Stig'
                       "base_rules.stig_id = #{table}.id"
                     when 'SecurityRequirementsGuide'
                       "base_rules.security_requirements_guide_id = #{table}.id"
                     else
                       raise ArgumentError, "SeverityCounts not supported for model: #{name}"
                     end

      # Add type filter for STI (not needed for Component since it uses component_id)
      type_condition = name == 'Component' ? '' : "AND base_rules.type = '#{rule_type}' "

      # Select only lightweight columns — exclude xml/binary blobs that can be
      # multi-MB per row. This is the DRY fix: all models using this concern
      # automatically benefit without per-controller workarounds.
      lightweight_cols = columns.reject { |c| HEAVY_COLUMN_TYPES.include?(c.type) }
                                .map { |c| "#{table}.#{c.name}" }

      select(
        *lightweight_cols,
        "(SELECT COUNT(*) FROM base_rules WHERE #{fk_condition} #{type_condition}" \
        "AND base_rules.rule_severity = 'high') AS severity_high_count",
        "(SELECT COUNT(*) FROM base_rules WHERE #{fk_condition} #{type_condition}" \
        "AND base_rules.rule_severity = 'medium') AS severity_medium_count",
        "(SELECT COUNT(*) FROM base_rules WHERE #{fk_condition} #{type_condition}" \
        "AND base_rules.rule_severity = 'low') AS severity_low_count"
      )
    }
  end

  ##
  # Get severity counts hash
  # Uses virtual columns from with_severity_counts scope if available, otherwise computes
  #
  # @return [Hash] Hash with :high, :medium, :low counts
  def severity_counts_hash
    # If loaded via with_severity_counts scope, use virtual columns (no extra query)
    if has_attribute?(:severity_high_count)
      {
        high: severity_high_count || 0,
        medium: severity_medium_count || 0,
        low: severity_low_count || 0
      }
    else
      # Fallback: compute from rules (triggers query)
      severity_counts
    end
  end

  ##
  # Calculate severity counts from rules association
  # Override `rules_association` in including model to specify which association to use
  #
  # @return [Hash] Hash with :high, :medium, :low counts
  def severity_counts
    counts = rules_association.group(:rule_severity).count
    {
      high: counts['high'] || 0,
      medium: counts['medium'] || 0,
      low: counts['low'] || 0
    }
  end

  ##
  # Override in including model to specify which association contains the rules
  # Default: :rules
  def rules_association
    send(:rules)
  end
end
