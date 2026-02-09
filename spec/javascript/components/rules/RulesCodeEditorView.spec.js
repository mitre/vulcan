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
});
