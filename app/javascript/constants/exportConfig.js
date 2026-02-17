/**
 * Export mode + format configuration.
 * Mirrors Export::Registry on the backend — keep in sync.
 */

// Export modes — purpose-first selection
export const EXPORT_MODES = {
  working_copy: {
    label: "Working Copy",
    description: "Internal review and editing",
  },
  vendor_submission: {
    label: "DISA Vendor Submission",
    description: "Submit to DISA for review",
  },
  published_stig: {
    label: "Published STIG",
    description: "AC rules ready for publication",
  },
  backup: {
    label: "Backup",
    description: "Full-fidelity archive of all rules",
  },
};

// Mode → allowed formats (mirrors Export::Registry::COMBINATIONS)
export const MODE_FORMAT_MATRIX = {
  working_copy: ["csv", "excel"],
  vendor_submission: ["excel"],
  published_stig: ["xccdf", "inspec"],
  backup: ["xccdf"],
};

// Format display metadata
export const FORMAT_LABELS = {
  csv: { label: "CSV", description: "Comma-separated values" },
  excel: { label: "Excel", description: "Standard spreadsheet" },
  xccdf: { label: "XCCDF", description: "SCAP XML format" },
  inspec: { label: "InSpec", description: "Chef InSpec profile" },
};

// Mode-specific overrides for format descriptions
export const MODE_FORMAT_OVERRIDES = {
  vendor_submission: {
    excel: { description: "DISA 17-column strict template" },
  },
  backup: {
    xccdf: { description: "All rules included (no filtering)" },
  },
};

// Canonical format order for mode-aware display
export const ALL_FORMATS = ["csv", "excel", "xccdf", "inspec"];
