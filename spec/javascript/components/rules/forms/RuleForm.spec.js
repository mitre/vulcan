/**
 * RuleForm.vue — Behavioral Mount Tests
 *
 * Tests the TEMPLATE CONTRACT: given specific field props, the form renders
 * the correct fields, disables the right inputs, and always shows IA Control/CCI.
 *
 * These complement composable tests (useRuleFormFields.spec.js) which verify
 * that the correct props are COMPUTED. These tests verify the template
 * correctly RESPONDS to those props — catching v-if bugs, binding errors,
 * and missing fields.
 *
 * REQUIREMENTS (from docs/development/rule-form-business-rules.md):
 * R1: Fields render when in fields.displayed, hidden when not
 * R2: Fields disable when in fields.disabled or when form disabled prop is true
 * R3: IA Control/CCI always visible when rule has data (not status-gated)
 * R4: severity_override_guidance renders between severity and title
 * R5: DISA section rendered when disa_fields prop provided
 * R6: Check section rendered when check_fields prop provided
 * R7: Status text reflects satisfied_by
 */
import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleForm from "@/components/rules/forms/RuleForm.vue";

// Lightweight stub — exposes disabled state via native <textarea>
const MarkdownTextareaStub = {
  name: "MarkdownTextarea",
  template: '<textarea :disabled="disabled" :id="id"></textarea>',
  props: ["value", "disabled", "id", "inputClass", "placeholder", "rows", "maxRows"],
};

function makeRule(overrides = {}) {
  return {
    status: "Applicable - Configurable",
    rule_severity: "medium",
    locked: false,
    review_requestor_id: null,
    satisfied_by: [],
    title: "Test Title",
    fixtext: "Test Fix",
    vendor_comments: "Test Comments",
    status_justification: "Test Justification",
    artifact_description: "Test Artifact",
    version: "1.0",
    rule_weight: "10.0",
    fix_id: "F-1234",
    fixtext_fixref: "SV-1234",
    ident: "CCI-000015",
    ident_system: "https://iase.disa.mil/cci",
    nist_control_family: "AC-2 (1)",
    disa_rule_descriptions_attributes: [
      {
        _destroy: false,
        vuln_discussion: "Test discussion",
        severity_override_guidance: "",
      },
    ],
    checks_attributes: [{ content: "Test check", _destroy: false }],
    srg_rule_attributes: { rule_severity: "medium" },
    ...overrides,
  };
}

const defaultStatuses = [
  "Not Yet Determined",
  "Applicable - Configurable",
  "Applicable - Inherently Meets",
  "Applicable - Does Not Meet",
  "Not Applicable",
];

describe("RuleForm", () => {
  let wrapper;

  const createWrapper = (propsOverrides = {}) => {
    return mount(RuleForm, {
      localVue,
      stubs: {
        MarkdownTextarea: MarkdownTextareaStub,
        DisaRuleDescriptionForm: true,
        CheckForm: true,
        AdditionalQuestions: true,
      },
      propsData: {
        rule: makeRule(),
        statuses: defaultStatuses,
        disabled: false,
        fields: {
          displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
          disabled: [],
        },
        ...propsOverrides,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  // ─── R1: Fields render when in displayed, hidden when not ──
  describe("field visibility based on fields.displayed (R1)", () => {
    it("renders status dropdown when in displayed", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[id^="ruleEditor-status-group-"]').exists()).toBe(true);
    });

    it("renders severity dropdown when in displayed", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[id^="ruleEditor-rule_severity-group-"]').exists()).toBe(true);
    });

    it("renders title field when in displayed", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[id^="ruleEditor-title-group-"]').exists()).toBe(true);
    });

    it("renders fixtext field when in displayed", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[id^="ruleEditor-fixtext-group-"]').exists()).toBe(true);
    });

    it("renders vendor_comments when in displayed", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[id^="ruleEditor-vendor_comments-group-"]').exists()).toBe(true);
    });

    it("does NOT render title when not in displayed", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity"], disabled: [] },
      });
      expect(wrapper.find('[id^="ruleEditor-title-group-"]').exists()).toBe(false);
    });

    it("does NOT render fixtext when not in displayed", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity", "title"], disabled: [] },
      });
      expect(wrapper.find('[id^="ruleEditor-fixtext-group-"]').exists()).toBe(false);
    });

    it("does NOT render status_justification when not in displayed", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity", "title"], disabled: [] },
      });
      expect(wrapper.find('[id^="ruleEditor-status_justification-group-"]').exists()).toBe(false);
    });

    it("renders status_justification when in displayed", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity", "status_justification"], disabled: [] },
      });
      expect(wrapper.find('[id^="ruleEditor-status_justification-group-"]').exists()).toBe(true);
    });

    it("renders advanced fields when in displayed", () => {
      wrapper = createWrapper({
        fields: {
          displayed: [
            "status",
            "rule_severity",
            "title",
            "fixtext",
            "vendor_comments",
            "version",
            "rule_weight",
            "fix_id",
            "fixtext_fixref",
            "ident",
            "ident_system",
          ],
          disabled: [],
        },
      });
      expect(wrapper.find('[id^="ruleEditor-version-group-"]').exists()).toBe(true);
      expect(wrapper.find('[id^="ruleEditor-rule_weight-group-"]').exists()).toBe(true);
      expect(wrapper.find('[id^="ruleEditor-fix_id-group-"]').exists()).toBe(true);
      expect(wrapper.find('[id^="ruleEditor-fixtext_fixref-group-"]').exists()).toBe(true);
      expect(wrapper.find('[id^="ruleEditor-ident-group-"]').exists()).toBe(true);
      expect(wrapper.find('[id^="ruleEditor-ident_system-group-"]').exists()).toBe(true);
    });

    it("does NOT render advanced fields when not in displayed", () => {
      wrapper = createWrapper({
        fields: {
          displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
          disabled: [],
        },
      });
      expect(wrapper.find('[id^="ruleEditor-version-group-"]').exists()).toBe(false);
      expect(wrapper.find('[id^="ruleEditor-rule_weight-group-"]').exists()).toBe(false);
      expect(wrapper.find('[id^="ruleEditor-fix_id-group-"]').exists()).toBe(false);
      expect(wrapper.find('[id^="ruleEditor-fixtext_fixref-group-"]').exists()).toBe(false);
      expect(wrapper.find('[id^="ruleEditor-ident-group-"]').exists()).toBe(false);
      expect(wrapper.find('[id^="ruleEditor-ident_system-group-"]').exists()).toBe(false);
    });
  });

  // ─── R2: Fields disable when in fields.disabled ────────────
  describe("field disability based on fields.disabled and disabled prop (R2)", () => {
    it("disables severity dropdown when in fields.disabled", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity", "title"], disabled: ["rule_severity"] },
      });
      const select = wrapper.find('select[id^="ruleEditor-rule_severity-"]');
      expect(select.element.disabled).toBe(true);
    });

    it("does NOT disable severity when not in fields.disabled", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity", "title"], disabled: [] },
      });
      const select = wrapper.find('select[id^="ruleEditor-rule_severity-"]');
      expect(select.element.disabled).toBe(false);
    });

    it("disables title textarea when in fields.disabled", () => {
      wrapper = createWrapper({
        fields: { displayed: ["status", "rule_severity", "title", "fixtext"], disabled: ["title"] },
      });
      const textarea = wrapper.find('textarea[id^="ruleEditor-title-"]');
      expect(textarea.element.disabled).toBe(true);
    });

    it("disables fixtext textarea when in fields.disabled", () => {
      wrapper = createWrapper({
        fields: {
          displayed: ["status", "rule_severity", "title", "fixtext"],
          disabled: ["fixtext"],
        },
      });
      const textarea = wrapper.find('textarea[id^="ruleEditor-fixtext-"]');
      expect(textarea.element.disabled).toBe(true);
    });

    it("disables all fields when form-level disabled prop is true", () => {
      wrapper = createWrapper({
        disabled: true,
        fields: { displayed: ["status", "rule_severity", "title"], disabled: [] },
      });
      expect(wrapper.find('select[id^="ruleEditor-status-"]').element.disabled).toBe(true);
      expect(wrapper.find('select[id^="ruleEditor-rule_severity-"]').element.disabled).toBe(true);
      expect(wrapper.find('textarea[id^="ruleEditor-title-"]').element.disabled).toBe(true);
    });
  });

  // ─── R3: IA Control/CCI always visible ─────────────────────
  describe("IA Control/CCI always visible when rule has data (R3)", () => {
    it("renders IA Control/CCI section when rule has nist_control_family and ident", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[data-testid="ia-control-cci"]').exists()).toBe(true);
    });

    it("displays the correct IA Control value", () => {
      wrapper = createWrapper();
      const iaInput = wrapper.find('input[id^="ruleEditor-nist_control_family-"]');
      expect(iaInput.element.value).toBe("AC-2 (1)");
    });

    it("displays the correct CCI value", () => {
      wrapper = createWrapper();
      const cciInput = wrapper.find('input[id^="ruleEditor-cci-"]');
      expect(cciInput.element.value).toBe("CCI-000015");
    });

    it("IA Control and CCI inputs are readonly", () => {
      wrapper = createWrapper();
      const iaInput = wrapper.find('input[id^="ruleEditor-nist_control_family-"]');
      const cciInput = wrapper.find('input[id^="ruleEditor-cci-"]');
      expect(iaInput.attributes("readonly")).toBeDefined();
      expect(cciInput.attributes("readonly")).toBeDefined();
    });

    it("does NOT render when rule has no nist_control_family or ident", () => {
      wrapper = createWrapper({
        rule: makeRule({ nist_control_family: null, ident: null }),
      });
      expect(wrapper.find('[data-testid="ia-control-cci"]').exists()).toBe(false);
    });

    it("renders regardless of which fields are in displayed", () => {
      // Even with minimal fields (Inherently Meets-like), IA Control/CCI renders
      wrapper = createWrapper({
        fields: {
          displayed: ["status", "rule_severity", "status_justification"],
          disabled: [],
        },
      });
      expect(wrapper.find('[data-testid="ia-control-cci"]').exists()).toBe(true);
    });
  });

  // ─── R4: severity_override_guidance ─────────────────────────
  describe("severity_override_guidance rendering (R4)", () => {
    it("renders when included in fields.displayed", () => {
      wrapper = createWrapper({
        fields: {
          displayed: ["status", "rule_severity", "severity_override_guidance", "title"],
          disabled: [],
        },
      });
      expect(wrapper.find('[id^="ruleEditor-severity_override_guidance-group-"]').exists()).toBe(
        true,
      );
    });

    it("does NOT render when not in fields.displayed", () => {
      wrapper = createWrapper({
        fields: {
          displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
          disabled: [],
        },
      });
      expect(wrapper.find('[id^="ruleEditor-severity_override_guidance-group-"]').exists()).toBe(
        false,
      );
    });

    it('has label "Severity Override Guidance"', () => {
      wrapper = createWrapper({
        fields: {
          displayed: ["status", "rule_severity", "severity_override_guidance", "title"],
          disabled: [],
        },
      });
      const group = wrapper.find('[id^="ruleEditor-severity_override_guidance-group-"]');
      const label = group.find("label");
      expect(label.text()).toContain("Severity Override Guidance");
    });
  });

  // ─── R5: DISA section ──────────────────────────────────────
  describe("DISA section controlled by disa_fields prop (R5)", () => {
    it("renders DisaRuleDescriptionForm when disa_fields prop provided", () => {
      wrapper = createWrapper({
        disa_fields: { displayed: ["vuln_discussion"], disabled: [] },
      });
      expect(wrapper.findComponent({ name: "DisaRuleDescriptionForm" }).exists()).toBe(true);
    });

    it("does NOT render DisaRuleDescriptionForm when disa_fields is undefined", () => {
      wrapper = createWrapper();
      // disa_fields prop defaults to undefined
      expect(wrapper.findComponent({ name: "DisaRuleDescriptionForm" }).exists()).toBe(false);
    });
  });

  // ─── R6: Check section ─────────────────────────────────────
  describe("Check section controlled by check_fields prop (R6)", () => {
    it("renders CheckForm when check_fields prop provided", () => {
      wrapper = createWrapper({
        check_fields: { displayed: ["content"], disabled: [] },
      });
      expect(wrapper.findComponent({ name: "CheckForm" }).exists()).toBe(true);
    });

    it("does NOT render CheckForm when check_fields is undefined", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "CheckForm" }).exists()).toBe(false);
    });
  });

  // ─── R7: satisfied_by status display ────────────────────────
  describe("satisfied_by status display (R7)", () => {
    it('shows "Applicable - Configurable" in status dropdown when satisfied_by is set', () => {
      wrapper = createWrapper({
        rule: makeRule({
          status: "Not Yet Determined",
          satisfied_by: [{ id: 1, fixtext: "parent fix" }],
        }),
        fields: {
          displayed: ["status", "rule_severity", "title", "fixtext", "vendor_comments"],
          disabled: ["title", "fixtext"],
        },
      });
      const select = wrapper.find('select[id^="ruleEditor-status-"]');
      expect(select.element.value).toBe("Applicable - Configurable");
    });
  });

  // ─── NYD tooltip guidance ───────────────────────────────────
  describe("Not Yet Determined tooltip guidance", () => {
    // REQUIREMENT: When status is NYD, field tooltips should explain
    // that the user must change status before editing those fields.

    it("shows NYD guidance tooltip for title when status is NYD", () => {
      wrapper = createWrapper({ rule: makeRule({ status: "Not Yet Determined" }) });
      expect(wrapper.vm.tooltips.title).toContain("Change the status");
    });

    it("shows normal tooltip for title when status is not NYD", () => {
      wrapper = createWrapper({ rule: makeRule({ status: "Applicable - Configurable" }) });
      expect(wrapper.vm.tooltips.title).toBe("Describe the vulnerability for this control");
    });

    it("does NOT replace the status tooltip with NYD guidance", () => {
      // Status field must always show status descriptions so user knows what to pick
      wrapper = createWrapper({ rule: makeRule({ status: "Not Yet Determined" }) });
      expect(wrapper.vm.tooltips.status).toContain("Configurable");
      expect(wrapper.vm.tooltips.status).not.toContain("Change the status");
    });

    it("shows NYD guidance for fixtext when status is NYD", () => {
      wrapper = createWrapper({ rule: makeRule({ status: "Not Yet Determined" }) });
      expect(wrapper.vm.tooltips.fixtext).toContain("Change the status");
    });
  });
});
