/**
 * Composable that owns ALL field visibility/disabled logic for rule forms.
 *
 * Replaces the duplicated computed properties in BasicRuleForm and AdvancedRuleForm
 * with a single, declarative source of truth driven by ruleFieldConfig.js.
 *
 * @param {Ref<Object>} rule - reactive rule object
 * @param {Ref<boolean>} advancedMode - whether advanced fields are shown
 * @param {Object} options - { readOnly: Ref<boolean> }
 * @returns composable API (see JSDoc on return)
 */
import { computed } from "vue";
import { LOCKABLE_SECTIONS } from "./ruleFieldConfig";
import { buildFieldSets, resolveFieldStates } from "./fieldStateConfig";

const EMPTY_SETS = Object.freeze({
  rule: { displayed: [], disabled: [] },
  disa: { displayed: [], disabled: [] },
  check: { displayed: [], disabled: [] },
});

export function useRuleFormFields(rule, advancedMode, options = {}) {
  const readOnly = options.readOnly || { value: false };
  // STIG is the documented default: it is the only kind existing pages
  // serve until the SRG editor threads document_type through.
  const documentType = options.documentType || { value: "stig" };

  // Interim tier mapping: the Advanced Fields checkbox IS the publisher
  // tier switch until the publisher membership capability ships.
  const tier = computed(() => (advancedMode.value ? "publisher" : "author"));

  // One resolution per (kind, status, tier); a rule still loading (no
  // status yet) renders empty sets rather than throwing — absence of a
  // status is a loading state, not a vocabulary violation.
  const fieldSets = computed(() => {
    const status = rule.value.status;
    if (!status) return EMPTY_SETS;
    return buildFieldSets({
      documentType: documentType.value,
      status,
      tier: tier.value,
    });
  });

  // ─── Effective status ───
  // Status is set by the backend: ADNM when satisfied-by (per DISA V4R3
  // §4.1.9), NYD on removal. No frontend override needed — the DB value
  // drives fieldStateConfig field visibility.
  const effectiveStatus = computed(() => {
    return rule.value.status;
  });

  // ─── Form-level disabled ───────────────────────────────────
  const isFormDisabled = computed(() => {
    const r = rule.value;
    return !!(readOnly.value || r.locked || r.review_requestor_id);
  });

  const forceEnableAdditionalQuestions = computed(() => {
    const r = rule.value;
    return !readOnly.value && !r.locked && !r.review_requestor_id;
  });

  // ─── Severity override detection ──────────────────────────
  const severityChanged = computed(() => {
    const r = rule.value;
    const srg = r.srg_rule_attributes;
    if (srg?.rule_severity == null) return false;
    return r.rule_severity !== srg.rule_severity;
  });

  // Severity is editable exactly when the resolver says so for the
  // current (kind, status, tier) — replaces the STIG-only status list.
  const severityEditable = computed(() => {
    const status = rule.value.status;
    if (!status) return false;
    const states = resolveFieldStates({
      documentType: documentType.value,
      status,
      tier: tier.value,
    });
    return states.rule.rule_severity === "editable";
  });

  const showSeverityOverride = computed(() => {
    return severityChanged.value && severityEditable.value;
  });

  // ─── Rule form fields ─────────────────────────────────────
  const ruleFormFields = computed(() => {
    const result = {
      displayed: [...fieldSets.value.rule.displayed],
      disabled: [...fieldSets.value.rule.disabled],
    };

    // Dynamic injection of severity_override_guidance (between severity and title)
    if (showSeverityOverride.value && !result.displayed.includes("severity_override_guidance")) {
      result.displayed.push("severity_override_guidance");
    }

    // satisfied_by disables specific fields, NOT entire form
    const r = rule.value;
    if (r.satisfied_by && r.satisfied_by.length > 0) {
      if (!result.disabled.includes("title")) result.disabled.push("title");
      if (!result.disabled.includes("fixtext")) result.disabled.push("fixtext");
    }

    // Inject section-locked fields into disabled array
    injectLockedFields(result);

    return result;
  });

  // ─── DISA description fields ──────────────────────────────
  const disaDescriptionFields = computed(() => {
    const result = {
      displayed: [...fieldSets.value.disa.displayed],
      disabled: [...fieldSets.value.disa.disabled],
    };
    injectLockedFields(result);
    return result;
  });

  // ─── Check form fields ────────────────────────────────────
  const checkFormFields = computed(() => {
    const result = {
      displayed: [...fieldSets.value.check.displayed],
      disabled: [...fieldSets.value.check.disabled],
    };
    injectLockedFields(result);
    return result;
  });

  // ─── Section visibility ───────────────────────────────────
  const showDisaSection = computed(() => disaDescriptionFields.value.displayed.length > 0);
  const showChecksSection = computed(() => checkFormFields.value.displayed.length > 0);

  // Collapsible sections only when the publisher tier reveals fields the
  // author tier doesn't — statuses that are tier-invariant keep fields
  // inline (matches the legacy "has advanced additions" behavior).
  const showCollapsibleSections = computed(() => {
    const status = rule.value.status;
    if (!status) return false;
    const author = buildFieldSets({ documentType: documentType.value, status, tier: "author" });
    const publisher = buildFieldSets({
      documentType: documentType.value,
      status,
      tier: "publisher",
    });
    return (
      publisher.rule.displayed.length > author.rule.displayed.length ||
      publisher.disa.displayed.length > author.disa.displayed.length
    );
  });

  // ─── Per-section locking ─────────────────────────────────
  function isFieldLocked(fieldName) {
    const r = rule.value;
    if (!r.locked_fields || r.locked) return false;
    for (const [section, fields] of Object.entries(LOCKABLE_SECTIONS)) {
      if (fields.includes(fieldName) && r.locked_fields[section]) {
        return true;
      }
    }
    return false;
  }

  function isFieldEditable(fieldName) {
    if (isFormDisabled.value) return false;
    return !isFieldLocked(fieldName);
  }

  // ─── Field state CSS class ──────────────────────────────
  // Returns the CSS class for visual state indication on form groups.
  // Priority: section-locked > under-review > whole-locked > none
  function fieldStateClass(fieldName) {
    if (isFieldLocked(fieldName)) return "field-state--section-locked";
    // C3: whole-locked rules use form-level disable + "Rule Locked" banner
    // — no per-field visual indicator needed
    return "";
  }

  // Which field state is active for the entire rule (for legend display)
  const activeFieldStates = computed(() => {
    const r = rule.value;
    const states = [];
    if (r.locked_fields && Object.keys(r.locked_fields).length > 0 && !r.locked) {
      states.push("section-locked");
    }
    return states;
  });

  // Inject section-locked fields into disabled arrays
  function injectLockedFields(result) {
    const r = rule.value;
    if (!r.locked_fields || r.locked) return;
    for (const fieldName of result.displayed) {
      if (isFieldLocked(fieldName) && !result.disabled.includes(fieldName)) {
        result.disabled.push(fieldName);
      }
    }
  }

  return {
    // Field configs
    ruleFormFields,
    disaDescriptionFields,
    checkFormFields,

    // Form state
    isFormDisabled,
    forceEnableAdditionalQuestions,

    // Severity override
    effectiveStatus,
    severityChanged,
    showSeverityOverride,
    severityEditable,

    // Section visibility
    showDisaSection,
    showChecksSection,
    showCollapsibleSections,

    // Granular locking
    isFieldLocked,
    isFieldEditable,

    // Field state visualization
    fieldStateClass,
    activeFieldStates,
  };
}
