# frozen_string_literal: true

# Strips stale satisfaction text ("Satisfies: ..." / "Satisfied By: ...") from
# vendor_comments and vuln_discussion columns. Satisfaction relationships are now
# stored as structured rule_satisfactions records — the text is redundant.
#
# SCOPED TO COMPONENT RULES ONLY (type = 'Rule'). STIG/SRG reference data
# (SrgRule, StigRule) is imported from DISA and must never be modified.
class StripSatisfactionTextFromVendorComments < ActiveRecord::Migration[8.0]
  def up
    # Pattern matches "Satisfies: ..." or "Satisfied By: ..." to end of string (case-insensitive)
    # Uses POSIX regex via regexp_replace for PostgreSQL
    strip_pattern = '\s*\m(Satisfi(ed\s+By|es))\s*:.*$'

    # Strip from vendor_comments on component rules only (NOT SRG/STIG reference data)
    execute <<-SQL.squish
      UPDATE base_rules
      SET vendor_comments = NULLIF(TRIM(regexp_replace(vendor_comments, '#{strip_pattern}', '', 'i')), '')
      WHERE type = 'Rule'
        AND vendor_comments ~* '(satisfies|satisfied\s+by)\s*:'
    SQL

    # Strip from vuln_discussion on disa_rule_descriptions belonging to component rules only
    execute <<-SQL.squish
      UPDATE disa_rule_descriptions
      SET vuln_discussion = NULLIF(TRIM(regexp_replace(vuln_discussion, '#{strip_pattern}', '', 'i')), '')
      WHERE base_rule_id IN (SELECT id FROM base_rules WHERE type = 'Rule')
        AND vuln_discussion ~* '(satisfies|satisfied\s+by)\s*:'
    SQL
  end

  def down
    # Data migration — satisfaction text cannot be reconstructed from structured records
    # because the original formatting varies. No-op on rollback.
    Rails.logger.warn('StripSatisfactionTextFromVendorComments: rollback is a no-op — text cannot be reconstructed')
  end
end
