import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleEditorHeader from "@/components/rules/RuleEditorHeader.vue";

// Mock axios with defaults structure for FormMixin
vi.mock("axios", () => ({
  default: {
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: {
      headers: {
        common: {},
      },
    },
  },
}));

describe("RuleEditorHeader", () => {
  let wrapper;
  const mockRules = [
    {
      id: 1,
      rule_id: "001",
      version: "SV-001r1",
      component_id: 10,
      status: "Not Yet Determined",
      satisfies: [],
      satisfied_by: [],
      histories: [],
      locked: false,
      review_requestor_id: null,
      changes_requested: false,
      disa_rule_descriptions_attributes: [{ mitigations: "" }],
      created_at: "2024-01-01",
      updated_at: "2024-01-01",
      artifact_description: "",
    },
    {
      id: 2,
      rule_id: "002",
      version: "SV-002r1",
      component_id: 10,
      status: "Not Yet Determined",
      satisfies: [],
      satisfied_by: [],
    },
    {
      id: 3,
      rule_id: "003",
      version: "SV-003r1",
      component_id: 10,
      status: "Not Yet Determined",
      satisfies: [],
      satisfied_by: [],
    },
    {
      id: 4,
      rule_id: "004",
      version: "SV-004r1",
      component_id: 10,
      status: "Not Yet Determined",
      satisfies: [{ id: 5 }], // This one already satisfies something, should be excluded
      satisfied_by: [],
    },
  ];

  const createWrapper = (props = {}) => {
    return shallowMount(RuleEditorHeader, {
      localVue,
      propsData: {
        effectivePermissions: "admin",
        currentUserId: 1,
        rule: mockRules[0],
        rules: mockRules,
        projectPrefix: "TEST",
        readOnly: false,
        ...props,
      },
      stubs: {
        CommentModal: true,
        NewRuleModalForm: true,
        Multiselect: true,
      },
    });
  };

  let rootEmitSpy;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    localStorage.clear();
    localStorage.setItem("showSRGIdChecked-10", "false");
  });

  afterEach(() => {
    vi.useRealTimers();
    if (wrapper) {
      wrapper.destroy();
    }
    if (rootEmitSpy) {
      rootEmitSpy.mockRestore();
    }
  });

  describe("multi-select satisfies modal", () => {
    it("has selectedSatisfiesRuleIds initialized as empty array", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedSatisfiesRuleIds).toEqual([]);
    });

    it("has satisfiesSearchText initialized as empty string", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.satisfiesSearchText).toBe("");
    });

    it("filters out rules that already satisfy something", () => {
      wrapper = createWrapper();
      wrapper.vm.filterRules();

      // Rule 4 satisfies something, should be excluded
      // Rule 1 is current rule, should be excluded
      // Rules 2 and 3 should be included
      const ruleIds = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ruleIds).toContain(2);
      expect(ruleIds).toContain(3);
      expect(ruleIds).not.toContain(1); // current rule
      expect(ruleIds).not.toContain(4); // already satisfies something
    });

    it("addMultipleSatisfiedRules emits events for each selected rule", async () => {
      wrapper = createWrapper();
      rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");
      // vue-multiselect passes full objects when track-by is used
      await wrapper.setData({
        selectedSatisfiesRuleIds: [
          { value: 2, text: "TEST-002" },
          { value: 3, text: "TEST-003" },
        ],
      });

      wrapper.vm.addMultipleSatisfiedRules();
      await wrapper.vm.$nextTick();

      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 2, 1);
      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 3, 1);
    });

    it("addMultipleSatisfiedRules handles plain IDs for backwards compatibility", async () => {
      wrapper = createWrapper();
      rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");
      // Also test with plain IDs for backwards compatibility
      await wrapper.setData({ selectedSatisfiesRuleIds: [2, 3] });

      wrapper.vm.addMultipleSatisfiedRules();
      await wrapper.vm.$nextTick();

      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 2, 1);
      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 3, 1);
    });

    it("clearSelectedRules resets selection and search text", () => {
      wrapper = createWrapper();
      wrapper.vm.selectedSatisfiesRuleIds = [2, 3];
      wrapper.vm.satisfiesSearchText = "test search";

      wrapper.vm.clearSelectedRules();

      expect(wrapper.vm.selectedSatisfiesRuleIds).toEqual([]);
      expect(wrapper.vm.satisfiesSearchText).toBe("");
    });

    it("shows correct count of selected rules", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedSatisfiesRuleIds.length).toBe(0);

      wrapper.vm.selectedSatisfiesRuleIds = [2, 3];
      expect(wrapper.vm.selectedSatisfiesRuleIds.length).toBe(2);
    });
  });
});
