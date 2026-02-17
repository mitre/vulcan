# frozen_string_literal: true

module Export
  module Modes
    # VendorSubmission mode: strict DISA-compliant export per Vendor STIG Process Guide V4R1.
    #
    # - Exactly 17 columns (Table 8-1)
    # - STIGID blank (DISA fills during finalization)
    # - Check/Fix blank for non-AC statuses
    # - VulnDiscussion and Severity blank for NA
    # - Mitigation only for ADNM
    # - Artifact Description only for AIM
    # - Status Justification only for AIM, ADNM, NA
    # - NYD rules excluded (not a DISA-recognized status)
    #
    # See docs/disa-process/field-requirements.md for the full matrix.
    class VendorSubmission < BaseMode
      # The 17 DISA columns — no Vendor Comments, no Satisfies, no InSpec.
      VENDOR_SUBMISSION_KEYS = Export::ExportableRule::CSV_KEYS[0..16].freeze

      # The 17-column DISA headers (Table 8-1).
      VENDOR_SUBMISSION_HEADERS = ExportConstants::DISA_EXPORT_HEADERS[0..16].freeze

      # Fields that are blanked per-status. Keyed by status, value is set of column keys to blank.
      # Derived directly from docs/disa-process/field-requirements.md requirements matrix.
      BLANK_FIELDS = {
        'Applicable - Configurable' => %i[stig_id mitigation artifact_description status_justification].to_set,
        'Applicable - Inherently Meets' => %i[stig_id check_content fixtext mitigation].to_set,
        'Applicable - Does Not Meet' => %i[stig_id check_content fixtext artifact_description].to_set,
        'Not Applicable' => %i[stig_id check_content fixtext vuln_discussion severity mitigation artifact_description].to_set
      }.freeze

      def columns
        VENDOR_SUBMISSION_KEYS
      end

      def headers
        VENDOR_SUBMISSION_HEADERS
      end

      # Exclude NYD rules — not a DISA-recognized status.
      def rule_scope(rules)
        rules.where.not(status: 'Not Yet Determined')
      end

      # Apply DISA field-blanking rules per status.
      def transform_value(column_key, value, exportable_rule)
        blank_set = BLANK_FIELDS[exportable_rule.status]
        return value unless blank_set&.include?(column_key)

        nil
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
