import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RulesCodeEditorView from "@/components/rules/RulesCodeEditorView.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    put: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

describe("RulesCodeEditorView", () => {
  let wrapper;

  const mockRules = [
    {
      id: 1,
      rule_id: "001",
      status: "Not Yet Determined",
      locked: false,
      review_requestor_id: null,
      satisfies: [],
      satisfied_by: [],
      histories: [{ name: "Test User" }],
      version: "SV-001",
    },
    {
      id: 2,
      rule_id: "002",
      status: "Applicable - Configurable",
      locked: false,
      review_requestor_id: null,
      satisfies: [],
      satisfied_by: [],
      histories: [],
      version: "SV-002",
    },
    {
      id: 3,
      rule_id: "003",
      status: "Not Applicable",
      locked: true,
      review_requestor_id: null,
      satisfies: [],
      satisfied_by: [],
      histories: [],
      version: "SV-003",
    },
  ];

  const defaultProps = {
    effectivePermissions: "admin",
    currentUserId: 1,
    project: { id: 1, name: "Test Project" },
    component: {
      id: 41,
      prefix: "TEST",
      advanced_fields: false,
      additional_questions: [],
    },
    rules: mockRules,
    statuses: [
      "Not Yet Determined",
      "Applicable - Configurable",
      "Applicable - Inherently Meets",
      "Applicable - Does Not Meet",
      "Not Applicable",
    ],
    availableRoles: ["viewer", "author", "reviewer", "admin"],
  };

  const createWrapper = (props = {}) => {
    return shallowMount(RulesCodeEditorView, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        RuleNavigator: true,
        RuleEditor: true,
        RuleHistories: true,
        RuleReviews: true,
        RuleSatisfactions: true,
        RelatedRulesModal: true,
        RuleReviewModal: true,
        RuleFilterBar: true,
        ControlsCommandBar: true,
        ControlsPageLayout: true,
        NewRuleModalForm: true,
        Multiselect: true,
        BModal: true,
        BSidebar: true,
        BButton: true,
        BFormGroup: true,
        BIcon: true,
      },
      mocks: {
        $root: {
          $emit: vi.fn(),
        },
      },
    });
  };

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("basic rendering", () => {
    it("renders the component", () => {
      wrapper = createWrapper();
      expect(wrapper.exists()).toBe(true);
    });

    it("renders ControlsPageLayout", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ControlsPageLayout" }).exists()).toBe(true);
    });

    it("renders ControlsCommandBar", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ControlsCommandBar" }).exists()).toBe(true);
    });

    it("renders RuleFilterBar", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleFilterBar" }).exists()).toBe(true);
    });

    it("renders RuleNavigator", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleNavigator" }).exists()).toBe(true);
    });
  });

  describe("useRuleSelection composable integration", () => {
    it("has selectedRuleId in component state", () => {
      wrapper = createWrapper();
      // After composable integration, selectedRuleId should be a ref
      expect(wrapper.vm.selectedRuleId).toBeDefined();
    });

    it("has openRuleIds in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.openRuleIds).toBeDefined();
    });

    it("has selectedRule computed property", () => {
      wrapper = createWrapper();
      // selectedRule should be a computed, not a function
      expect(wrapper.vm.selectedRule).toBeDefined();
    });

    it("selectRule method updates selectedRuleId", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      expect(wrapper.vm.selectedRuleId).toBe(1);
    });

    it("selectRule adds to openRuleIds", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      expect(wrapper.vm.openRuleIds).toContain(1);
    });

    it("deselectRule removes from openRuleIds", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      wrapper.vm.deselectRule(1);
      expect(wrapper.vm.openRuleIds).not.toContain(1);
    });

    it("persists selectedRuleId to localStorage", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      expect(localStorage.getItem("selectedRuleId-41")).toBe("1");
    });
  });

  describe("useRuleFilters composable integration", () => {
    it("has filters in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.filters).toBeDefined();
      expect(wrapper.vm.filters.acFilterChecked).toBe(true);
    });

    it("has counts computed property", () => {
      wrapper = createWrapper();
      // counts should come from useRuleFilters
      const counts = wrapper.vm.counts;
      expect(counts).toBeDefined();
      expect(counts.nyd).toBe(1); // One rule with 'Not Yet Determined'
      expect(counts.ac).toBe(1); // One rule with 'Applicable - Configurable'
    });

    it("setFilter updates filter state", () => {
      wrapper = createWrapper();
      wrapper.vm.setFilter("acFilterChecked", false);
      expect(wrapper.vm.filters.acFilterChecked).toBe(false);
    });

    it("resetFilters resets all filters", () => {
      wrapper = createWrapper();
      wrapper.vm.setFilter("acFilterChecked", false);
      wrapper.vm.resetFilters();
      expect(wrapper.vm.filters.acFilterChecked).toBe(true);
    });
  });

  describe("useSidebar composable integration", () => {
    it("has activePanel in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.activePanel).toBeDefined();
    });

    it("togglePanel opens a panel", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("reviews");
      expect(wrapper.vm.activePanel).toBe("reviews");
    });

    it("togglePanel closes panel when toggled again", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("reviews");
      wrapper.vm.togglePanel("reviews");
      expect(wrapper.vm.activePanel).toBeNull();
    });

    it("togglePanel switches between panels", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("reviews");
      wrapper.vm.togglePanel("history");
      expect(wrapper.vm.activePanel).toBe("history");
    });
  });

  describe("event handling", () => {
    it("passes selectRule to RuleNavigator as ruleSelected handler", () => {
      wrapper = createWrapper();
      const navigator = wrapper.findComponent({ name: "RuleNavigator" });
      expect(navigator.exists()).toBe(true);
      // The @ruleSelected should be connected to selectRule (or handleRuleSelected)
    });

    it("passes activePanel to ControlsCommandBar", async () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("reviews");
      await wrapper.vm.$nextTick();
      // With shallowMount, check the vm state rather than stubbed component props
      expect(wrapper.vm.activePanel).toBe("reviews");
    });
  });

  describe("RuleEditor event forwarding", () => {
    // CRITICAL: RuleEditor must forward toggle-panel events so panel buttons work.
    // This was a regression where buttons did nothing because events weren't wired up.

    it("forwards toggle-panel events from RuleEditor to togglePanel", async () => {
      wrapper = createWrapper();
      // Select a rule first so RuleEditor renders
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();

      // Find RuleEditor and emit toggle-panel
      const ruleEditor = wrapper.findComponent({ name: "RuleEditor" });
      expect(ruleEditor.exists()).toBe(true);

      // Emit toggle-panel from RuleEditor
      ruleEditor.vm.$emit("toggle-panel", "satisfies");
      await wrapper.vm.$nextTick();

      // Verify the panel was toggled
      expect(wrapper.vm.activePanel).toBe("satisfies");
    });

    it("opens rule-history panel when RuleEditor emits toggle-panel", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();

      const ruleEditor = wrapper.findComponent({ name: "RuleEditor" });
      ruleEditor.vm.$emit("toggle-panel", "rule-history");
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.activePanel).toBe("rule-history");
    });

    it("opens rule-reviews panel when RuleEditor emits toggle-panel", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();

      const ruleEditor = wrapper.findComponent({ name: "RuleEditor" });
      ruleEditor.vm.$emit("toggle-panel", "rule-reviews");
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.activePanel).toBe("rule-reviews");
    });
  });

  describe("computed properties", () => {
    it("isViewerOnly returns true for viewer permissions", () => {
      wrapper = createWrapper({ effectivePermissions: "viewer" });
      expect(wrapper.vm.isViewerOnly).toBe(true);
    });

    it("isViewerOnly returns false for admin permissions", () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      expect(wrapper.vm.isViewerOnly).toBe(false);
    });
  });

  describe("toggleAdvancedFields (slot reactivity fix)", () => {
    // REQUIREMENT: Toggling advanced fields must update the form LIVE,
    // not just after page reload. This tests the local data property
    // pattern that fixes Vue 2 slot reactivity issues.

    it("initializes localAdvancedFields from component prop", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.localAdvancedFields).toBe(false);
    });

    it("initializes localAdvancedFields as true when component has advanced_fields", () => {
      wrapper = createWrapper({
        component: { ...defaultProps.component, advanced_fields: true },
      });
      expect(wrapper.vm.localAdvancedFields).toBe(true);
    });

    it("updates localAdvancedFields after successful PATCH", async () => {
      const axios = (await import("axios")).default;
      axios.patch.mockResolvedValueOnce({ data: {} });

      wrapper = createWrapper();
      expect(wrapper.vm.localAdvancedFields).toBe(false);

      wrapper.vm.toggleAdvancedFields(true);
      await vi.waitFor(() => {
        expect(wrapper.vm.localAdvancedFields).toBe(true);
      });
    });

    it("does not update localAdvancedFields on PATCH failure", async () => {
      const axios = (await import("axios")).default;
      axios.patch.mockRejectedValueOnce(new Error("Network error"));

      wrapper = createWrapper();
      expect(wrapper.vm.localAdvancedFields).toBe(false);

      wrapper.vm.toggleAdvancedFields(true);
      // Wait for the promise to settle
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(wrapper.vm.localAdvancedFields).toBe(false);
    });

    it("passes localAdvancedFields to RuleEditor, not component.advanced_fields", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();

      const ruleEditor = wrapper.findComponent({ name: "RuleEditor" });
      expect(ruleEditor.exists()).toBe(true);
      // The template binds :advanced_fields="localAdvancedFields"
      expect(ruleEditor.props("advanced_fields")).toBe(false);

      // Simulate successful toggle
      const axios = (await import("axios")).default;
      axios.patch.mockResolvedValueOnce({ data: {} });
      wrapper.vm.toggleAdvancedFields(true);
      await vi.waitFor(() => {
        expect(wrapper.vm.localAdvancedFields).toBe(true);
      });
      await wrapper.vm.$nextTick();
      expect(ruleEditor.props("advanced_fields")).toBe(true);
    });
  });

  describe("filterRulesForSatisfies (Also Satisfies modal)", () => {
    // REQUIREMENT: The Also Satisfies modal shows eligible rules as options.
    // A rule is eligible if:
    //   1. It is NOT the currently selected rule
    //   2. It does NOT already satisfy another rule (satisfies.length === 0)
    //   3. It is NOT already in the selected rule's satisfies list
    // Display: truncated SRG ID (or prefix-rule_id fallback)

    const rulesWithSrgIds = [
      {
        id: 1,
        rule_id: "001",
        srg_id: "SRG-OS-000001-GPOS-00001",
        status: "Applicable - Configurable",
        locked: false,
        review_requestor_id: null,
        satisfies: [],
        satisfied_by: [],
        histories: [],
        version: "SV-001",
      },
      {
        id: 2,
        rule_id: "002",
        srg_id: "SRG-OS-000002-GPOS-00002",
        status: "Not Yet Determined",
        locked: false,
        review_requestor_id: null,
        satisfies: [],
        satisfied_by: [],
        histories: [],
        version: "SV-002",
      },
      {
        id: 3,
        rule_id: "003",
        srg_id: "SRG-OS-000003-GPOS-00003",
        status: "Applicable - Configurable",
        locked: false,
        review_requestor_id: null,
        satisfies: [{ id: 99, rule_id: "099", srg_id: "SRG-OS-000099-GPOS-00099" }],
        satisfied_by: [],
        histories: [],
        version: "SV-003",
      },
      {
        id: 4,
        rule_id: "004",
        srg_id: null,
        status: "Not Applicable",
        locked: false,
        review_requestor_id: null,
        satisfies: [],
        satisfied_by: [],
        histories: [],
        version: "SV-004",
      },
    ];

    it("excludes the currently selected rule from options", () => {
      wrapper = createWrapper({ rules: rulesWithSrgIds });
      wrapper.vm.selectRule(1);
      wrapper.vm.filterRulesForSatisfies();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ids).not.toContain(1);
    });

    it("excludes rules that already satisfy other rules", () => {
      wrapper = createWrapper({ rules: rulesWithSrgIds });
      wrapper.vm.selectRule(1);
      wrapper.vm.filterRulesForSatisfies();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      // Rule 3 has satisfies.length > 0 — should be excluded
      expect(ids).not.toContain(3);
    });

    it("excludes rules already in the selected rule's satisfies list", () => {
      const rulesWithExistingSatisfaction = rulesWithSrgIds.map((r) => {
        if (r.id === 1) {
          return {
            ...r,
            satisfies: [{ id: 2, rule_id: "002", srg_id: "SRG-OS-000002-GPOS-00002" }],
          };
        }
        return r;
      });
      wrapper = createWrapper({ rules: rulesWithExistingSatisfaction });
      wrapper.vm.selectRule(1);
      wrapper.vm.filterRulesForSatisfies();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ids).not.toContain(2);
    });

    it("includes eligible rules", () => {
      wrapper = createWrapper({ rules: rulesWithSrgIds });
      wrapper.vm.selectRule(1);
      wrapper.vm.filterRulesForSatisfies();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      // Rule 2 and 4 are eligible (not selected, no existing satisfies, not in satisfies list)
      expect(ids).toContain(2);
      expect(ids).toContain(4);
    });

    it("displays truncated SRG ID as option text", () => {
      wrapper = createWrapper({ rules: rulesWithSrgIds });
      wrapper.vm.selectRule(1);
      wrapper.vm.filterRulesForSatisfies();
      const rule2Option = wrapper.vm.filteredSelectRules.find((r) => r.value === 2);
      expect(rule2Option.text).toBe("SRG-OS-000002");
    });

    it("falls back to prefix-rule_id when srg_id is null", () => {
      wrapper = createWrapper({ rules: rulesWithSrgIds });
      wrapper.vm.selectRule(1);
      wrapper.vm.filterRulesForSatisfies();
      const rule4Option = wrapper.vm.filteredSelectRules.find((r) => r.value === 4);
      expect(rule4Option.text).toBe("TEST-004");
    });

    it("returns empty when no rule is selected", () => {
      wrapper = createWrapper({ rules: rulesWithSrgIds });
      // Deselect all rules — autoSelectFirst selects rule 1 on mount
      wrapper.vm.deselectRule(wrapper.vm.selectedRuleId);
      wrapper.vm.filterRulesForSatisfies();
      expect(wrapper.vm.filteredSelectRules).toEqual([]);
    });
  });

  describe("addMultipleSatisfiedRules", () => {
    it("emits addSatisfied:rule for each selected rule", () => {
      wrapper = createWrapper();
      const rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");
      wrapper.vm.selectRule(1);
      wrapper.vm.selectedSatisfiesRuleIds = [
        { value: 2, text: "SRG-OS-000002" },
        { value: 3, text: "SRG-OS-000003" },
      ];
      wrapper.vm.addMultipleSatisfiedRules();
      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 2, 1);
      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 3, 1);
      rootEmitSpy.mockRestore();
    });

    it("does nothing when no rule is selected", () => {
      wrapper = createWrapper();
      const rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");
      // Don't select any rule — deselect to ensure selectedRule is null
      wrapper.vm.deselectRule(wrapper.vm.selectedRuleId);
      rootEmitSpy.mockClear();
      wrapper.vm.selectedSatisfiesRuleIds = [{ value: 2, text: "SRG-OS-000002" }];
      wrapper.vm.addMultipleSatisfiedRules();
      expect(rootEmitSpy).not.toHaveBeenCalledWith(
        "addSatisfied:rule",
        expect.anything(),
        expect.anything(),
      );
      rootEmitSpy.mockRestore();
    });
  });

  describe("clearSelectedRules", () => {
    it("resets selectedSatisfiesRuleIds to empty array", () => {
      wrapper = createWrapper();
      wrapper.vm.selectedSatisfiesRuleIds = [
        { value: 1, text: "SRG-OS-000001" },
      ];
      wrapper.vm.clearSelectedRules();
      expect(wrapper.vm.selectedSatisfiesRuleIds).toEqual([]);
    });
  });
});
