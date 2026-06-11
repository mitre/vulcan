import { describe, it, expect, afterEach, vi } from "vitest";
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
  // CONSISTENT FIELD RENDERING
  // All fields must render through RuleFormGroup directly —
  // the viewer must NOT reuse editor wrapper components.
  // ==========================================
  describe("consistent field rendering", () => {
    it("renders all four content fields through RuleFormGroup directly", () => {
      wrapper = createWrapper();
      const groups = wrapper.findAllComponents({ name: "RuleFormGroup" });
      const fieldNames = groups.wrappers.map((w) => w.props("fieldName"));
      expect(fieldNames).toContain("vuln_discussion");
      expect(fieldNames).toContain("content");
      expect(fieldNames).toContain("fixtext");
      expect(fieldNames).toContain("vendor_comments");
    });

    it("does not use editor wrapper components", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "DisaRuleDescriptionForm" }).exists()).toBe(false);
      expect(wrapper.findComponent({ name: "CheckForm" }).exists()).toBe(false);
    });

    it("passes disabled and readOnly to all RuleFormGroup instances", () => {
      wrapper = createWrapper();
      const groups = wrapper.findAllComponents({ name: "RuleFormGroup" });
      groups.wrappers.forEach((g) => {
        expect(g.props("disabled")).toBe(true);
        expect(g.props("readOnly")).toBe(true);
      });
    });

    it("renders all text fields through MarkdownTextarea", () => {
      wrapper = createWrapper();
      const textareas = wrapper.findAllComponents({ name: "MarkdownTextarea" });
      expect(textareas.length).toBe(4);
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
      // spy (not manual reassignment) — restored via mockRestore below
      const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});

      wrapper = shallowMount(RuleDetails, {
        localVue,
        propsData: {
          selectedRule: null,
          type: "stig",
        },
      });

      const propErrors = errorSpy.mock.calls
        .map((args) => args.join(" "))
        .filter((e) => e.includes("Invalid prop") || e.includes("type check failed"));
      errorSpy.mockRestore();
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
