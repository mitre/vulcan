# frozen_string_literal: true

module Export
  module Modes
    # WorkingCopy mode: exports all rules with all columns including InSpec control body.
    # No filtering, no transforms — identity pass-through.
    # This is the "just give me everything" export for internal team use.
    class WorkingCopy < BaseMode
      def columns
        Export::ExportableRule::ALL_KEYS
      end

      def headers
        ExportConstants::EXPORT_HEADERS
      end

      # No status filtering — all rules included.
      # Optional: exclude_satisfied_by removes rules with satisfied_by relationships.
      def rule_scope(rules)
        exclude_satisfied_by(rules)
      end

      # Identity transform — values pass through unchanged.
      def transform_value(_column_key, value, _exportable_rule)
        value
      end

      def eager_load_associations
        [
          :reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
          :additional_answers, :satisfies, :satisfied_by,
          { srg_rule: %i[disa_rule_descriptions rule_descriptions checks] }
        ]
      end
    end
  end
end
