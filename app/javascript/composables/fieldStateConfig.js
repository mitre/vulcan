/**
 * Three-state field model: every form field resolves to exactly one of
 * hidden | readonly | editable, keyed by (documentType x status x tier).
 *
 * ONE source of truth for field states across both document kinds. This is
 * the successor to STATUS_FIELD_CONFIG's four-list shape: the legacy
 * `displayed` list maps to editable, `disabled` to readonly, the legacy
 * advanced lists to tier-variant entries, and omission to hidden.
 *
 * Tiers: `author` (default) and `publisher`. A field value is either a
 * state string (same state for both tiers) or `{ author, publisher }`.
 * The publisher tier is currently switched by the Advanced Fields checkbox
 * — an interim mapping until the publisher membership capability ships;
 * server-side enforcement is NOT provided by this module.
 *
 * The tier overlay is expected to stay a small, per-field concern
 * (severity, CCI/IA-control alignment). If tier-variant entries start
 * multiplying, revisit the roles model instead of adding more.
 *
 * Fields resolving to hidden are OMITTED from resolveFieldStates output —
 * absence is the hidden state, so consumers never branch on a sentinel.
 */

export const FIELD_STATES = Object.freeze({
  HIDDEN: "hidden",
  READONLY: "readonly",
  EDITABLE: "editable",
});

const TIERS = Object.freeze(["author", "publisher"]);

// Tier-variant entry: hidden to authors, editable at publisher tier.
const PUBLISHER_ONLY = Object.freeze({ author: "hidden", publisher: "editable" });

// The IA Control / CCI reference display: inherited identifiers shown
// read-only at every status, both kinds, both tiers. `cci` renders
// rule.ident and `nist_control_family` renders its own attribute; the
// editable identifier paths (`ident`, `ia_controls`) are separate fields.
const REFERENCE_DISPLAY = Object.freeze({
  nist_control_family: "readonly",
  cci: "readonly",
});

// The DISA vendor-metadata block revealed at publisher tier (STIG kinds
// that expose it).
const DISA_PUBLISHER_BLOCK = Object.freeze({
  documentable: PUBLISHER_ONLY,
  false_positives: PUBLISHER_ONLY,
  false_negatives: PUBLISHER_ONLY,
  potential_impacts: PUBLISHER_ONLY,
  third_party_tools: PUBLISHER_ONLY,
  responsibility: PUBLISHER_ONLY,
  ia_controls: PUBLISHER_ONLY,
});

// SRG working statuses share one shape: everything editable, severity and
// identifiers inherited (readonly to authors, editable to publishers),
// justification hidden until Not Applicable.
const SRG_WORKING_STATUS = Object.freeze({
  rule: {
    status: "editable",
    title: "editable",
    fixtext: "editable",
    rule_severity: Object.freeze({ author: "readonly", publisher: "editable" }),
    ident: PUBLISHER_ONLY,
    ...REFERENCE_DISPLAY,
  },
  disa: { vuln_discussion: "editable" },
  check: { content: "editable" },
});

export const FIELD_CONFIG_BY_DOCUMENT_TYPE = Object.freeze({
  stig: {
    "Applicable - Configurable": {
      rule: {
        status: "editable",
        rule_severity: "editable",
        title: "editable",
        fixtext: "editable",
        vendor_comments: "editable",
        status_justification: PUBLISHER_ONLY,
        version: PUBLISHER_ONLY,
        rule_weight: PUBLISHER_ONLY,
        artifact_description: PUBLISHER_ONLY,
        fix_id: PUBLISHER_ONLY,
        fixtext_fixref: PUBLISHER_ONLY,
        ident: PUBLISHER_ONLY,
        ident_system: PUBLISHER_ONLY,
        ...REFERENCE_DISPLAY,
      },
      disa: {
        vuln_discussion: "editable",
        mitigations_available: PUBLISHER_ONLY,
        mitigations: PUBLISHER_ONLY,
        poam_available: PUBLISHER_ONLY,
        poam: PUBLISHER_ONLY,
        mitigation_control: PUBLISHER_ONLY,
        ...DISA_PUBLISHER_BLOCK,
      },
      check: { content: "editable" },
    },
    "Not Yet Determined": {
      rule: {
        status: "editable",
        rule_severity: "readonly",
        title: "readonly",
        fixtext: "readonly",
        ...REFERENCE_DISPLAY,
      },
      disa: { vuln_discussion: "readonly" },
      check: { content: "readonly" },
    },
    "Applicable - Inherently Meets": {
      rule: {
        status: "editable",
        rule_severity: "editable",
        status_justification: "editable",
        artifact_description: "editable",
        vendor_comments: "editable",
        ...REFERENCE_DISPLAY,
      },
      disa: {},
      check: {},
    },
    "Applicable - Does Not Meet": {
      rule: {
        status: "editable",
        rule_severity: "editable",
        status_justification: "editable",
        vendor_comments: "editable",
        ...REFERENCE_DISPLAY,
      },
      disa: {
        mitigations_available: "editable",
        mitigations: "editable",
        mitigation_control: "editable",
        poam_available: "editable",
        poam: "editable",
        ...DISA_PUBLISHER_BLOCK,
      },
      check: {},
    },
    "Not Applicable": {
      rule: {
        status: "editable",
        rule_severity: "readonly",
        status_justification: "editable",
        vendor_comments: "editable",
        ...REFERENCE_DISPLAY,
      },
      disa: {},
      check: {},
    },
  },

  srg: {
    "Not Yet Determined": SRG_WORKING_STATUS,
    Applicable: SRG_WORKING_STATUS,
    "Not Applicable": {
      rule: {
        status: "editable",
        // Required at Not Applicable — requiredness is enforced server-side.
        status_justification: "editable",
      },
      disa: {},
      check: {},
    },
  },
});

const GROUPS = Object.freeze(["rule", "disa", "check"]);

/**
 * Resolve every field's state for (documentType, status, tier).
 *
 * @returns {{rule: Object, disa: Object, check: Object}} maps of
 *   field -> "readonly" | "editable"; hidden fields are omitted.
 * @throws on unknown documentType, status, or tier — a silent empty
 *   config would render a broken form.
 */
export function resolveFieldStates({ documentType, status, tier = "author" }) {
  const kindConfig = FIELD_CONFIG_BY_DOCUMENT_TYPE[documentType];
  if (!kindConfig) {
    throw new Error(`fieldStateConfig: unknown document type "${documentType}"`);
  }
  if (!TIERS.includes(tier)) {
    throw new Error(`fieldStateConfig: unknown tier "${tier}"`);
  }
  const statusConfig = kindConfig[status];
  if (!statusConfig) {
    throw new Error(
      `fieldStateConfig: unknown status "${status}" for document type "${documentType}"`,
    );
  }

  const resolved = {};
  for (const group of GROUPS) {
    resolved[group] = {};
    for (const [field, entry] of Object.entries(statusConfig[group])) {
      const state = typeof entry === "string" ? entry : entry[tier];
      if (state !== FIELD_STATES.HIDDEN) {
        resolved[group][field] = state;
      }
    }
  }
  return resolved;
}

// The status whose form is the kind's fullest — the baseline the
// fields-hidden hint compares against. Status knowledge lives in this
// module by design; components never hardcode a status string.
const FULL_FORM_STATUS_BY_DOCUMENT_TYPE = Object.freeze({
  stig: "Applicable - Configurable",
  srg: "Applicable",
});

/**
 * Whether the given status hides fields that the kind's fullest
 * authoring form shows (at the same tier). Drives the editor's
 * "some fields are hidden due to the control's status" hint.
 */
export function hasHiddenFields({ documentType, status, tier = "author" }) {
  const current = resolveFieldStates({ documentType, status, tier });
  const full = resolveFieldStates({
    documentType,
    status: FULL_FORM_STATUS_BY_DOCUMENT_TYPE[documentType],
    tier,
  });
  return GROUPS.some((group) =>
    Object.keys(full[group]).some((field) => !(field in current[group])),
  );
}

/**
 * Adapter for the existing consumer contract: RuleFormGroup and the form
 * components resolve visibility via `fields.displayed.includes(name)` and
 * read-only rendering via `fields.disabled.includes(name)`.
 *
 * displayed = every non-hidden field; disabled = the readonly subset.
 */
export function buildFieldSets({ documentType, status, tier = "author" }) {
  const states = resolveFieldStates({ documentType, status, tier });
  const sets = {};
  for (const group of GROUPS) {
    const displayed = Object.keys(states[group]);
    const disabled = displayed.filter((field) => states[group][field] === FIELD_STATES.READONLY);
    sets[group] = { displayed, disabled };
  }
  return sets;
}
