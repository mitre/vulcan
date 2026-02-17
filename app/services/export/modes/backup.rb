# frozen_string_literal: true

module Export
  module Modes
    # Backup mode: exports ALL rules regardless of status with full metadata.
    # Used for full-fidelity component backup/restore via XCCDF.
    # No filtering, no transforms — preserves everything.
    class Backup < BaseMode
      # Component-based formatters handle their own structure.
      def columns
        []
      end

      def headers
        []
      end

      # No filtering — all rules included for complete backup.
      def rule_scope(rules)
        rules
      end

      def transform_value(_column_key, value, _exportable_rule)
        value
      end

      def eager_load_associations
        [
          :disa_rule_descriptions, :rule_descriptions, :checks,
          :references, :satisfies, :satisfied_by,
          { reviews: :user },
          { additional_answers: :additional_question },
          { srg_rule: %i[disa_rule_descriptions rule_descriptions checks] }
        ]
      end
    end
  end
end
