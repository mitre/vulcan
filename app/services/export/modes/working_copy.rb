# frozen_string_literal: true

module Export
  module Modes
    # WorkingCopy mode: exports all rules with all columns including InSpec control body.
    # No filtering, no transforms — identity pass-through.
    # This is the "just give me everything" export for internal team use.
    class WorkingCopy < BaseMode
      def columns
        # ALL_KEYS includes :source — provides Direct/Inherited indicator for filtering
        Export::ExportableRule::ALL_KEYS
      end

      # SRGs and STIGs are both XCCDF documents authored the same way, so the
      # working copy is available for both. SRG components load their authored
      # requirements through srg_eager_load_associations (BaseMode default) and
      # ExportableRule blanks the source-reference / satisfies / InSpec columns,
      # which have no meaning for an authored SrgRule.
      def supports_srg_kind?
        true
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

      def include_source_column?
        true
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
