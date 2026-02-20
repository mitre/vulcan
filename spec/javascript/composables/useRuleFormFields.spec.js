/**
 * Tests for useRuleFormFields composable.
 *
 * Requirements:
 * R1: Field visibility varies by status × mode (basic/advanced)
 * R2: severity_override_guidance shows DYNAMICALLY when severity differs from SRG default
 * R3: satisfied_by forces effectiveStatus to Configurable, disables title+fixtext only
 * R4: Granular locking (stub API — isFieldLocked, isFieldEditable)
 * R5: IA Control/CCI always visible (handled in component, not composable)
 */
import { describe, it, expect } from "vitest";
import { ref } from "vue";
import { useRuleFormFields } from "@/composables/useRuleFormFields";

// Helper to create a rule object with sensible defaults
function makeRule(overrides = {}) {
  return {
    status: "Applicable - Configurable",
    rule_severity: "medium",
    locked: false,
    review_requestor_id: null,
    satisfied_by: [],
    srg_rule_attributes: {
      rule_severity: "medium",
    },
    disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
    checks_attributes: [{ content: "" }],
    nist_control_family: "AC-2 (1)",
    ident: "CCI-000015",
    ...overrides,
  };
}

describe("useRuleFormFields", () => {
  // ─── effectiveStatus ───────────────────────────────────────
  describe("effectiveStatus", () => {
    it("returns rule.status when no satisfied_by", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { effectiveStatus } = useRuleFormFields(rule, ref(false));
      expect(effectiveStatus.value).toBe("Not Applicable");
    });

    it('forces "Applicable - Configurable" when satisfied_by is non-empty', () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          satisfied_by: [{ id: 1, fixtext: "parent fix" }],
        }),
      );
      const { effectiveStatus } = useRuleFormFields(rule, ref(false));
      expect(effectiveStatus.value).toBe("Applicable - Configurable");
    });
  });

  // ─── isFormDisabled ────────────────────────────────────────
  describe("isFormDisabled", () => {
    it("returns false for normal editable rule", () => {
      const rule = ref(makeRule());
      const { isFormDisabled } = useRuleFormFields(rule, ref(false));
      expect(isFormDisabled.value).toBe(false);
    });

    it("returns true when rule is locked", () => {
      const rule = ref(makeRule({ locked: true }));
      const { isFormDisabled } = useRuleFormFields(rule, ref(false));
      expect(isFormDisabled.value).toBe(true);
    });

    it("returns true when rule has review_requestor_id", () => {
      const rule = ref(makeRule({ review_requestor_id: 42 }));
      const { isFormDisabled } = useRuleFormFields(rule, ref(false));
      expect(isFormDisabled.value).toBe(true);
    });

    it("returns true when readOnly option is set", () => {
      const rule = ref(makeRule());
      const { isFormDisabled } = useRuleFormFields(rule, ref(false), { readOnly: ref(true) });
      expect(isFormDisabled.value).toBe(true);
    });

    it("does NOT disable when satisfied_by is set (R3: no whole-form disable)", () => {
      const rule = ref(makeRule({ satisfied_by: [{ id: 1 }] }));
      const { isFormDisabled } = useRuleFormFields(rule, ref(false));
      expect(isFormDisabled.value).toBe(false);
    });
  });

  // ─── forceEnableAdditionalQuestions ────────────────────────
  describe("forceEnableAdditionalQuestions", () => {
    it("returns true for normal editable rule", () => {
      const rule = ref(makeRule());
      const { forceEnableAdditionalQuestions } = useRuleFormFields(rule, ref(false));
      expect(forceEnableAdditionalQuestions.value).toBe(true);
    });

    it("returns false when locked", () => {
      const rule = ref(makeRule({ locked: true }));
      const { forceEnableAdditionalQuestions } = useRuleFormFields(rule, ref(false));
      expect(forceEnableAdditionalQuestions.value).toBe(false);
    });

    it("returns false when under review", () => {
      const rule = ref(makeRule({ review_requestor_id: 5 }));
      const { forceEnableAdditionalQuestions } = useRuleFormFields(rule, ref(false));
      expect(forceEnableAdditionalQuestions.value).toBe(false);
    });
  });

  // ─── severityChanged / severityEditable / showSeverityOverride ─
  describe("severity override detection (R2)", () => {
    it("severityChanged is false when severity matches SRG default", () => {
      const rule = ref(
        makeRule({ rule_severity: "medium", srg_rule_attributes: { rule_severity: "medium" } }),
      );
      const { severityChanged } = useRuleFormFields(rule, ref(false));
      expect(severityChanged.value).toBe(false);
    });

    it("severityChanged is true when severity differs from SRG default", () => {
      const rule = ref(
        makeRule({ rule_severity: "high", srg_rule_attributes: { rule_severity: "medium" } }),
      );
      const { severityChanged } = useRuleFormFields(rule, ref(false));
      expect(severityChanged.value).toBe(true);
    });

    it("severityChanged is false when srg_rule_attributes is null", () => {
      const rule = ref(makeRule({ srg_rule_attributes: null }));
      const { severityChanged } = useRuleFormFields(rule, ref(false));
      expect(severityChanged.value).toBe(false);
    });

    it("severityEditable is true for Configurable", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { severityEditable } = useRuleFormFields(rule, ref(false));
      expect(severityEditable.value).toBe(true);
    });

    it("severityEditable is true for Inherently Meets", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { severityEditable } = useRuleFormFields(rule, ref(false));
      expect(severityEditable.value).toBe(true);
    });

    it("severityEditable is true for Does Not Meet", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { severityEditable } = useRuleFormFields(rule, ref(false));
      expect(severityEditable.value).toBe(true);
    });

    it("severityEditable is false for Not Applicable", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { severityEditable } = useRuleFormFields(rule, ref(false));
      expect(severityEditable.value).toBe(false);
    });

    it("severityEditable is false for Not Yet Determined", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { severityEditable } = useRuleFormFields(rule, ref(false));
      expect(severityEditable.value).toBe(false);
    });

    it("showSeverityOverride is true when severity changed + applicable status", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Configurable",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { showSeverityOverride } = useRuleFormFields(rule, ref(false));
      expect(showSeverityOverride.value).toBe(true);
    });

    it("showSeverityOverride is false when severity matches SRG default", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Configurable",
          rule_severity: "medium",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { showSeverityOverride } = useRuleFormFields(rule, ref(false));
      expect(showSeverityOverride.value).toBe(false);
    });

    it("showSeverityOverride is false for Not Applicable even if severity changed", () => {
      const rule = ref(
        makeRule({
          status: "Not Applicable",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { showSeverityOverride } = useRuleFormFields(rule, ref(false));
      expect(showSeverityOverride.value).toBe(false);
    });

    it("showSeverityOverride is false for Not Yet Determined even if severity changed", () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { showSeverityOverride } = useRuleFormFields(rule, ref(false));
      expect(showSeverityOverride.value).toBe(false);
    });
  });

  // ─── ruleFormFields: Basic mode ────────────────────────────
  describe("ruleFormFields - basic mode", () => {
    const advancedMode = ref(false);

    it("Configurable: shows status, rule_severity, title, fixtext, vendor_comments", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining(["status", "rule_severity", "title", "fixtext", "vendor_comments"]),
      );
      expect(ruleFormFields.value.disabled).toEqual([]);
    });

    it("Not Yet Determined: shows status, rule_severity, title, fixtext; disables title, rule_severity, fixtext", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining(["status", "rule_severity", "title", "fixtext"]),
      );
      expect(ruleFormFields.value.disabled).toEqual(
        expect.arrayContaining(["title", "rule_severity", "fixtext"]),
      );
    });

    it("Inherently Meets: shows status, rule_severity, status_justification, artifact_description, vendor_comments", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "status_justification",
          "artifact_description",
          "vendor_comments",
        ]),
      );
      expect(ruleFormFields.value.disabled).toEqual([]);
    });

    it("Does Not Meet: shows status, rule_severity, status_justification, vendor_comments", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "status_justification",
          "vendor_comments",
        ]),
      );
      expect(ruleFormFields.value.disabled).toEqual([]);
    });

    it("Not Applicable: shows status, rule_severity, status_justification, artifact_description, vendor_comments; disables rule_severity", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "status_justification",
          "artifact_description",
          "vendor_comments",
        ]),
      );
      expect(ruleFormFields.value.disabled).toEqual(expect.arrayContaining(["rule_severity"]));
    });
  });

  // ─── ruleFormFields: Advanced mode ─────────────────────────
  describe("ruleFormFields - advanced mode", () => {
    const advancedMode = ref(true);

    it("Configurable: includes advanced fields like version, rule_weight, fix_id, ident", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      const d = ruleFormFields.value.displayed;
      expect(d).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "title",
          "fixtext",
          "vendor_comments",
          "status_justification",
          "version",
          "rule_weight",
          "artifact_description",
          "fix_id",
          "fixtext_fixref",
          "ident",
          "ident_system",
        ]),
      );
    });

    it("Not Yet Determined: same fields as basic including fixtext (no advanced additions)", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining(["status", "rule_severity", "title", "fixtext"]),
      );
    });

    it("Inherently Meets: same as basic in advanced mode", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "status_justification",
          "artifact_description",
          "vendor_comments",
        ]),
      );
    });

    it("Does Not Meet: same as basic in advanced mode", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "status_justification",
          "vendor_comments",
        ]),
      );
    });

    it("Not Applicable: same as basic in advanced mode", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { ruleFormFields } = useRuleFormFields(rule, advancedMode);
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining([
          "status",
          "rule_severity",
          "status_justification",
          "artifact_description",
          "vendor_comments",
        ]),
      );
      expect(ruleFormFields.value.disabled).toEqual(expect.arrayContaining(["rule_severity"]));
    });
  });

  // ─── disaDescriptionFields: Basic mode ─────────────────────
  describe("disaDescriptionFields - basic mode", () => {
    const advancedMode = ref(false);

    it("Configurable: shows vuln_discussion", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual(
        expect.arrayContaining(["vuln_discussion"]),
      );
    });

    it("Not Yet Determined: shows vuln_discussion disabled", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual(
        expect.arrayContaining(["vuln_discussion"]),
      );
      expect(disaDescriptionFields.value.disabled).toEqual(
        expect.arrayContaining(["vuln_discussion"]),
      );
    });

    it("Inherently Meets: no DISA fields", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual([]);
    });

    it("Does Not Meet: shows mitigations_available, mitigations, mitigation_control, poam_available, poam", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual(
        expect.arrayContaining([
          "mitigations_available",
          "mitigations",
          "mitigation_control",
          "poam_available",
          "poam",
        ]),
      );
    });

    it("Not Applicable: no DISA fields", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual([]);
    });
  });

  // ─── disaDescriptionFields: Advanced mode ──────────────────
  describe("disaDescriptionFields - advanced mode", () => {
    const advancedMode = ref(true);

    it("Configurable: shows all DISA description fields", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual(
        expect.arrayContaining([
          "vuln_discussion",
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
        ]),
      );
    });

    it("Does Not Meet advanced: adds documentable, false_positives, etc.", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      const d = disaDescriptionFields.value.displayed;
      expect(d).toEqual(
        expect.arrayContaining([
          "mitigations_available",
          "mitigations",
          "mitigation_control",
          "poam_available",
          "poam",
          "documentable",
          "false_positives",
          "false_negatives",
          "potential_impacts",
          "third_party_tools",
          "responsibility",
          "ia_controls",
        ]),
      );
    });

    it("Inherently Meets: still no DISA fields even in advanced", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual([]);
    });

    it("Not Applicable: still no DISA fields even in advanced", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { disaDescriptionFields } = useRuleFormFields(rule, advancedMode);
      expect(disaDescriptionFields.value.displayed).toEqual([]);
    });
  });

  // ─── severity_override_guidance dynamic injection ──────────
  describe("severity_override_guidance dynamic injection into rule fields", () => {
    it("injects severity_override_guidance when severity changed + Configurable", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Configurable",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).toContain("severity_override_guidance");
    });

    it("does NOT inject severity_override_guidance when severity matches", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Configurable",
          rule_severity: "medium",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).not.toContain("severity_override_guidance");
    });

    it("injects for Does Not Meet when severity changed", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Does Not Meet",
          rule_severity: "low",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).toContain("severity_override_guidance");
    });

    it("injects for Inherently Meets when severity changed", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Inherently Meets",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).toContain("severity_override_guidance");
    });

    it("does NOT inject for Not Applicable", () => {
      const rule = ref(
        makeRule({
          status: "Not Applicable",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).not.toContain("severity_override_guidance");
    });

    it("does NOT inject for Not Yet Determined", () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).not.toContain("severity_override_guidance");
    });

    it("does not duplicate in advanced mode", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Configurable",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(true));
      const count = ruleFormFields.value.displayed.filter(
        (f) => f === "severity_override_guidance",
      ).length;
      expect(count).toBe(1);
    });
  });

  // ─── checkFormFields ───────────────────────────────────────
  describe("checkFormFields", () => {
    it("Configurable: shows content", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.displayed).toEqual(["content"]);
    });

    it("Not Yet Determined: shows check content disabled", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.displayed).toEqual(["content"]);
      expect(checkFormFields.value.disabled).toEqual(["content"]);
    });

    it("Inherently Meets: no check fields", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.displayed).toEqual([]);
    });

    it("Does Not Meet: no check fields", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.displayed).toEqual([]);
    });

    it("Not Applicable: no check fields", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.displayed).toEqual([]);
    });

    it("satisfied_by: shows content (effective status is Configurable)", () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          satisfied_by: [{ id: 1 }],
        }),
      );
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.displayed).toEqual(["content"]);
    });
  });

  // ─── satisfied_by behavior (R3) ────────────────────────────
  describe("satisfied_by behavior (R3)", () => {
    it("uses Configurable field set when satisfied_by is set", () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          satisfied_by: [{ id: 1, fixtext: "parent fix" }],
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining(["status", "rule_severity", "title", "fixtext", "vendor_comments"]),
      );
    });

    it("disables title and fixtext when satisfied_by is set", () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          satisfied_by: [{ id: 1 }],
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).toEqual(expect.arrayContaining(["title", "fixtext"]));
    });

    it("does NOT disable the entire form (isFormDisabled stays false)", () => {
      const rule = ref(
        makeRule({
          satisfied_by: [{ id: 1 }],
        }),
      );
      const { isFormDisabled } = useRuleFormFields(rule, ref(false));
      expect(isFormDisabled.value).toBe(false);
    });
  });

  // ─── section visibility helpers ────────────────────────────
  describe("section visibility", () => {
    it("showDisaSection is true when DISA fields have displayed entries", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { showDisaSection } = useRuleFormFields(rule, ref(false));
      expect(showDisaSection.value).toBe(true);
    });

    it("showDisaSection is false when no DISA fields (Inherently Meets, basic)", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { showDisaSection } = useRuleFormFields(rule, ref(false));
      expect(showDisaSection.value).toBe(false);
    });

    it("showDisaSection is false for Inherently Meets even when severity changed (override guidance now in rule fields)", () => {
      const rule = ref(
        makeRule({
          status: "Applicable - Inherently Meets",
          rule_severity: "high",
          srg_rule_attributes: { rule_severity: "medium" },
        }),
      );
      const { showDisaSection } = useRuleFormFields(rule, ref(false));
      expect(showDisaSection.value).toBe(false);
    });

    it("showChecksSection is true for Configurable", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { showChecksSection } = useRuleFormFields(rule, ref(false));
      expect(showChecksSection.value).toBe(true);
    });

    it("showChecksSection is true for Not Yet Determined (has disabled check content for context)", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { showChecksSection } = useRuleFormFields(rule, ref(false));
      expect(showChecksSection.value).toBe(true);
    });

    it("showChecksSection is false for Not Applicable (no check fields)", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { showChecksSection } = useRuleFormFields(rule, ref(false));
      expect(showChecksSection.value).toBe(false);
    });

    it("showChecksSection is true when satisfied_by is set", () => {
      const rule = ref(
        makeRule({
          status: "Not Yet Determined",
          satisfied_by: [{ id: 1 }],
        }),
      );
      const { showChecksSection } = useRuleFormFields(rule, ref(false));
      expect(showChecksSection.value).toBe(true);
    });
  });

  // ─── showCollapsibleSections ─────────────────────────────────
  describe("showCollapsibleSections", () => {
    it("is true for Configurable (has advanced DISA additions)", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { showCollapsibleSections } = useRuleFormFields(rule, ref(true));
      expect(showCollapsibleSections.value).toBe(true);
    });

    it("is true for Does Not Meet (has advanced DISA additions)", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { showCollapsibleSections } = useRuleFormFields(rule, ref(true));
      expect(showCollapsibleSections.value).toBe(true);
    });

    it("is false for Not Yet Determined (no advanced additions)", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { showCollapsibleSections } = useRuleFormFields(rule, ref(true));
      expect(showCollapsibleSections.value).toBe(false);
    });

    it("is false for Not Applicable (no advanced additions)", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { showCollapsibleSections } = useRuleFormFields(rule, ref(true));
      expect(showCollapsibleSections.value).toBe(false);
    });

    it("is false for Inherently Meets (no advanced additions)", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { showCollapsibleSections } = useRuleFormFields(rule, ref(true));
      expect(showCollapsibleSections.value).toBe(false);
    });
  });

  // ─── Exact field sets per status (strict assertions) ──────
  // These use toEqual (not arrayContaining) to catch accidental field additions/omissions.
  // Business rules source: docs/development/rule-form-business-rules.md
  describe("exact field sets per status", () => {
    const STATUSES = {
      "Applicable - Configurable": {
        basic: {
          rule: {
            displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
            disabled: [],
          },
          disa: { displayed: ["vuln_discussion"], disabled: [] },
          check: { displayed: ["content"], disabled: [] },
        },
        advanced: {
          rule: {
            displayed: [
              "status",
              "rule_severity",
              "title",
              "fixtext",
              "vendor_comments",
              "status_justification",
              "version",
              "rule_weight",
              "artifact_description",
              "fix_id",
              "fixtext_fixref",
              "ident",
              "ident_system",
            ],
            disabled: [],
          },
          disa: {
            displayed: [
              "vuln_discussion",
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
            disabled: [],
          },
          check: { displayed: ["content"], disabled: [] },
        },
      },
      "Not Yet Determined": {
        basic: {
          rule: {
            displayed: ["status", "rule_severity", "title", "fixtext"],
            disabled: ["title", "rule_severity", "fixtext"],
          },
          disa: { displayed: ["vuln_discussion"], disabled: ["vuln_discussion"] },
          check: { displayed: ["content"], disabled: ["content"] },
        },
        advanced: {
          rule: {
            displayed: ["status", "rule_severity", "title", "fixtext"],
            disabled: ["title", "rule_severity", "fixtext"],
          },
          disa: { displayed: ["vuln_discussion"], disabled: ["vuln_discussion"] },
          check: { displayed: ["content"], disabled: ["content"] },
        },
      },
      "Applicable - Inherently Meets": {
        basic: {
          rule: {
            displayed: [
              "status",
              "rule_severity",
              "status_justification",
              "artifact_description",
              "vendor_comments",
            ],
            disabled: [],
          },
          disa: { displayed: [], disabled: [] },
          check: { displayed: [], disabled: [] },
        },
        advanced: {
          rule: {
            displayed: [
              "status",
              "rule_severity",
              "status_justification",
              "artifact_description",
              "vendor_comments",
            ],
            disabled: [],
          },
          disa: { displayed: [], disabled: [] },
          check: { displayed: [], disabled: [] },
        },
      },
      "Applicable - Does Not Meet": {
        basic: {
          rule: {
            displayed: ["status", "rule_severity", "status_justification", "vendor_comments"],
            disabled: [],
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
          },
          check: { displayed: [], disabled: [] },
        },
        advanced: {
          rule: {
            displayed: ["status", "rule_severity", "status_justification", "vendor_comments"],
            disabled: [],
          },
          disa: {
            displayed: [
              "mitigations_available",
              "mitigations",
              "mitigation_control",
              "poam_available",
              "poam",
              "documentable",
              "false_positives",
              "false_negatives",
              "potential_impacts",
              "third_party_tools",
              "responsibility",
              "ia_controls",
            ],
            disabled: [],
          },
          check: { displayed: [], disabled: [] },
        },
      },
      "Not Applicable": {
        basic: {
          rule: {
            displayed: [
              "status",
              "rule_severity",
              "status_justification",
              "artifact_description",
              "vendor_comments",
            ],
            disabled: ["rule_severity"],
          },
          disa: { displayed: [], disabled: [] },
          check: { displayed: [], disabled: [] },
        },
        advanced: {
          rule: {
            displayed: [
              "status",
              "rule_severity",
              "status_justification",
              "artifact_description",
              "vendor_comments",
            ],
            disabled: ["rule_severity"],
          },
          disa: { displayed: [], disabled: [] },
          check: { displayed: [], disabled: [] },
        },
      },
    };

    for (const [status, modes] of Object.entries(STATUSES)) {
      describe(status, () => {
        for (const [mode, expected] of Object.entries(modes)) {
          const isAdvanced = mode === "advanced";

          it(`${mode} mode: exact ruleFormFields`, () => {
            const rule = ref(makeRule({ status }));
            const { ruleFormFields } = useRuleFormFields(rule, ref(isAdvanced));
            expect(ruleFormFields.value.displayed).toEqual(expected.rule.displayed);
            expect(ruleFormFields.value.disabled).toEqual(expected.rule.disabled);
          });

          it(`${mode} mode: exact disaDescriptionFields`, () => {
            const rule = ref(makeRule({ status }));
            const { disaDescriptionFields } = useRuleFormFields(rule, ref(isAdvanced));
            expect(disaDescriptionFields.value.displayed).toEqual(expected.disa.displayed);
            expect(disaDescriptionFields.value.disabled).toEqual(expected.disa.disabled);
          });

          it(`${mode} mode: exact checkFormFields`, () => {
            const rule = ref(makeRule({ status }));
            const { checkFormFields } = useRuleFormFields(rule, ref(isAdvanced));
            expect(checkFormFields.value.displayed).toEqual(expected.check.displayed);
            expect(checkFormFields.value.disabled).toEqual(expected.check.disabled);
          });
        }
      });
    }
  });

  // ─── Per-section locking (R4) ───────────────────────────
  describe("per-section locking (R4)", () => {
    it("isFieldLocked returns false by default (no locked_fields)", () => {
      const rule = ref(makeRule());
      const { isFieldLocked } = useRuleFormFields(rule, ref(false));
      expect(isFieldLocked("title")).toBe(false);
      expect(isFieldLocked("fixtext")).toBe(false);
    });

    it("isFieldLocked returns true when field section is locked", () => {
      const rule = ref(makeRule({ locked_fields: { Title: true } }));
      const { isFieldLocked } = useRuleFormFields(rule, ref(false));
      expect(isFieldLocked("title")).toBe(true);
    });

    it("isFieldLocked returns false for fields in unlocked sections", () => {
      const rule = ref(makeRule({ locked_fields: { Title: true } }));
      const { isFieldLocked } = useRuleFormFields(rule, ref(false));
      expect(isFieldLocked("fixtext")).toBe(false);
      expect(isFieldLocked("status")).toBe(false);
    });

    it("isFieldLocked returns false when whole-rule is locked (whole-rule takes precedence)", () => {
      const rule = ref(makeRule({ locked: true, locked_fields: { Title: true } }));
      const { isFieldLocked } = useRuleFormFields(rule, ref(false));
      expect(isFieldLocked("title")).toBe(false);
    });

    it("isFieldEditable returns true by default", () => {
      const rule = ref(makeRule());
      const { isFieldEditable } = useRuleFormFields(rule, ref(false));
      expect(isFieldEditable("title")).toBe(true);
    });

    it("isFieldEditable returns false when form is disabled", () => {
      const rule = ref(makeRule({ locked: true }));
      const { isFieldEditable } = useRuleFormFields(rule, ref(false));
      expect(isFieldEditable("title")).toBe(false);
    });

    it("isFieldEditable returns false when field section is locked", () => {
      const rule = ref(makeRule({ locked_fields: { Title: true } }));
      const { isFieldEditable } = useRuleFormFields(rule, ref(false));
      expect(isFieldEditable("title")).toBe(false);
    });

    it("locked sections inject fields into ruleFormFields disabled array", () => {
      // Configurable shows status + title in basic mode
      const rule = ref(makeRule({ locked_fields: { Title: true, Status: true } }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).toContain("title");
      expect(ruleFormFields.value.disabled).toContain("status");
    });

    it("locked sections inject status_justification when displayed", () => {
      // Inherently Meets shows status_justification in basic mode
      const rule = ref(
        makeRule({
          status: "Applicable - Inherently Meets",
          locked_fields: { Status: true },
        }),
      );
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).toContain("status");
      expect(ruleFormFields.value.disabled).toContain("status_justification");
    });

    it("locked sections inject fields into disaDescriptionFields disabled array", () => {
      const rule = ref(makeRule({ locked_fields: { "Vulnerability Discussion": true } }));
      const { disaDescriptionFields } = useRuleFormFields(rule, ref(true));
      expect(disaDescriptionFields.value.disabled).toContain("vuln_discussion");
    });

    it("locked sections inject fields into checkFormFields disabled array", () => {
      const rule = ref(makeRule({ locked_fields: { Check: true } }));
      const { checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(checkFormFields.value.disabled).toContain("content");
    });

    it("does not inject locked fields that are not displayed", () => {
      // Not Applicable status does not display fixtext
      const rule = ref(makeRule({ status: "Not Applicable", locked_fields: { Fix: true } }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).not.toContain("fixtext");
      // Should not add to disabled if not displayed
      expect(ruleFormFields.value.disabled).not.toContain("fixtext");
    });

    it("multiple sections can be locked simultaneously", () => {
      const rule = ref(
        makeRule({
          locked_fields: { Title: true, Fix: true, Check: true, "Vendor Comments": true },
        }),
      );
      const { ruleFormFields, checkFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).toContain("title");
      expect(ruleFormFields.value.disabled).toContain("fixtext");
      expect(ruleFormFields.value.disabled).toContain("vendor_comments");
      expect(checkFormFields.value.disabled).toContain("content");
    });
  });

  // ─── Field state visualization ───────────────────────────
  describe("fieldStateClass (visual state indicators)", () => {
    it("returns empty string for normal editable fields", () => {
      const rule = ref(makeRule());
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      expect(fieldStateClass("title")).toBe("");
    });

    it("returns section-locked class when field section is locked", () => {
      const rule = ref(makeRule({ locked_fields: { Title: true } }));
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      expect(fieldStateClass("title")).toBe("field-state--section-locked");
    });

    it("returns under-review class when rule is under review", () => {
      const rule = ref(makeRule({ review_requestor_id: 42 }));
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      expect(fieldStateClass("title")).toBe("field-state--under-review");
    });

    it("returns whole-locked class when rule is whole-locked", () => {
      const rule = ref(makeRule({ locked: true }));
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      expect(fieldStateClass("title")).toBe("field-state--whole-locked");
    });

    it("section-locked takes priority over under-review for locked fields", () => {
      const rule = ref(
        makeRule({
          locked_fields: { Title: true },
          review_requestor_id: 42,
        }),
      );
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      // Section-locked field shows section-locked (higher priority)
      expect(fieldStateClass("title")).toBe("field-state--section-locked");
      // Non-locked field shows under-review
      expect(fieldStateClass("fixtext")).toBe("field-state--under-review");
    });

    it("whole-locked overrides section-locked (section lock hidden)", () => {
      const rule = ref(makeRule({ locked: true, locked_fields: { Title: true } }));
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      // isFieldLocked returns false when whole-locked, so whole-locked class applies
      expect(fieldStateClass("title")).toBe("field-state--whole-locked");
    });

    it("returns empty for unlocked sections when others are locked", () => {
      const rule = ref(makeRule({ locked_fields: { Title: true } }));
      const { fieldStateClass } = useRuleFormFields(rule, ref(false));
      expect(fieldStateClass("fixtext")).toBe("");
    });
  });

  describe("activeFieldStates (legend display)", () => {
    it("returns empty array for normal rule", () => {
      const rule = ref(makeRule());
      const { activeFieldStates } = useRuleFormFields(rule, ref(false));
      expect(activeFieldStates.value).toEqual([]);
    });

    it("includes section-locked when sections are locked", () => {
      const rule = ref(makeRule({ locked_fields: { Title: true } }));
      const { activeFieldStates } = useRuleFormFields(rule, ref(false));
      expect(activeFieldStates.value).toContain("section-locked");
    });

    it("includes under-review when rule is under review", () => {
      const rule = ref(makeRule({ review_requestor_id: 42 }));
      const { activeFieldStates } = useRuleFormFields(rule, ref(false));
      expect(activeFieldStates.value).toContain("under-review");
    });

    it("includes whole-locked when rule is locked", () => {
      const rule = ref(makeRule({ locked: true }));
      const { activeFieldStates } = useRuleFormFields(rule, ref(false));
      expect(activeFieldStates.value).toContain("whole-locked");
    });

    it("does not include section-locked when whole-locked", () => {
      const rule = ref(makeRule({ locked: true, locked_fields: { Title: true } }));
      const { activeFieldStates } = useRuleFormFields(rule, ref(false));
      expect(activeFieldStates.value).not.toContain("section-locked");
      expect(activeFieldStates.value).toContain("whole-locked");
    });
  });

  // ─── severity disabled logic in ruleFormFields ─────────────
  describe("severity disabled logic in ruleFormFields", () => {
    it("rule_severity is NOT in disabled for Configurable (editable)", () => {
      const rule = ref(makeRule({ status: "Applicable - Configurable" }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).not.toContain("rule_severity");
    });

    it("rule_severity is NOT in disabled for Inherently Meets (now editable per R2)", () => {
      const rule = ref(makeRule({ status: "Applicable - Inherently Meets" }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).not.toContain("rule_severity");
    });

    it("rule_severity is NOT in disabled for Does Not Meet (now editable per R2)", () => {
      const rule = ref(makeRule({ status: "Applicable - Does Not Meet" }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).not.toContain("rule_severity");
    });

    it("rule_severity IS in disabled for Not Applicable", () => {
      const rule = ref(makeRule({ status: "Not Applicable" }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).toContain("rule_severity");
    });

    it("rule_severity IS in disabled for Not Yet Determined", () => {
      const rule = ref(makeRule({ status: "Not Yet Determined" }));
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.disabled).toContain("rule_severity");
    });
  });
});
