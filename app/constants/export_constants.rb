# frozen_string_literal: true

module ExportConstants
  DISA_EXPORT_HEADERS = ['IA Control', 'CCI', 'SRGID', 'STIGID', 'SRG Requirement', 'Requirement', 'SRG VulDiscussion',
                         'VulDiscussion', 'Status', 'SRG Check', 'Check', 'SRG Fix', 'Fix', 'Severity', 'Mitigation',
                         'Artifact Description', 'Status Justification', 'Vendor Comments',
                         'Satisfies'].freeze
  OPTIONAL_EXPORT_HEADERS = ['InSpec Control Body'].freeze

  EXPORT_HEADERS = [DISA_EXPORT_HEADERS, OPTIONAL_EXPORT_HEADERS].flatten.freeze

  # Column definitions for STIG/SRG CSV export
  # Each column has a key (matching csv_value_for), a header label, and a default flag
  BENCHMARK_CSV_COLUMNS = {
    rule_id: { header: 'Rule ID', default: true },
    version: { header: 'STIG ID', default: true }, # Shows as "SRG ID" for SRG context
    srg_id: { header: 'SRG ID', default: true },
    vuln_id: { header: 'Vuln ID', default: true },
    rule_severity: { header: 'Severity', default: true },
    title: { header: 'Title', default: true },
    vuln_discussion: { header: 'Description', default: true },
    check_content: { header: 'Check', default: true },
    fixtext: { header: 'Fix', default: true },
    ident: { header: 'CCI', default: true },
    nist_control_family: { header: '800-53 Controls', default: true },
    legacy_ids: { header: 'Legacy IDs', default: true },
    status: { header: 'Status', default: false },
    rule_weight: { header: 'Weight', default: false },
    mitigations: { header: 'Mitigations', default: false },
    severity_override_guidance: { header: 'Severity Override', default: false },
    false_positives: { header: 'False Positives', default: false },
    false_negatives: { header: 'False Negatives', default: false }
  }.freeze

  BENCHMARK_CSV_DEFAULT_COLUMNS = BENCHMARK_CSV_COLUMNS.select { |_, v| v[:default] }.keys.freeze

  # SRG default columns exclude STIG-specific fields (vuln_id, srg_id)
  # SRG rules use `version` for SRG ID; srg_id is not populated on SRG rules
  SRG_CSV_DEFAULT_COLUMNS = (BENCHMARK_CSV_DEFAULT_COLUMNS - %i[vuln_id srg_id]).freeze

  # SRG context overrides the header for `version` from "STIG ID" to "SRG ID"
  SRG_CSV_HEADER_OVERRIDES = { version: 'SRG ID' }.freeze
end
