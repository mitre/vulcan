import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleDetails from "@/components/benchmarks/RuleDetails.vue";

/**
 * RuleDetails Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. GENERIC (works for STIG, SRG, and Component):
 *    - Accepts type prop ('stig' | 'srg' | 'component')
 *    - Displays rule title
 *    - Renders vuln discussion form
 *    - Renders check form
 *    - Renders fix text via RuleFormGroup
 *    - Renders vendor comments via RuleFormGroup if present
 *
 * 2. NO TYPE-SPECIFIC DISPLAY:
 *    - Component structure is the same for all types
 *    - All fields are generic (rule has same structure)
 *
 * 3. DISABLED FORMS:
 *    - All form fields disabled (read-only viewer)
 */
describe("RuleDetails", () => {
  let wrapper;

  const mockRule = {
    id: 1,
    title: "Test Rule Title",
    fixtext: "Fix instructions here",
    vendor_comments: "Vendor note about this rule",
    disa_rule_descriptions_attributes: [
      { vuln_discussion: "Vulnerability details and discussion" },
    ],
    checks_attributes: [{ content: "Check content and procedure" }],
  };

  const mockRuleWithoutVendorComments = {
    id: 2,
    title: "Another Rule",
    fixtext: "Different fix",
    disa_rule_descriptions_attributes: [{ vuln_discussion: "Different vuln" }],
    checks_attributes: [{ content: "Different check" }],
  };

  const createWrapper = (props = {}) => {
    return shallowMount(RuleDetails, {
      localVue,
      propsData: {
        selectedRule: mockRule,
        type: "stig",
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // TYPE PROP
  // ==========================================
  describe("type prop", () => {
    it("accepts stig type", () => {
      wrapper = createWrapper({ type: "stig" });
      expect(wrapper.props("type")).toBe("stig");
    });

    it("accepts srg type", () => {
      wrapper = createWrapper({ type: "srg" });
      expect(wrapper.props("type")).toBe("srg");
    });

    it("type prop is required", () => {
      expect(RuleDetails.props.type.required).toBe(true);
    });

    it("validates type prop", () => {
      const validator = RuleDetails.props.type.validator;
      expect(validator("stig")).toBe(true);
      expect(validator("srg")).toBe(true);
      expect(validator("component")).toBe(true);
      expect(validator("invalid")).toBe(false);
    });
  });

  // ==========================================
  // BASIC RENDERING
  // ==========================================
  describe("basic rendering", () => {
    it("renders rule title in card header", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Test Rule Title");
    });

    it("renders fix text via RuleFormGroup", () => {
      wrapper = createWrapper();
      const groups = wrapper.findAllComponents({ name: "RuleFormGroup" });
      const fixtextGroup = groups.wrappers.find((w) => w.props("fieldName") === "fixtext");
      expect(fixtextGroup).toBeTruthy();
    });

    it("renders vendor comments via RuleFormGroup when present", () => {
      wrapper = createWrapper({ selectedRule: mockRule });
      const groups = wrapper.findAllComponents({ name: "RuleFormGroup" });
      const vcGroup = groups.wrappers.find((w) => w.props("fieldName") === "vendor_comments");
      expect(vcGroup).toBeTruthy();
    });

    it("does not render vendor comments when absent", () => {
      wrapper = createWrapper({ selectedRule: mockRuleWithoutVendorComments });
      const groups = wrapper.findAllComponents({ name: "RuleFormGroup" });
      const vcGroup = groups.wrappers.find((w) => w.props("fieldName") === "vendor_comments");
      expect(vcGroup).toBeFalsy();
    });
  });

  // ==========================================
  // FORM COMPONENTS
  // ==========================================
  describe("form components", () => {
    it("passes disabled=true to DisaRuleDescriptionForm", () => {
      wrapper = createWrapper();
      const disaForm = wrapper.findComponent({ name: "DisaRuleDescriptionForm" });
      expect(disaForm.exists()).toBe(true);
      expect(disaForm.props("disabled")).toBe(true);
    });

    it("passes disabled=true to CheckForm", () => {
      wrapper = createWrapper();
      const checkForm = wrapper.findComponent({ name: "CheckForm" });
      expect(checkForm.exists()).toBe(true);
      expect(checkForm.props("disabled")).toBe(true);
    });

    it("configures disaDescriptionFormFields correctly", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.disaDescriptionFormFields).toEqual({
        displayed: ["vuln_discussion"],
        disabled: [],
      });
    });

    it("configures checkFormFields correctly", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.checkFormFields).toEqual({
        displayed: ["content"],
        disabled: [],
      });
    });
  });

  // ==========================================
  // GENERIC BEHAVIOR (same for STIG and SRG)
  // ==========================================
  describe("generic behavior", () => {
    it("renders identically for STIG type", () => {
      const stigWrapper = createWrapper({ type: "stig" });
      expect(stigWrapper.text()).toContain("Test Rule Title");
      const groups = stigWrapper.findAllComponents({ name: "RuleFormGroup" });
      expect(groups.wrappers.find((w) => w.props("fieldName") === "fixtext")).toBeTruthy();
    });

    it("renders identically for SRG type", () => {
      const srgWrapper = createWrapper({ type: "srg" });
      expect(srgWrapper.text()).toContain("Test Rule Title");
      const groups = srgWrapper.findAllComponents({ name: "RuleFormGroup" });
      expect(groups.wrappers.find((w) => w.props("fieldName") === "fixtext")).toBeTruthy();
    });
  });

  // ==========================================
  // NULL/UNDEFINED RULE HANDLING
  // ==========================================
  describe("null/undefined rule handling", () => {
    it("accepts null selectedRule without Vue warnings", () => {
      const errors = [];
      const originalError = console.error;
      console.error = (...args) => errors.push(args.join(" "));

      wrapper = shallowMount(RuleDetails, {
        localVue,
        propsData: {
          selectedRule: null,
          type: "stig",
        },
      });

      console.error = originalError;

      const propErrors = errors.filter(
        (e) => e.includes("Invalid prop") || e.includes("type check failed"),
      );
      expect(propErrors.length).toBe(0);
    });

    it("shows placeholder message when selectedRule is null", () => {
      wrapper = shallowMount(RuleDetails, {
        localVue,
        propsData: {
          selectedRule: null,
          type: "stig",
        },
      });

      expect(wrapper.text()).toContain("Select a rule from the list to view details");
    });
  });
});
