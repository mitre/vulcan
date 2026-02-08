/**
 * Declarative field configuration for rule forms.
 *
 * ONE source of truth per status — all field groups (rule, disa, check)
 * defined together. The composable (useRuleFormFields) reads from this
 * config and merges with dynamic logic (severity override, satisfied_by).
 *
 * Each field group has:
 *   displayed: fields shown in basic mode
 *   disabled:  fields disabled in basic mode
 *   advancedDisplayed: additional fields shown only in advanced mode
 *   advancedDisabled:  additional fields disabled only in advanced mode
 */

export const STATUS_FIELD_CONFIG = {
  "Applicable - Configurable": {
    rule: {
      displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
      disabled: [],
      advancedDisplayed: [
        "status_justification",
        "version",
        "rule_weight",
        "artifact_description",
        "fix_id",
        "fixtext_fixref",
        "ident",
        "ident_system",
      ],
      advancedDisabled: [],
    },
    disa: {
      displayed: ["vuln_discussion"],
      disabled: [],
      advancedDisplayed: [
        "documentable",
        "false_positives",
        "false_negatives",
        "mitigations_available",
        "mitigations",
        "poam_available",
        "poam",
        "potential_impacts",
        "third_party_tools",
        "mitigation_control",
        "responsibility",
        "ia_controls",
      ],
      advancedDisabled: [],
    },
    check: {
      displayed: ["content"],
      disabled: [],
    },
  },

  "Not Yet Determined": {
    rule: {
      displayed: ["status", "rule_severity", "title", "fixtext"],
      disabled: ["title", "rule_severity", "fixtext"],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    disa: {
      displayed: ["vuln_discussion"],
      disabled: ["vuln_discussion"],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    check: {
      displayed: ["content"],
      disabled: ["content"],
    },
  },

  "Applicable - Inherently Meets": {
    rule: {
      displayed: [
        "status",
        "rule_severity",
        "status_justification",
        "artifact_description",
        "vendor_comments",
      ],
      disabled: [],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    disa: {
      displayed: [],
      disabled: [],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    check: {
      displayed: [],
      disabled: [],
    },
  },

  "Applicable - Does Not Meet": {
    rule: {
      displayed: ["status", "rule_severity", "status_justification", "vendor_comments"],
      disabled: [],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    disa: {
      displayed: [
        "mitigations_available",
        "mitigations",
        "mitigation_control",
        "poam_available",
        "poam",
      ],
      disabled: [],
      advancedDisplayed: [
        "documentable",
        "false_positives",
        "false_negatives",
        "potential_impacts",
        "third_party_tools",
        "responsibility",
        "ia_controls",
      ],
      advancedDisabled: [],
    },
    check: {
      displayed: [],
      disabled: [],
    },
  },

  "Not Applicable": {
    rule: {
      displayed: [
        "status",
        "rule_severity",
        "status_justification",
        "artifact_description",
        "vendor_comments",
      ],
      disabled: ["rule_severity"],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    disa: {
      displayed: [],
      disabled: [],
      advancedDisplayed: [],
      advancedDisabled: [],
    },
    check: {
      displayed: [],
      disabled: [],
    },
  },
};

// Statuses where severity is editable (can be changed from SRG default)
export const SEVERITY_EDITABLE_STATUSES = [
  "Applicable - Configurable",
  "Applicable - Inherently Meets",
  "Applicable - Does Not Meet",
];

// Statuses where severity_override_guidance can appear (when severity changed)
export const SEVERITY_OVERRIDE_STATUSES = SEVERITY_EDITABLE_STATUSES;

// Lockable section groups — maps section name to field names
export const LOCKABLE_SECTIONS = {
  Title: ["title"],
  Severity: ["rule_severity", "severity_override_guidance"],
  Status: ["status", "status_justification"],
  Fix: ["fixtext", "fix_id", "fixtext_fixref"],
  Check: ["content"],
  "Vulnerability Discussion": ["vuln_discussion"],
  "DISA Metadata": [
    "documentable",
    "false_positives",
    "false_negatives",
    "mitigations_available",
    "mitigations",
    "poam_available",
    "poam",
    "potential_impacts",
    "third_party_tools",
    "mitigation_control",
    "responsibility",
    "ia_controls",
  ],
  "Vendor Comments": ["vendor_comments"],
  "Artifact Description": ["artifact_description"],
};
