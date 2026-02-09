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
import {
  STATUS_FIELD_CONFIG,
  SEVERITY_EDITABLE_STATUSES,
  SEVERITY_OVERRIDE_STATUSES,
  LOCKABLE_SECTIONS,
} from "./ruleFieldConfig";

// ─── Helper: build field set from config ──────────────────
function buildFieldSet(config, isAdvanced) {
  if (!config) {
    return { displayed: [], disabled: [] };
  }

  const displayed = [...config.displayed];
  const disabled = [...(config.disabled || [])];

  if (isAdvanced && config.advancedDisplayed) {
    displayed.push(...config.advancedDisplayed);
  }
  if (isAdvanced && config.advancedDisabled) {
    disabled.push(...config.advancedDisabled);
  }

  return { displayed, disabled };
}

// ─── Status config lookup ───────────────────────────────────
function getStatusConfig(status) {
  return STATUS_FIELD_CONFIG[status] || { rule: null, disa: null, check: null };
}

export function useRuleFormFields(rule, advancedMode, options = {}) {
  const readOnly = options.readOnly || { value: false };

  // ─── Effective status (satisfied_by forces Configurable) ───
  const effectiveStatus = computed(() => {
    const r = rule.value;
    if (r.satisfied_by && r.satisfied_by.length > 0) {
      return "Applicable - Configurable";
    }
    return r.status;
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

  const severityEditable = computed(() => {
    return SEVERITY_EDITABLE_STATUSES.includes(effectiveStatus.value);
  });

  const showSeverityOverride = computed(() => {
    return severityChanged.value && SEVERITY_OVERRIDE_STATUSES.includes(effectiveStatus.value);
  });

  // ─── Rule form fields ─────────────────────────────────────
  const ruleFormFields = computed(() => {
    const config = getStatusConfig(effectiveStatus.value);
    const result = buildFieldSet(config.rule, advancedMode.value);

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

    return result;
  });

  // ─── DISA description fields ──────────────────────────────
  const disaDescriptionFields = computed(() => {
    const config = getStatusConfig(effectiveStatus.value);
    return buildFieldSet(config.disa, advancedMode.value);
  });

  // ─── Check form fields ────────────────────────────────────
  const checkFormFields = computed(() => {
    const config = getStatusConfig(effectiveStatus.value);
    return buildFieldSet(config.check, advancedMode.value);
  });

  // ─── Section visibility ───────────────────────────────────
  const showDisaSection = computed(() => disaDescriptionFields.value.displayed.length > 0);
  const showChecksSection = computed(() => checkFormFields.value.displayed.length > 0);

  // Collapsible sections only when advanced mode adds extra DISA/check fields
  // beyond basic. Statuses with no advanced additions keep fields inline.
  const showCollapsibleSections = computed(() => {
    const config = getStatusConfig(effectiveStatus.value);
    const hasAdvancedDisa = config.disa?.advancedDisplayed?.length > 0;
    const hasAdvancedRule = config.rule?.advancedDisplayed?.length > 0;
    return hasAdvancedDisa || hasAdvancedRule;
  });

  // ─── Granular locking stubs (Phase 5) ─────────────────────
  function isFieldLocked(fieldName) {
    const r = rule.value;
    if (!r.locked_fields) return false;
    // Find which section this field belongs to
    for (const [, fields] of Object.entries(LOCKABLE_SECTIONS)) {
      if (fields.includes(fieldName)) {
        return !!r.locked_fields[fieldName];
      }
    }
    return false;
  }

  function isFieldEditable(fieldName) {
    if (isFormDisabled.value) return false;
    return !isFieldLocked(fieldName);
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
  };
}
