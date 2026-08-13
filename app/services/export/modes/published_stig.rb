# frozen_string_literal: true

module Export
  module Modes
    # PublishedStig mode: exports only AC rules, excluding satisfied_by.
    # Matches the public STIG format published by DISA on Cyber Exchange.
    # Used with XCCDF and InSpec formatters (component-based, not row-based).
    class PublishedStig < BaseMode
      # Component-based formatters (XCCDF, InSpec) handle their own structure.
      # These return empty arrays since columns/headers are not used.
      def columns
        []
      end

      def headers
        []
      end

      # AC only, exclude rules that are satisfied_by other rules.
      def rule_scope(rules)
        satisfied_by_ids = RuleSatisfaction.where(rule_id: rules.select(:id)).select(:rule_id)
        rules.where(status: 'Applicable - Configurable')
             .where.not(id: satisfied_by_ids)
      end

      def transform_value(_column_key, value, _exportable_rule)
        value
      end

      # Publication is the one purpose with meaning for both document kinds:
      # an srg component publishes its authored requirements through the srg
      # publication mode (valid for XCCDF only — the Registry gates it, so
      # InSpec exports still exclude srg components).
      def srg_counterpart
        :published_srg
      end

      def eager_load_associations
        [
          :disa_rule_descriptions, :rule_descriptions, :checks,
          :satisfies, :satisfied_by,
          { srg_rule: %i[disa_rule_descriptions rule_descriptions checks] }
        ]
      end
    end
  end
end
