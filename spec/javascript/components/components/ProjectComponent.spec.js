import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import ProjectComponent from "@/components/components/ProjectComponent.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
  },
}));

describe("ProjectComponent", () => {
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
      reviews: [],
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
      reviews: [],
      version: "SV-002",
    },
  ];

  const defaultProps = {
    effective_permissions: "admin",
    current_user_id: 1,
    project: { id: 1, name: "Test Project" },
    initialComponentState: {
      id: 41,
      name: "Test Component",
      prefix: "TEST",
      title: "Test Title",
      description: "Test Description",
      version: "1.0",
      release: "R1",
      released: false,
      releasable: true,
      advanced_fields: false,
      additional_questions: [],
      admin_name: "Admin",
      admin_email: "admin@test.com",
      metadata: {},
      rules: mockRules,
      memberships: [],
      memberships_count: 0,
      inherited_memberships: [],
      available_members: [],
      histories: [],
      reviews: [],
    },
    statuses: [
      "Not Yet Determined",
      "Applicable - Configurable",
      "Applicable - Inherently Meets",
      "Applicable - Does Not Meet",
      "Not Applicable",
    ],
    available_roles: ["admin", "author", "viewer"],
  };

  const createWrapper = (props = {}) => {
    return shallowMount(ProjectComponent, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        ControlsPageLayout: true,
        ControlsCommandBar: true,
        ControlsSidepanels: true,
        RuleNavigator: true,
        RuleEditor: true,
        RuleSatisfactions: true,
        RuleReviews: true,
        RuleHistories: true,
        RelatedRulesModal: true,
        MembersModal: true,
        BSidebar: true,
        BModal: true,
        BIcon: true,
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

    it("renders RuleNavigator", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleNavigator" }).exists()).toBe(true);
    });
  });

  describe("useRuleSelection composable integration", () => {
    it("has selectedRuleId in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedRuleId).toBeDefined();
    });

    it("has openRuleIds in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.openRuleIds).toBeDefined();
    });

    it("has selectedRule computed property", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedRule).toBeDefined();
    });

    it("selectRule method updates selectedRuleId", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      expect(wrapper.vm.selectedRuleId).toBe(1);
    });

    it("persists selectedRuleId to localStorage", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      expect(localStorage.getItem("selectedRuleId-41")).toBe("1");
    });
  });

  describe("useSidebar composable integration", () => {
    it("has activePanel in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.activePanel).toBeDefined();
    });

    it("togglePanel opens a panel", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("details");
      expect(wrapper.vm.activePanel).toBe("details");
    });

    it("togglePanel closes panel when toggled again", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("details");
      wrapper.vm.togglePanel("details");
      expect(wrapper.vm.activePanel).toBeNull();
    });
  });

  describe("component panels", () => {
    it("has details slideover", () => {
      wrapper = createWrapper();
      // Component should have slideover for details
      expect(wrapper.vm.componentPanels).toContain("details");
    });

    it("has metadata slideover", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.componentPanels).toContain("metadata");
    });

    it("has questions slideover", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.componentPanels).toContain("questions");
    });

    it("has comp-history slideover", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.componentPanels).toContain("comp-history");
    });

    // comp-reviews retired in PR #717 — slideover replaced by the
    // full-page /components/:id/triage route. The Triage button on
    // the command bar links there directly.
    it("does NOT register a comp-reviews slideover panel anymore", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.componentPanels).not.toContain("comp-reviews");
    });
  });

  describe("rule panels (enabled when rule selected)", () => {
    // REQUIREMENT: Rule panels use namespaced IDs to avoid collision with component panels
    // 'rule-reviews' instead of 'reviews', 'rule-history' instead of 'history'
    it("has satisfies slideover", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.rulePanels).toContain("satisfies");
    });

    it("has rule-reviews slideover", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.rulePanels).toContain("rule-reviews");
    });

    it("has rule-history slideover", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.rulePanels).toContain("rule-history");
    });
  });

  describe("no tabs or right sidebar", () => {
    it("does not have tabs", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BTabs" }).exists()).toBe(false);
    });

    it("uses ControlsSidepanels for slideovers", () => {
      wrapper = createWrapper();
      // Sidebars are now in the shared ControlsSidepanels component
      const controlsSidepanels = wrapper.findComponent({ name: "ControlsSidepanels" });
      expect(controlsSidepanels.exists()).toBe(true);
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

  describe("refreshComponent", () => {
    // REQUIREMENT: When component details are updated via modal, the sidepanel
    // should reactively display the new data WITHOUT a full page reload.
    // The refreshComponent method should fetch updated data and update
    // the component properties in-place for Vue reactivity.

    it("fetches component data as JSON", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper();

      // Call refreshComponent
      wrapper.vm.refreshComponent();

      // Verify axios.get was called with .json extension
      expect(axios.get).toHaveBeenCalledWith("/components/41.json");
    });

    it("updates component properties in-place on successful fetch", async () => {
      const axios = (await import("axios")).default;
      const updatedData = {
        id: 41,
        name: "Updated Component Name",
        title: "Updated Title",
        description: "Updated Description",
      };
      axios.get.mockResolvedValueOnce({ data: updatedData });

      wrapper = createWrapper();

      // Call refreshComponent and wait for promise
      await wrapper.vm.refreshComponent();

      // Wait for Vue to process updates
      await wrapper.vm.$nextTick();

      // Component properties should be updated in-place
      expect(wrapper.vm.component.name).toBe("Updated Component Name");
      expect(wrapper.vm.component.title).toBe("Updated Title");
    });

    it("does NOT reload the page", async () => {
      const axios = (await import("axios")).default;
      axios.get.mockResolvedValueOnce({ data: { id: 41, name: "Test" } });

      // Mock location.reload to track if it's called
      const originalReload = globalThis.location.reload;
      const mockReload = vi.fn();
      delete globalThis.location;
      globalThis.location = { reload: mockReload };

      wrapper = createWrapper();
      await wrapper.vm.refreshComponent();
      await wrapper.vm.$nextTick();

      // CRITICAL: Should NOT call location.reload
      expect(mockReload).not.toHaveBeenCalled();

      // Restore
      globalThis.location.reload = originalReload;
    });
  });

  // ==========================================================================
  // PR-717 Step 5: per-component editor Download surface. Mounts ExportModal
  // and listens for the `download` event from ControlsCommandBar.
  // ==========================================================================
  describe("Download flow", () => {
    it("mounts ExportModal as a child", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ExportModal" }).exists()).toBe(true);
    });

    it("opens the export modal when ControlsCommandBar emits download", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showExportModal).toBe(false);
      const commandBar = wrapper.findComponent({ name: "ControlsCommandBar" });
      commandBar.vm.$emit("download");
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.showExportModal).toBe(true);
    });

    it("closes the export modal when modal emits cancel", async () => {
      wrapper = createWrapper();
      wrapper.vm.showExportModal = true;
      await wrapper.vm.$nextTick();
      const modal = wrapper.findComponent({ name: "ExportModal" });
      modal.vm.$emit("cancel");
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.showExportModal).toBe(false);
    });

    it("executeExport hits the project export route with the component_id", () => {
      wrapper = createWrapper();
      axios.get.mockClear();
      wrapper.vm.executeExport({
        type: "csv",
        mode: "working_copy",
        componentIds: [41],
      });
      expect(axios.get).toHaveBeenCalledTimes(1);
      const calledUrl = axios.get.mock.calls[0][0];
      expect(calledUrl).toContain("/projects/1/export/csv?component_ids=41");
      expect(calledUrl).toContain("mode=working_copy");
    });

    it("passes the available Working Copy / Vendor Submission / Publish Draft / Backup modes to ExportModal", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "ExportModal" });
      expect(modal.props("availableModes")).toEqual([
        "working_copy",
        "vendor_submission",
        "published_stig",
        "backup",
      ]);
    });

    it("passes the single component to ExportModal with hideComponentSelection=true", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "ExportModal" });
      expect(modal.props("hideComponentSelection")).toBe(true);
      expect(modal.props("components").length).toBe(1);
      expect(modal.props("components")[0].id).toBe(41);
    });
  });
});
