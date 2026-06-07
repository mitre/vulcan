import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createPinia } from "pinia";
import { createTestRouter } from "@test/support/routerTestHelper";
import ProjectComponent from "@/components/components/ProjectComponent.vue";
import { getComponent, patchComponent } from "@/api/componentsApi";
import { getRule } from "@/api/rulesApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  getComponent: vi.fn(() => Promise.resolve({ data: {} })),
  patchComponent: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/api/rulesApi", () => ({
  getRule: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/api/projectsApi", () => ({
  exportProjectData: vi.fn(() => Promise.resolve("/projects/1/export/csv?component_ids=41")),
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
      checks_attributes: [],
      disa_rule_descriptions_attributes: [],
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
      checks_attributes: [],
      disa_rule_descriptions_attributes: [],
    },
  ];

  const defaultProps = {
    current_user_id: 1,
    project: { id: 1, name: "Test Project" },
    initialComponentState: {
      effective_permissions: "admin",
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
    const router = createTestRouter([
      { path: "/", name: "editor-root" },
      { path: "/rules/:ruleId", name: "rule", props: true },
    ]);
    return shallowMount(ProjectComponent, {
      localVue,
      pinia: createPinia(),
      router,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        ControlsPageLayout: true,
        ControlsCommandBar: true,
        ControlsSidepanels: true,
        RuleSearchBar: true,
        RuleList: true,
        ActiveFilterPills: true,
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

    it("renders RuleSearchBar in sidebar header (pinned)", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleSearchBar" }).exists()).toBe(true);
    });

    it("renders ActiveFilterPills in sidebar header (pinned)", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ActiveFilterPills" }).exists()).toBe(true);
    });

    it("renders RuleList in sidebar body (scrollable)", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleList" }).exists()).toBe(true);
    });

    it("does NOT render RuleNavigator (replaced by composable)", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleNavigator" }).exists()).toBe(false);
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

      wrapper = createWrapper();

      // Call refreshComponent
      wrapper.vm.refreshComponent();

      expect(getComponent).toHaveBeenCalledWith(41);
    });

    it("updates component properties in-place on successful fetch", async () => {

      const updatedData = {
        id: 41,
        name: "Updated Component Name",
        title: "Updated Title",
        description: "Updated Description",
      };
      getComponent.mockResolvedValueOnce({ data: updatedData });

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

      getComponent.mockResolvedValueOnce({ data: { id: 41, name: "Test" } });

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
  // Chrome condensation: breadcrumbs, banner chip, filter toggle
  // ==========================================================================
  describe("chrome condensation", () => {
    it("root element has vulcan-editor-layout class for flex chain continuity", () => {
      wrapper = createWrapper();
      expect(wrapper.classes()).toContain("vulcan-editor-layout");
    });

    it("does NOT render a standalone b-breadcrumb row", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(false);
    });

    it("passes breadcrumbs to ControlsCommandBar", () => {
      wrapper = createWrapper();
      const commandBar = wrapper.findComponent({ name: "ControlsCommandBar" });
      const breadcrumbs = commandBar.props("breadcrumbs");
      expect(breadcrumbs).toBeDefined();
      expect(breadcrumbs.length).toBe(3);
      expect(breadcrumbs[0].text).toBe("Projects");
      expect(breadcrumbs[0].href).toBe("/projects");
      expect(breadcrumbs[2].active).toBe(true);
    });

    it("does NOT render a standalone CommentPeriodBanner", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "CommentPeriodBanner" }).exists()).toBe(false);
    });

    it("passes showFilterToggle=true to ControlsCommandBar", () => {
      wrapper = createWrapper();
      const commandBar = wrapper.findComponent({ name: "ControlsCommandBar" });
      expect(commandBar.props("showFilterToggle")).toBe(true);
    });

    it("filter bar is hidden by default", () => {
      wrapper = createWrapper();
      const layout = wrapper.findComponent({ name: "ControlsPageLayout" });
      expect(layout.props("showFilterBar")).toBe(false);
    });

    it("toggles filter bar visibility when command bar emits toggle-filter-bar", async () => {
      wrapper = createWrapper();
      const commandBar = wrapper.findComponent({ name: "ControlsCommandBar" });
      commandBar.vm.$emit("toggle-filter-bar");
      await wrapper.vm.$nextTick();
      const layout = wrapper.findComponent({ name: "ControlsPageLayout" });
      expect(layout.props("showFilterBar")).toBe(true);
    });

    it("persists filter bar visibility to localStorage", async () => {
      wrapper = createWrapper();
      const commandBar = wrapper.findComponent({ name: "ControlsCommandBar" });
      commandBar.vm.$emit("toggle-filter-bar");
      await wrapper.vm.$nextTick();
      expect(localStorage.getItem("filterBarVisible-41")).toBe("true");
    });

    it("restores filter bar visibility from localStorage", () => {
      localStorage.setItem("filterBarVisible-41", "true");
      wrapper = createWrapper();
      const layout = wrapper.findComponent({ name: "ControlsPageLayout" });
      expect(layout.props("showFilterBar")).toBe(true);
    });

    it("has openCommentsPanel method for command bar event forwarding", () => {
      wrapper = createWrapper();
      expect(typeof wrapper.vm.openCommentsPanel).toBe("function");
    });

    it("clearAllFilters resets both filter bar and nav filters", () => {
      wrapper = createWrapper();
      expect(typeof wrapper.vm.clearAllFilters).toBe("function");
    });
  });

  // ==========================================================================
  // per-component editor Download surface. Mounts ExportModal
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

    it("executeExport calls exportProjectData with project id, type, and options", async () => {
      const { exportProjectData } = await import("@/api/projectsApi");

      wrapper = createWrapper();
      wrapper.vm.executeExport({
        type: "csv",
        mode: "working_copy",
        componentIds: [41],
      });

      expect(exportProjectData).toHaveBeenCalledWith(1, "csv", {
        componentIds: [41],
        mode: "working_copy",
        includeSrg: undefined,
        includeMemberships: undefined,
        excludeSatisfiedBy: undefined,
      });
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

  describe("permissions via provide", () => {
    it("reads effective_permissions from initialComponentState", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.effective_permissions).toBe("admin");
    });

    it("derives viewer permissions from initialComponentState", () => {
      wrapper = createWrapper({
        initialComponentState: {
          ...defaultProps.initialComponentState,
          effective_permissions: "viewer",
        },
      });
      expect(wrapper.vm.effective_permissions).toBe("viewer");
    });

    it("defaults to null when initialComponentState has no permissions", () => {
      const stateWithout = { ...defaultProps.initialComponentState };
      delete stateWithout.effective_permissions;
      wrapper = createWrapper({ initialComponentState: stateWithout });
      expect(wrapper.vm.effective_permissions).toBeNull();
    });
  });
});
