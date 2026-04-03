import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import DisaRuleDescriptionForm from "@/components/rules/forms/DisaRuleDescriptionForm.vue";

describe("DisaRuleDescriptionForm", () => {
  const createWrapper = (propsOverrides = {}) => {
    const defaultDescription = {
      _destroy: false,
      documentable: false,
      vuln_discussion: "",
      false_positives: "",
      false_negatives: "",
      mitigations_available: false,
      mitigations: "",
      poam_available: false,
      poam: "",
      severity_override_guidance: "",
      potential_impacts: "",
      third_party_tools: "",
      mitigation_control: "",
      responsibility: "",
      ia_controls: "",
    };

    const defaultRule = {
      status: "Applicable - Configurable",
      satisfied_by: [],
      locked: false,
      review_requestor_id: null,
    };

    const defaultFields = {
      displayed: [
        "documentable",
        "vuln_discussion",
        "false_positives",
        "false_negatives",
        "mitigations_available",
        "mitigations",
        "poam_available",
        "poam",
        "severity_override_guidance",
        "potential_impacts",
        "third_party_tools",
        "mitigation_control",
        "responsibility",
        "ia_controls",
      ],
      disabled: [],
    };

    return mount(DisaRuleDescriptionForm, {
      localVue,
      propsData: {
        description: defaultDescription,
        rule: defaultRule,
        index: 0,
        disabled: false,
        fields: defaultFields,
        ...propsOverrides,
      },
    });
  };

  // REQUIREMENT: Mitigations and Mitigation Control text fields should only
  // be visible when the "Mitigations Available" toggle is ON. POA&M toggle
  // should only appear when Mitigations Available is OFF (XOR behavior).
  // POA&M text field should only appear when POA&M Available is ON.

  describe("mitigations/POA&M conditional visibility", () => {
    it("hides mitigations textarea when mitigations_available is false", () => {
      const wrapper = createWrapper(); // mitigations_available defaults to false
      const field = wrapper.find('[id^="ruleEditor-disa_rule_description-mitigations-group"]');
      expect(field.exists()).toBe(false);
    });

    it("shows mitigations textarea when mitigations_available is true", () => {
      const wrapper = createWrapper({
        description: {
          _destroy: false,
          documentable: false,
          vuln_discussion: "",
          false_positives: "",
          false_negatives: "",
          mitigations_available: true,
          mitigations: "",
          poam_available: false,
          poam: "",
          severity_override_guidance: "",
          potential_impacts: "",
          third_party_tools: "",
          mitigation_control: "",
          responsibility: "",
          ia_controls: "",
        },
      });
      const field = wrapper.find('[id^="ruleEditor-disa_rule_description-mitigations-group"]');
      expect(field.exists()).toBe(true);
    });

    it("hides mitigation_control when mitigations_available is false", () => {
      const wrapper = createWrapper();
      const field = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-mitigation_control-group"]',
      );
      expect(field.exists()).toBe(false);
    });

    it("shows mitigation_control when mitigations_available is true", () => {
      const wrapper = createWrapper({
        description: {
          _destroy: false,
          documentable: false,
          vuln_discussion: "",
          false_positives: "",
          false_negatives: "",
          mitigations_available: true,
          mitigations: "",
          poam_available: false,
          poam: "",
          severity_override_guidance: "",
          potential_impacts: "",
          third_party_tools: "",
          mitigation_control: "",
          responsibility: "",
          ia_controls: "",
        },
      });
      const field = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-mitigation_control-group"]',
      );
      expect(field.exists()).toBe(true);
    });

    it("hides POA&M toggle when mitigations_available is true", () => {
      const wrapper = createWrapper({
        description: {
          _destroy: false,
          documentable: false,
          vuln_discussion: "",
          false_positives: "",
          false_negatives: "",
          mitigations_available: true,
          mitigations: "",
          poam_available: false,
          poam: "",
          severity_override_guidance: "",
          potential_impacts: "",
          third_party_tools: "",
          mitigation_control: "",
          responsibility: "",
          ia_controls: "",
        },
      });
      const field = wrapper.find('[id^="ruleEditor-disa_rule_description-poam_available-group"]');
      expect(field.exists()).toBe(false);
    });

    it("shows POA&M toggle when mitigations_available is false", () => {
      const wrapper = createWrapper();
      const field = wrapper.find('[id^="ruleEditor-disa_rule_description-poam_available-group"]');
      expect(field.exists()).toBe(true);
    });

    it("hides POA&M textarea when poam_available is false", () => {
      const wrapper = createWrapper();
      const field = wrapper.find('[id^="ruleEditor-disa_rule_description-poam-group"]');
      expect(field.exists()).toBe(false);
    });

    it("shows POA&M textarea when poam_available is true and mitigations_available is false", () => {
      const wrapper = createWrapper({
        description: {
          _destroy: false,
          documentable: false,
          vuln_discussion: "",
          false_positives: "",
          false_negatives: "",
          mitigations_available: false,
          mitigations: "",
          poam_available: true,
          poam: "",
          severity_override_guidance: "",
          potential_impacts: "",
          third_party_tools: "",
          mitigation_control: "",
          responsibility: "",
          ia_controls: "",
        },
      });
      const field = wrapper.find('[id^="ruleEditor-disa_rule_description-poam-group"]');
      expect(field.exists()).toBe(true);
    });

    it("hides POA&M textarea when poam_available is true but mitigations_available is also true", () => {
      const wrapper = createWrapper({
        description: {
          _destroy: false,
          documentable: false,
          vuln_discussion: "",
          false_positives: "",
          false_negatives: "",
          mitigations_available: true,
          mitigations: "",
          poam_available: true,
          poam: "",
          severity_override_guidance: "",
          potential_impacts: "",
          third_party_tools: "",
          mitigation_control: "",
          responsibility: "",
          ia_controls: "",
        },
      });
      // POA&M toggle itself should be hidden (XOR)
      const toggle = wrapper.find('[id^="ruleEditor-disa_rule_description-poam_available-group"]');
      expect(toggle.exists()).toBe(false);
      // POA&M text should also be hidden
      const text = wrapper.find('[id^="ruleEditor-disa_rule_description-poam-group"]');
      expect(text.exists()).toBe(false);
    });
  });

  // REQUIREMENT: Fields that are NOT dependent on mitigations/POA&M toggles
  // should always render when included in the displayed list.

  describe("always-visible fields (not toggle-dependent)", () => {
    const alwaysVisibleFields = [
      "potential_impacts",
      "third_party_tools",
      "responsibility",
      "ia_controls",
      "severity_override_guidance",
    ];

    for (const fieldName of alwaysVisibleFields) {
      it(`shows ${fieldName} regardless of mitigations_available state`, () => {
        // Test with mitigations OFF
        const wrapperOff = createWrapper();
        const fieldOff = wrapperOff.find(
          `[id^="ruleEditor-disa_rule_description-${fieldName}-group"]`,
        );
        expect(fieldOff.exists()).toBe(true);

        // Test with mitigations ON
        const wrapperOn = createWrapper({
          description: {
            _destroy: false,
            documentable: false,
            vuln_discussion: "",
            false_positives: "",
            false_negatives: "",
            mitigations_available: true,
            mitigations: "",
            poam_available: false,
            poam: "",
            severity_override_guidance: "",
            potential_impacts: "",
            third_party_tools: "",
            mitigation_control: "",
            responsibility: "",
            ia_controls: "",
          },
        });
        const fieldOn = wrapperOn.find(
          `[id^="ruleEditor-disa_rule_description-${fieldName}-group"]`,
        );
        expect(fieldOn.exists()).toBe(true);
      });
    }
  });

  // REQUIREMENT: All fields should have descriptive tooltips to help users
  // understand what data is expected. No tooltip should be null for
  // fields that accept user input.

  describe("tooltips", () => {
    it("provides tooltips for all toggle and text fields", () => {
      const wrapper = createWrapper();
      const vm = wrapper.vm;

      // These should all have non-null tooltips
      const fieldsRequiringTooltips = [
        "vuln_discussion",
        "false_positives",
        "false_negatives",
        "mitigations_available",
        "poam_available",
        "potential_impacts",
        "third_party_tools",
        "mitigation_control",
        "responsibility",
        "ia_controls",
        "severity_override_guidance",
        "documentable",
      ];

      for (const field of fieldsRequiringTooltips) {
        expect(vm.tooltips[field]).not.toBeNull();
        expect(vm.tooltips[field]).toBeTruthy();
      }
    });
  });

  // REQUIREMENT: The severity_override_guidance field label must read
  // "Severity Override Guidance" to match the DISA STIG terminology.
  // The database column is named severity_override_guidance, the
  // HumanizedTypesMixIn uses "Severity Override Guidance", and the
  // CSV export header is "Severity Override". The label in the form
  // template must be consistent with all of these.

  describe("severity_override_guidance field", () => {
    it("renders the field when included in displayed fields", () => {
      const wrapper = createWrapper();

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]',
      );
      expect(fieldGroup.exists()).toBe(true);
    });

    it('displays the correct label "Severity Override Guidance"', () => {
      const wrapper = createWrapper();

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]',
      );
      const label = fieldGroup.find("label");

      // The label must say "Severity" not "Security"
      expect(label.text()).toContain("Severity Override Guidance");
      expect(label.text()).not.toContain("Security Override Guidance");
    });

    it("does not render when not in displayed fields", () => {
      const wrapper = createWrapper({
        fields: {
          displayed: ["mitigation_control"],
          disabled: [],
        },
      });

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]',
      );
      expect(fieldGroup.exists()).toBe(false);
    });

    it("renders a MarkdownTextarea for the field", () => {
      const wrapper = createWrapper();

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]',
      );
      // MarkdownTextarea wraps b-form-textarea — check it renders
      const textarea = fieldGroup.find(
        'textarea, [id^="ruleEditor-disa_rule_description-severity_override_guidance-"]',
      );
      expect(textarea.exists()).toBe(true);
    });
  });
});
