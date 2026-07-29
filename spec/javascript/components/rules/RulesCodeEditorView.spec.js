import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue, flushPromises } from "@test/testHelper";
import { createPinia, setActivePinia } from "pinia";
import { createTestRouter } from "@test/support/routerTestHelper";
import { useRuleSelectionStore } from "@/stores/ruleSelection";
import RulesCodeEditorView from "@/components/rules/RulesCodeEditorView.vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/rulesApi", () => ({
  updateRule: vi.fn(() => Promise.resolve({ data: {} })),
  updateSectionLocks: vi.fn(() => Promise.resolve({ data: {} })),
  getRelocations: vi.fn(() => Promise.resolve({ data: [] })),
  getRelocationDestinations: vi.fn(() => Promise.resolve({ data: [] })),
  markRelocation: vi.fn(() => Promise.resolve({ data: {} })),
  unmarkRelocation: vi.fn(() => Promise.resolve({ data: {} })),
  dryRunRelocation: vi.fn(() => Promise.resolve({ data: {} })),
  acceptRelocation: vi.fn(() => Promise.resolve({ data: {} })),
  declineRelocation: vi.fn(() => Promise.resolve({ data: {} })),
}));
import {
  getRelocations,
  getRelocationDestinations,
  dryRunRelocation,
  acceptRelocation,
  declineRelocation,
} from "@/api/rulesApi";

vi.mock("@/api/reviewsApi", () => ({
  createRuleReview: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/api/componentsApi", () => ({
  getComponent: vi.fn(() => Promise.resolve({ data: {} })),
  patchComponent: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/composables/usePermissions", { spy: true });
vi.mock("@/composables/useReplyComposer", { spy: true });
import { usePermissions } from "@/composables/usePermissions";
import { useReplyComposer } from "@/composables/useReplyComposer";

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
      version: "SV-002",
      checks_attributes: [],
      disa_rule_descriptions_attributes: [],
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
      checks_attributes: [],
      disa_rule_descriptions_attributes: [],
    },
  ];

  const defaultProps = {
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

  let pinia;

  const createWrapper = (props = {}, permissions = "admin") => {
    pinia = createPinia();
    setActivePinia(pinia);
    const router = createTestRouter([
      { path: "/", name: "editor-root" },
      { path: "/rules/:ruleId", name: "rule", props: true },
    ]);
    return shallowMount(RulesCodeEditorView, {
      localVue,
      pinia,
      router,
      // Permissions arrive via provide/inject (usePermissions) — the page
      // root (Rules.vue) provides; this view injects.
      provide: { effectivePermissions: permissions },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
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
        AlsoSatisfiesModal: true,
        RuleSearchBar: true,
        RuleList: true,
        ActiveFilterPills: true,
        Multiselect: true,
        BModal: true,
        BSidebar: true,
        BButton: true,
        BFormGroup: true,
        BIcon: true,
      },
      // NOTE: do not try to mock $root here — VTU cannot replace the real
      // $root; use vi.spyOn(wrapper.vm.$root, "$emit") in tests instead.
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

    it("renders RuleSearchBar (sidebar header)", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "RuleSearchBar" }).exists()).toBe(true);
    });
  });

  describe("useRuleSelection composable integration", () => {
    it("has selectedRuleId in component state", () => {
      wrapper = createWrapper();
      // After composable integration, selectedRuleId should be a ref
      expect(wrapper.vm.selectedRuleId).toBeDefined();
    });

    it("has openRuleIds available via the store", () => {
      wrapper = createWrapper();
      const store = useRuleSelectionStore();
      expect(store.openRuleIds).toBeDefined();
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

    it("selectRule adds to openRuleIds in the store", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      const store = useRuleSelectionStore();
      expect(store.openRuleIds).toContain(1);
    });

    it("deselectRule removes from openRuleIds in the store", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      wrapper.vm.deselectRule(1);
      const store = useRuleSelectionStore();
      expect(store.openRuleIds).not.toContain(1);
    });

    it("persists selectedRuleId to localStorage", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      expect(localStorage.getItem("selectedRuleId-41")).toBe("1");
    });

    // REGRESSION: a persisted selection can reference a requirement that
    // no longer exists — e.g. relocated away since the last visit. The
    // stale id must be CLEARED (fall back to the first rule), never
    // fetched: the old behavior fired refresh:rule with the dead id and
    // 404ed on every subsequent visit.
    it("clears a stale persisted selection instead of fetching the missing rule", async () => {
      localStorage.setItem("selectedRuleId-41", "999");
      wrapper = createWrapper();
      const rootEmit = vi.spyOn(wrapper.vm.$root, "$emit");
      await new Promise((resolve) => setTimeout(resolve, 5));

      expect(rootEmit).not.toHaveBeenCalledWith("refresh:rule", 999);
      expect(wrapper.vm.selectedRuleId).toBe(1);
    });
  });

  describe("useRuleFilters composable integration", () => {
    it("has filters in component state (vocabulary-keyed statusFilters)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.filters).toBeDefined();
      expect(wrapper.vm.filters.statusFilters["Applicable - Configurable"]).toBe(false);
    });

    it("has counts computed property keyed by status value", () => {
      wrapper = createWrapper();
      // counts should come from useRuleFilters
      const counts = wrapper.vm.counts;
      expect(counts).toBeDefined();
      expect(counts.statusCounts["Not Yet Determined"]).toBe(1);
      expect(counts.statusCounts["Applicable - Configurable"]).toBe(1);
    });

    it("setFilter updates filter state by status value", () => {
      wrapper = createWrapper();
      wrapper.vm.setFilter("Applicable - Configurable", true);
      expect(wrapper.vm.filters.statusFilters["Applicable - Configurable"]).toBe(true);
    });

    it("resetFilters resets all filters to defaults (all unchecked)", () => {
      wrapper = createWrapper();
      wrapper.vm.setFilter("Applicable - Configurable", true);
      wrapper.vm.resetFilters();
      expect(wrapper.vm.filters.statusFilters["Applicable - Configurable"]).toBe(false);
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
    it("has nav composable state flattened into component", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.navFilters).toBeDefined();
      expect(wrapper.vm.navFilteredRules).toBeDefined();
      expect(wrapper.vm.navHasActiveFilters).toBeDefined();
    });

    it("passes activePanel to ControlsCommandBar", async () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("reviews");
      await wrapper.vm.$nextTick();
      // With shallowMount, check the vm state rather than stubbed component props
      expect(wrapper.vm.activePanel).toBe("reviews");
    });
  });

  describe("adjudicating relocation proposals (receiver side)", () => {
    // REQUIREMENT: accept-request runs the dry-run and shows the preview
    // modal; nothing lands until the modal's explicit confirm, which
    // calls accept and materializes the landed row via the established
    // per-rule refresh event. Decline collects the rationale through its
    // own modal.
    const MARKER = {
      id: 7,
      source_rule_id: 91,
      component_id: 9,
      target_technology_token: "TEST",
      source_displayed_name: "WALK-00-000012",
      declined_at: null,
    };
    const PREVIEW = {
      valid: true,
      errors: [],
      source_displayed_name: "WALK-00-000012",
      target_component_name: "Test Component",
      would_create: { title: "Incoming", status: "Applicable", rule_id: "000004" },
      would_tombstone_source: true,
    };

    const srgWrapper = () =>
      createWrapper({ component: { ...defaultProps.component, document_type: "srg" } });

    it("runs the dry-run and opens the preview modal on accept-request", async () => {
      dryRunRelocation.mockResolvedValue({ data: PREVIEW });
      wrapper = srgWrapper();

      wrapper.findComponent({ name: "RelocationBacklogPanel" }).vm.$emit("accept-request", MARKER);
      await wrapper.vm.$nextTick();
      await wrapper.vm.$nextTick();

      expect(dryRunRelocation).toHaveBeenCalledWith(7, 41);
      const modal = wrapper.findComponent({ name: "AcceptRelocationModal" });
      expect(modal.props("visible")).toBe(true);
      expect(modal.props("preview")).toEqual(PREVIEW);
    });

    it("accepts only on explicit confirm and materializes the landed row", async () => {
      dryRunRelocation.mockResolvedValue({ data: PREVIEW });
      acceptRelocation.mockResolvedValue({ data: { toast: {}, landed_rule_id: 555 } });
      wrapper = srgWrapper();
      const rootEmit = vi.spyOn(wrapper.vm.$root, "$emit");

      wrapper.findComponent({ name: "RelocationBacklogPanel" }).vm.$emit("accept-request", MARKER);
      await wrapper.vm.$nextTick();
      expect(acceptRelocation).not.toHaveBeenCalled();

      wrapper.findComponent({ name: "AcceptRelocationModal" }).vm.$emit("accept");
      await flushPromises(wrapper);

      expect(acceptRelocation).toHaveBeenCalledWith(7, 41);
      expect(rootEmit).toHaveBeenCalledWith("refresh:rule", 555);
      expect(wrapper.findComponent({ name: "AcceptRelocationModal" }).props("visible")).toBe(false);
    });

    it("declines with the collected rationale through the decline modal", async () => {
      declineRelocation.mockResolvedValue({ data: {} });
      wrapper = srgWrapper();

      wrapper.findComponent({ name: "RelocationBacklogPanel" }).vm.$emit("decline-request", MARKER);
      await wrapper.vm.$nextTick();
      const modal = wrapper.findComponent({ name: "DeclineRelocationModal" });
      expect(modal.props("visible")).toBe(true);
      expect(modal.props("sourceDisplayedName")).toBe("WALK-00-000012");

      modal.vm.$emit("decline", "Covered elsewhere.");
      await flushPromises(wrapper);

      expect(declineRelocation).toHaveBeenCalledWith(7, 41, "Covered elsewhere.");
      expect(wrapper.findComponent({ name: "DeclineRelocationModal" }).props("visible")).toBe(
        false,
      );
    });

    it("passes the SRG's open-proposal count to the command bar's Relocations badge", async () => {
      getRelocations.mockResolvedValueOnce({ data: [MARKER] });
      wrapper = srgWrapper();
      await flushPromises(wrapper);
      expect(wrapper.findComponent({ name: "ControlsCommandBar" }).props("relocationCount")).toBe(
        1,
      );
    });

    it("fetches destinations on propose-modal open and excludes the component's own SRG", async () => {
      // Served to BOTH fetches: the eager created-hook fetch (backlog
      // vocabulary) and the propose-modal-open refresh.
      getRelocationDestinations.mockResolvedValue({
        data: [
          { token: "TEST", name: "This very SRG", released: false },
          { token: "RCVA", name: "Walkthrough receiving SRG", released: false },
        ],
      });
      wrapper = srgWrapper();
      await flushPromises(wrapper);

      wrapper.vm.openRelocationModal();
      await flushPromises(wrapper);

      expect(getRelocationDestinations).toHaveBeenCalled();
      expect(wrapper.vm.relocationModalVisible).toBe(true);
      // TEST is this component's own abbreviation — never a propose
      // destination. The modal receives the labelled propose subset from
      // useRelocations' destination vocabulary.
      expect(
        wrapper.findComponent({ name: "MarkRelocationModal" }).props("destinationOptions"),
      ).toEqual([{ value: "RCVA", text: "Walkthrough receiving SRG" }]);
    });

    it("surfaces a destinations fetch failure as a toast and still opens the modal", async () => {
      getRelocationDestinations.mockRejectedValueOnce(new Error("network down"));
      const toasts = [];
      const listener = (event) => toasts.push(event.detail);
      document.addEventListener("vulcan:toast", listener);
      wrapper = srgWrapper();
      await flushPromises(wrapper);

      wrapper.vm.openRelocationModal();
      await flushPromises(wrapper);
      document.removeEventListener("vulcan:toast", listener);

      // The failure is surfaced, and the modal still opens — the free
      // abbreviation input remains a working propose path.
      expect(toasts.some((t) => t.variant === "danger")).toBe(true);
      expect(wrapper.vm.relocationModalVisible).toBe(true);
    });
  });

  describe("RuleEditor event forwarding", () => {
    // CRITICAL: RuleEditor must forward toggle-panel events so panel buttons work.
    // This was a regression where buttons did nothing because events weren't wired up.

    it("threads the component's document_type into RuleEditor (kind-aware editor)", async () => {
      wrapper = createWrapper({
        component: { ...defaultProps.component, document_type: "srg" },
      });
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();
      expect(wrapper.findComponent({ name: "RuleEditor" }).props("documentType")).toBe("srg");
    });

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
      wrapper = createWrapper({}, "viewer");
      expect(wrapper.vm.isViewerOnly).toBe(true);
    });

    it("isViewerOnly returns false for admin permissions", () => {
      wrapper = createWrapper({}, "admin");
      expect(wrapper.vm.isViewerOnly).toBe(false);
    });
  });

  // ── composable contracts ────────────────────────────────────────────
  // REQUIREMENTS: permissions arrive via provide/inject (usePermissions —
  // the effectivePermissions prop is GONE), and the comment composer state
  // machine flows through useReplyComposer with the onOpen/afterPosted
  // bridge. DateFormatMixin + RoleComparisonMixin were verified dead;
  // toasts come from the useToast composable.
  describe("composable contracts", () => {
    beforeEach(() => vi.clearAllMocks());

    it("sources permissions from provide via usePermissions", () => {
      wrapper = createWrapper({}, "viewer");
      expect(usePermissions).toHaveBeenCalled();
      expect(wrapper.vm.effectivePermissions).toBe("viewer");
      expect(wrapper.vm.isViewerOnly).toBe(true);
    });

    it("wires useReplyComposer — section composer opens via the bridge", async () => {
      wrapper = createWrapper();
      expect(useReplyComposer).toHaveBeenCalled();

      const showSpy = vi.spyOn(wrapper.vm.$bvModal, "show").mockImplementation(() => {});
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();
      wrapper.vm.onOpenComposer("check_content");

      expect(wrapper.vm.composerState.mode).toBe("new-comment");
      expect(wrapper.vm.composerState.section).toBe("check_content");
      expect(wrapper.vm.composerState.ruleName).toBe("TEST-001");
      expect(wrapper.vm.composerActive).toBe(true);
      await wrapper.vm.$nextTick();
      expect(showSpy).toHaveBeenCalledWith("comment-composer-modal");
    });

    it("afterPosted bridge refreshes the selected rule and clears the composer", async () => {
      wrapper = createWrapper();
      vi.spyOn(wrapper.vm.$bvModal, "show").mockImplementation(() => {});
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();
      const rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");

      wrapper.vm.onOpenComposer("check_content");
      wrapper.vm.onComposerPosted();

      expect(rootEmitSpy).toHaveBeenCalledWith("refresh:rule", 1, "all");
      expect(wrapper.vm.composerActive).toBe(false);
    });

    it("component-mode posts do NOT trigger a rule refresh", async () => {
      wrapper = createWrapper();
      vi.spyOn(wrapper.vm.$bvModal, "show").mockImplementation(() => {});
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();
      const rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");

      wrapper.vm.onOpenComponentComposer();
      wrapper.vm.onComposerPosted();

      expect(rootEmitSpy).not.toHaveBeenCalledWith(
        "refresh:rule",
        expect.anything(),
        expect.anything(),
      );
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
      const { patchComponent } = await import("@/api/componentsApi");
      patchComponent.mockResolvedValueOnce({ data: {} });

      wrapper = createWrapper();
      expect(wrapper.vm.localAdvancedFields).toBe(false);

      wrapper.vm.toggleAdvancedFields(true);
      await vi.waitFor(() => {
        expect(wrapper.vm.localAdvancedFields).toBe(true);
      });
    });

    it("does not update localAdvancedFields on PATCH failure", async () => {
      const { patchComponent } = await import("@/api/componentsApi");
      patchComponent.mockRejectedValueOnce(new Error("Network error"));

      wrapper = createWrapper();
      expect(wrapper.vm.localAdvancedFields).toBe(false);

      wrapper.vm.toggleAdvancedFields(true);
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(wrapper.vm.localAdvancedFields).toBe(false);
    });

    it("passes localAdvancedFields to RuleEditor, not component.advanced_fields", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();

      const ruleEditor = wrapper.findComponent({ name: "RuleEditor" });
      expect(ruleEditor.exists()).toBe(true);
      expect(ruleEditor.props("advanced_fields")).toBe(false);

      const { patchComponent } = await import("@/api/componentsApi");
      patchComponent.mockResolvedValueOnce({ data: {} });
      wrapper.vm.toggleAdvancedFields(true);
      await vi.waitFor(() => {
        expect(wrapper.vm.localAdvancedFields).toBe(true);
      });
      await wrapper.vm.$nextTick();
      expect(ruleEditor.props("advanced_fields")).toBe(true);
    });
  });

  describe("sidebar split into header and body slots", () => {
    it("renders RuleSearchBar in the left-sidebar-header slot (pinned)", () => {
      wrapper = createWrapper();
      const searchBar = wrapper.findComponent({ name: "RuleSearchBar" });
      expect(searchBar.exists()).toBe(true);
    });

    it("renders ActiveFilterPills in the left-sidebar-header slot (pinned)", () => {
      wrapper = createWrapper();
      const pills = wrapper.findComponent({ name: "ActiveFilterPills" });
      expect(pills.exists()).toBe(true);
    });

    it("renders RuleList in the left-sidebar slot (scrollable body)", () => {
      wrapper = createWrapper();
      const ruleList = wrapper.findComponent({ name: "RuleList" });
      expect(ruleList.exists()).toBe(true);
    });
  });

  // ==========================================================================
  // Chrome condensation: filter toggle
  // ==========================================================================
  describe("chrome condensation", () => {
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

    it("toggles filter bar when command bar emits toggle-filter-bar", async () => {
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
      const componentId = defaultProps.component.id;
      expect(localStorage.getItem(`filterBarVisible-${componentId}`)).toBe("true");
    });

    it("clearAllFilters resets both filter bar and nav filters", () => {
      wrapper = createWrapper();
      expect(typeof wrapper.vm.clearAllFilters).toBe("function");
    });

    it("restores filter bar visibility from localStorage", () => {
      const componentId = defaultProps.component.id;
      localStorage.setItem(`filterBarVisible-${componentId}`, "true");
      wrapper = createWrapper();
      const layout = wrapper.findComponent({ name: "ControlsPageLayout" });
      expect(layout.props("showFilterBar")).toBe(true);
    });
  });

  describe("AlsoSatisfiesModal integration", () => {
    it("renders AlsoSatisfiesModal when a rule is selected", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();
      const modal = wrapper.findComponent({ name: "AlsoSatisfiesModal" });
      expect(modal.exists()).toBe(true);
    });

    it("forwards add-satisfied event to $root.$emit addSatisfied:rule", async () => {
      wrapper = createWrapper();
      const rootEmitSpy = vi.spyOn(wrapper.vm.$root, "$emit");
      wrapper.vm.selectRule(1);
      await wrapper.vm.$nextTick();
      wrapper.vm.onAddSatisfied(2, 1);
      expect(rootEmitSpy).toHaveBeenCalledWith("addSatisfied:rule", 2, 1);
      rootEmitSpy.mockRestore();
    });
  });

  describe("Rule-only modals are structurally absent for SRG kind", () => {
    // The layout stub must render its slots or absence assertions pass
    // vacuously for both kinds.
    const SlotLayout = {
      template:
        "<div><slot name='modals'></slot><slot name='main-content'></slot><slot name='right-panels'></slot></div>",
    };

    const mountWithKind = (documentType) => {
      pinia = createPinia();
      setActivePinia(pinia);
      const router = createTestRouter([
        { path: "/", name: "editor-root" },
        { path: "/rules/:ruleId", name: "rule", props: true },
      ]);
      const w = shallowMount(RulesCodeEditorView, {
        localVue,
        pinia,
        router,
        provide: { effectivePermissions: "admin" },
        propsData: {
          ...defaultProps,
          component: { ...defaultProps.component, document_type: documentType },
        },
        stubs: {
          RuleEditor: true,
          RuleHistories: true,
          RuleReviews: true,
          RuleSatisfactions: true,
          RelatedRulesModal: true,
          RuleReviewModal: true,
          RuleFilterBar: true,
          ControlsCommandBar: true,
          ControlsPageLayout: SlotLayout,
          NewRuleModalForm: true,
          AlsoSatisfiesModal: true,
          RuleSearchBar: true,
          RuleList: true,
          ActiveFilterPills: true,
          Multiselect: true,
          BModal: true,
          BSidebar: true,
          BButton: true,
          BFormGroup: true,
          BIcon: true,
        },
      });
      w.vm.ruleStore.selectedRuleId = 1;
      return w;
    };

    it("renders the satisfies/duplicate/related modals for stig kind (baseline)", async () => {
      wrapper = mountWithKind("stig");
      await wrapper.vm.$nextTick();
      expect(wrapper.findComponent({ name: "AlsoSatisfiesModal" }).exists()).toBe(true);
      expect(wrapper.findComponent({ name: "RelatedRulesModal" }).exists()).toBe(true);
    });

    it("never mounts them for srg kind — authored rows omit the Rule-only keys they crash on", async () => {
      wrapper = mountWithKind("srg");
      await wrapper.vm.$nextTick();
      expect(wrapper.findComponent({ name: "AlsoSatisfiesModal" }).exists()).toBe(false);
      expect(wrapper.findComponent({ name: "RelatedRulesModal" }).exists()).toBe(false);
      expect(wrapper.findComponent({ name: "NewRuleModalForm" }).exists()).toBe(false);
    });
  });
});
