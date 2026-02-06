/**
 * CSV column definitions for STIG/SRG export.
 * Used by ExportModal to render the column picker UI.
 * Keys must match the backend's ExportConstants::BENCHMARK_CSV_COLUMNS.
 */

export const STIG_CSV_COLUMNS = [
  { key: "rule_id", header: "Rule ID", example: "SV-203591r557031_rule", default: true },
  { key: "version", header: "STIG ID", example: "RHEL-09-000001", default: true },
  { key: "srg_id", header: "SRG ID", example: "SRG-OS-000001-GPOS-00001", default: true },
  { key: "vuln_id", header: "Vuln ID", example: "V-203591", default: true },
  { key: "rule_severity", header: "Severity", example: "medium", default: true },
  { key: "title", header: "Title", example: "The operating system must\u2026", default: true },
  {
    key: "vuln_discussion",
    header: "Description",
    example: "Without verification of the\u2026",
    default: true,
  },
  {
    key: "check_content",
    header: "Check",
    example: "Verify the operating system\u2026",
    default: true,
  },
  { key: "fixtext", header: "Fix", example: "Configure the operating sys\u2026", default: true },
  { key: "ident", header: "CCI", example: "CCI-000366", default: true },
  { key: "nist_control_family", header: "800-53 Controls", example: "CM-6 b", default: true },
  { key: "legacy_ids", header: "Legacy IDs", example: "V-56571, SV-70831", default: true },
  { key: "status", header: "Status", example: "Applicable - Configurable", default: false },
  { key: "rule_weight", header: "Weight", example: "10.0", default: false },
  { key: "mitigations", header: "Mitigations", example: "(empty for most rules)", default: false },
  {
    key: "severity_override_guidance",
    header: "Severity Override",
    example: "(empty for most rules)",
    default: false,
  },
  {
    key: "false_positives",
    header: "False Positives",
    example: "(empty for most rules)",
    default: false,
  },
  {
    key: "false_negatives",
    header: "False Negatives",
    example: "(empty for most rules)",
    default: false,
  },
];

export const SRG_CSV_COLUMNS = [
  { key: "rule_id", header: "Rule ID", example: "SV-200001r800001_rule", default: true },
  { key: "version", header: "SRG ID", example: "SRG-APP-000001-GPOS-00001", default: true },
  { key: "rule_severity", header: "Severity", example: "high", default: true },
  { key: "title", header: "Title", example: "The application must enforce\u2026", default: true },
  {
    key: "vuln_discussion",
    header: "Description",
    example: "Unauthorized access must be\u2026",
    default: true,
  },
  {
    key: "check_content",
    header: "Check",
    example: "Verify the application enforces\u2026",
    default: true,
  },
  { key: "fixtext", header: "Fix", example: "Configure the application to\u2026", default: true },
  { key: "ident", header: "CCI", example: "CCI-000213", default: true },
  { key: "nist_control_family", header: "800-53 Controls", example: "AC-3", default: true },
  { key: "legacy_ids", header: "Legacy IDs", example: "V-40000", default: true },
  { key: "status", header: "Status", example: "Applicable - Configurable", default: false },
  { key: "rule_weight", header: "Weight", example: "10.0", default: false },
  { key: "mitigations", header: "Mitigations", example: "(empty for most rules)", default: false },
  {
    key: "severity_override_guidance",
    header: "Severity Override",
    example: "(empty for most rules)",
    default: false,
  },
  {
    key: "false_positives",
    header: "False Positives",
    example: "(empty for most rules)",
    default: false,
  },
  {
    key: "false_negatives",
    header: "False Negatives",
    example: "(empty for most rules)",
    default: false,
  },
];
