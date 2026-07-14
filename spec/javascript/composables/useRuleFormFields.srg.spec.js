/**
 * REQUIREMENTS — useRuleFormFields kind-awareness (three-state model):
 *
 * The composable resolves field sets from fieldStateConfig by document
 * kind. Callers pass `documentType` (Ref) in options; omitting it means
 * STIG — the only kind existing pages serve until the SRG editor wires
 * document_type through (a documented default, not a data fabrication).
 * The Advanced Fields toggle is the interim tier switch: advanced ON
 * resolves the publisher tier.
 *
 * SRG behavior through the composable must follow the decided lifecycle:
 * working statuses fully editable with severity/identifiers inherited
 * read-only, Not Applicable showing only status + justification, and the
 * publisher tier unlocking severity + the CCI identifier.
 */
import { describe, it, expect } from "vitest";
import { ref } from "vue";
import { useRuleFormFields } from "@/composables/useRuleFormFields";

function makeSrgRule(overrides = {}) {
  return ref({
    status: "Not Yet Determined",
    locked: false,
    review_requestor_id: null,
    locked_fields: {},
    ...overrides,
  });
}

const srgOptions = () => ({ documentType: ref("srg") });

describe("useRuleFormFields — SRG kind", () => {
  it("NYD (author): content fields editable; severity and IA/CCI displayed read-only; no justification", () => {
    const { ruleFormFields, disaDescriptionFields, checkFormFields } = useRuleFormFields(
      makeSrgRule(),
      ref(false),
      srgOptions(),
    );
    expect(ruleFormFields.value.displayed).toContain("status");
    expect(ruleFormFields.value.displayed).toContain("title");
    expect(ruleFormFields.value.displayed).toContain("fixtext");
    expect(ruleFormFields.value.disabled).not.toContain("title");
    expect(ruleFormFields.value.disabled).not.toContain("fixtext");
    expect(ruleFormFields.value.disabled).toEqual(
      expect.arrayContaining(["rule_severity", "nist_control_family", "cci"]),
    );
    expect(ruleFormFields.value.displayed).not.toContain("status_justification");
    expect(disaDescriptionFields.value.displayed).toEqual(["vuln_discussion"]);
    expect(checkFormFields.value.displayed).toEqual(["content"]);
  });

  it("Applicable (author): identical field sets to NYD", () => {
    const nyd = useRuleFormFields(makeSrgRule(), ref(false), srgOptions());
    const applicable = useRuleFormFields(
      makeSrgRule({ status: "Applicable" }),
      ref(false),
      srgOptions(),
    );
    expect(applicable.ruleFormFields.value).toEqual(nyd.ruleFormFields.value);
    expect(applicable.disaDescriptionFields.value).toEqual(nyd.disaDescriptionFields.value);
    expect(applicable.checkFormFields.value).toEqual(nyd.checkFormFields.value);
  });

  it("Not Applicable: only status + justification; DISA and check sections hidden entirely", () => {
    const { ruleFormFields, showDisaSection, showChecksSection } = useRuleFormFields(
      makeSrgRule({ status: "Not Applicable" }),
      ref(false),
      srgOptions(),
    );
    expect([...ruleFormFields.value.displayed].sort()).toEqual(["status", "status_justification"]);
    expect(ruleFormFields.value.disabled).toEqual([]);
    expect(showDisaSection.value).toBe(false);
    expect(showChecksSection.value).toBe(false);
  });

  it("publisher tier (advanced ON): severity becomes editable and the CCI identifier appears", () => {
    const { ruleFormFields, severityEditable } = useRuleFormFields(
      makeSrgRule(),
      ref(true),
      srgOptions(),
    );
    expect(ruleFormFields.value.disabled).not.toContain("rule_severity");
    expect(ruleFormFields.value.displayed).toContain("ident");
    expect(severityEditable.value).toBe(true);
  });

  it("author tier: severityEditable is false (inherited read-only)", () => {
    const { severityEditable } = useRuleFormFields(makeSrgRule(), ref(false), srgOptions());
    expect(severityEditable.value).toBe(false);
  });

  it("STIG-only fields never appear in SRG sets (leak regression)", () => {
    ["Not Yet Determined", "Applicable", "Not Applicable"].forEach((status) => {
      [false, true].forEach((advanced) => {
        const { ruleFormFields, disaDescriptionFields } = useRuleFormFields(
          makeSrgRule({ status }),
          ref(advanced),
          srgOptions(),
        );
        expect(ruleFormFields.value.displayed).not.toContain("vendor_comments");
        expect(ruleFormFields.value.displayed).not.toContain("artifact_description");
        expect(disaDescriptionFields.value.displayed).not.toContain("mitigations");
        expect(disaDescriptionFields.value.displayed).not.toContain("ia_controls");
      });
    });
  });

  it("section locking still composes: a locked Title section disables title on an SRG row", () => {
    const { ruleFormFields } = useRuleFormFields(
      makeSrgRule({ locked_fields: { Title: true } }),
      ref(false),
      srgOptions(),
    );
    expect(ruleFormFields.value.displayed).toContain("title");
    expect(ruleFormFields.value.disabled).toContain("title");
  });
});

describe("useRuleFormFields — STIG default and equivalence", () => {
  it("omitting documentType resolves STIG (documented default) — AC basic shape unchanged", () => {
    const rule = ref({
      status: "Applicable - Configurable",
      locked: false,
      review_requestor_id: null,
      locked_fields: {},
    });
    const { ruleFormFields } = useRuleFormFields(rule, ref(false));
    expect(ruleFormFields.value.displayed).toEqual(
      expect.arrayContaining(["status", "rule_severity", "title", "fixtext", "vendor_comments"]),
    );
    expect(ruleFormFields.value.displayed).not.toContain("version");
  });

  it("STIG advanced ON reveals the legacy advanced fields (interim publisher mapping)", () => {
    const rule = ref({
      status: "Applicable - Configurable",
      locked: false,
      review_requestor_id: null,
      locked_fields: {},
    });
    const { ruleFormFields } = useRuleFormFields(rule, ref(true));
    expect(ruleFormFields.value.displayed).toEqual(
      expect.arrayContaining(["version", "rule_weight", "ident", "ident_system"]),
    );
  });

  it("the IA/CCI reference keys are displayed read-only at every STIG status (absorption)", () => {
    [
      "Applicable - Configurable",
      "Not Yet Determined",
      "Applicable - Inherently Meets",
      "Applicable - Does Not Meet",
      "Not Applicable",
    ].forEach((status) => {
      const rule = ref({ status, locked: false, review_requestor_id: null, locked_fields: {} });
      const { ruleFormFields } = useRuleFormFields(rule, ref(false));
      expect(ruleFormFields.value.displayed).toEqual(
        expect.arrayContaining(["nist_control_family", "cci"]),
      );
      expect(ruleFormFields.value.disabled).toEqual(
        expect.arrayContaining(["nist_control_family", "cci"]),
      );
    });
  });
});
