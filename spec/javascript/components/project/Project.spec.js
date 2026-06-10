import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue, flushPromises } from "@test/testHelper";
import Project from "@/components/project/Project.vue";

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

vi.mock("@/api/projectsApi", () => ({
  getProject: vi.fn(() => Promise.resolve({ data: {} })),
  updateProject: vi.fn(() => Promise.resolve({ data: {} })),
  exportProjectData: vi.fn(() => Promise.resolve("/projects/1/export/csv?component_ids=1")),
}));

vi.mock("@/api/componentsApi", () => ({
  deleteComponent: vi.fn(() => Promise.resolve({ data: {} })),
}));

/**
 * Project Component Tests
 *
 * REQUIREMENTS:
 *
 * 1. LAYOUT:
 *    - Breadcrumb navigation
 *    - Command bar with actions and panel buttons
 *    - Full-width tabs (no right sidebar)
 *    - Slideover panels for Details, Metadata, History
 *
 * 2. COMMAND BAR INTEGRATION:
 *    - Renders ProjectCommandBar
 *    - Passes project, permissions, activePanel
 *    - Handles toggle-visibility, new-component, download, toggle-panel events
 *
 * 3. SIDEPANELS INTEGRATION:
 *    - Renders ProjectSidepanels
 *    - Passes project, permissions, activePanel
 *    - Handles close-panel, project-updated events
 *
 * 4. USESIDEBAR COMPOSABLE:
 *    - Has activePanel in component state
 *    - togglePanel opens/closes panels
 *    - closePanel closes active panel
 */
describe("Project", () => {
  let wrapper;

  const defaultProps = {
    initialProjectState: {
      id: 1,
      name: "Test Project",
      description: "Test description",
      visibility: "hidden",
      effective_permissions: "admin",
      components: [],
      available_components: [],
      memberships: [],
      memberships_count: 0,
      access_requests: [],
      metadata: {},
      histories: [],
      details: {
        ac: 10,
        aim: 5,
        adnm: 2,
        na: 3,
        nyd: 20,
        nur: 15,
        ur: 5,
        lck: 2,
        total: 62,
      },
    },
    current_user_id: 1,
    statuses: ["Not Yet Determined", "Applicable - Configurable"],
    available_roles: ["admin", "author", "viewer"],
  };

  const createWrapper = (props = {}) => {
    return shallowMount(Project, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        ProjectCommandBar: true,
        ProjectSidepanels: true,
        ExportModal: true,
        ComponentActionPicker: true,
        BBreadcrumb: true,
        BTabs: true,
        BTab: true,
        BModal: true,
        ComponentCard: true,
        NewComponentModal: true,
        AddComponentModal: true,
        DiffViewer: true,
        RevisionHistory: true,
        MembershipsTable: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // BASIC RENDERING
  // ==========================================
  describe("basic rendering", () => {
    it("renders the component", () => {
      wrapper = createWrapper();
      expect(wrapper.exists()).toBe(true);
    });

    it("renders breadcrumb", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(true);
    });

    it("renders ProjectCommandBar", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ProjectCommandBar" }).exists()).toBe(true);
    });

    it("renders ProjectSidepanels", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ProjectSidepanels" }).exists()).toBe(true);
    });

    it("renders tabs", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BTabs" }).exists()).toBe(true);
    });
  });

  // ==========================================
  // PERMISSIONS VIA PROVIDE (SPA-ready)
  // ==========================================
  describe("permissions via provide", () => {
    it("reads effective_permissions from initialProjectState, not from a separate prop", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.effective_permissions).toBe("admin");
    });

    it("derives permissions from initialProjectState data", () => {
      wrapper = createWrapper({
        initialProjectState: {
          ...defaultProps.initialProjectState,
          effective_permissions: "viewer",
        },
      });
      expect(wrapper.vm.effective_permissions).toBe("viewer");
    });

    it("exposes canAdmin=true for admin permissions (gates admin-only children)", () => {
      // Project.vue is the PROVIDER — it cannot inject its own provide, so
      // canAdmin comes from the roleGteTo util in setup, not usePermissions.
      wrapper = createWrapper();
      expect(wrapper.vm.canAdmin).toBe(true);
    });

    it("exposes canAdmin=false for viewer permissions", () => {
      wrapper = createWrapper({
        initialProjectState: {
          ...defaultProps.initialProjectState,
          effective_permissions: "viewer",
        },
      });
      expect(wrapper.vm.canAdmin).toBe(false);
    });

    it("defaults to null when initialProjectState has no permissions", () => {
      const stateWithout = { ...defaultProps.initialProjectState };
      delete stateWithout.effective_permissions;
      // REQUIREMENT: null permissions is the designed non-member contract —
      // every child prop in the tree must accept it without Vue warnings.
      const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
      wrapper = createWrapper({ initialProjectState: stateWithout });
      expect(wrapper.vm.effective_permissions).toBeNull();
      const propWarnings = errorSpy.mock.calls.filter((call) =>
        String(call[0]).includes('type check failed for prop "effectivePermissions"'),
      );
      errorSpy.mockRestore();
      expect(propWarnings).toEqual([]);
    });
  });

  // ==========================================
  // USESIDEBAR COMPOSABLE INTEGRATION
  // ==========================================
  describe("useSidebar composable integration", () => {
    it("has activePanel in component state", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.activePanel).toBeDefined();
    });

    it("togglePanel opens a panel", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("proj-details");
      expect(wrapper.vm.activePanel).toBe("proj-details");
    });

    it("togglePanel closes panel when toggled again", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("proj-details");
      wrapper.vm.togglePanel("proj-details");
      expect(wrapper.vm.activePanel).toBeNull();
    });

    it("closePanel closes active panel", () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("proj-details");
      wrapper.vm.closePanel();
      expect(wrapper.vm.activePanel).toBeNull();
    });
  });

  // ==========================================
  // COMMAND BAR PROPS
  // ==========================================
  describe("command bar props", () => {
    it("passes project to ProjectCommandBar", () => {
      wrapper = createWrapper();
      const commandBar = wrapper.findComponent({ name: "ProjectCommandBar" });
      expect(commandBar.props("project")).toEqual(defaultProps.initialProjectState);
    });

    it("provides effectivePermissions to descendants instead of prop-passing", () => {
      // ProjectCommandBar (and the other project/ children) inject
      // effectivePermissions via usePermissions — the template attribute is
      // gone. A leftover attr would land in $attrs on the stub, so
      // attributes() pins the removal.
      wrapper = createWrapper();
      const commandBar = wrapper.findComponent({ name: "ProjectCommandBar" });
      expect(commandBar.attributes("effective-permissions")).toBeUndefined();
      expect(wrapper.vm.effective_permissions).toBe("admin");
    });

    it("passes activePanel to ProjectCommandBar", async () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("proj-details");
      await wrapper.vm.$nextTick();
      const commandBar = wrapper.findComponent({ name: "ProjectCommandBar" });
      expect(commandBar.props("activePanel")).toBe("proj-details");
    });
  });

  // ==========================================
  // SIDEPANELS PROPS
  // ==========================================
  describe("sidepanels props", () => {
    it("passes project to ProjectSidepanels", () => {
      wrapper = createWrapper();
      const sidepanels = wrapper.findComponent({ name: "ProjectSidepanels" });
      expect(sidepanels.props("project")).toEqual(defaultProps.initialProjectState);
    });

    it("passes activePanel to ProjectSidepanels", async () => {
      wrapper = createWrapper();
      wrapper.vm.togglePanel("proj-metadata");
      await wrapper.vm.$nextTick();
      const sidepanels = wrapper.findComponent({ name: "ProjectSidepanels" });
      expect(sidepanels.props("activePanel")).toBe("proj-metadata");
    });
  });

  // ==========================================
  // VISIBILITY TOGGLE
  // ==========================================
  describe("visibility toggle", () => {
    it("showVisibilityConfirm sets pending visibility and shows modal", () => {
      wrapper = createWrapper();
      wrapper.vm.showVisibilityConfirm(true);
      expect(wrapper.vm.pendingVisibility).toBe(true);
      expect(wrapper.vm.showVisibilityModal).toBe(true);
    });

    it("updateVisibility closes modal and calls updateProject", async () => {
      const { getProject } = await import("@/api/projectsApi");
      getProject.mockResolvedValue({ data: defaultProps.initialProjectState });
      const { updateProject } = await import("@/api/projectsApi");

      wrapper = createWrapper();
      wrapper.vm.pendingVisibility = true;
      wrapper.vm.showVisibilityModal = true;

      wrapper.vm.updateVisibility();

      expect(wrapper.vm.showVisibilityModal).toBe(false);
      expect(updateProject).toHaveBeenCalledWith(1, { visibility: "discoverable" });
    });

    it("cancelVisibilityChange closes modal and resets command bar toggle", () => {
      wrapper = createWrapper();
      wrapper.vm.showVisibilityModal = true;
      // Mock the command bar ref
      const resetMock = vi.fn();
      wrapper.vm.$refs.commandBar = { resetVisibilityToggle: resetMock };

      wrapper.vm.cancelVisibilityChange();

      expect(wrapper.vm.showVisibilityModal).toBe(false);
      expect(resetMock).toHaveBeenCalled();
    });

    it("onVisibilityModalHidden resets command bar toggle (handles backdrop/escape)", () => {
      wrapper = createWrapper();
      // Mock the command bar ref
      const resetMock = vi.fn();
      wrapper.vm.$refs.commandBar = { resetVisibilityToggle: resetMock };

      wrapper.vm.onVisibilityModalHidden();

      expect(resetMock).toHaveBeenCalled();
    });
  });

  // ==========================================
  // COMPONENT ACTION PICKER WORKFLOW (CONTRACT)
  // ==========================================
  describe("component action picker workflow", () => {
    it("renders ComponentActionPicker for selecting component creation method", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ComponentActionPicker" }).exists()).toBe(true);
    });

    it("clicking New Component button shows ComponentActionPicker modal", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showComponentActionPicker).toBe(false);
      wrapper.vm.openNewComponentModal();
      expect(wrapper.vm.showComponentActionPicker).toBe(true);
    });

    it('routes "create" action to NewComponentModal (default mode)', () => {
      wrapper = createWrapper();
      const showModalMock = vi.fn();
      wrapper.vm.$refs.newComponentModal = { showModal: showModalMock };

      wrapper.vm.handleComponentAction("create");

      expect(showModalMock).toHaveBeenCalled();
    });

    it('routes "import" action to NewComponentModal (spreadsheet mode)', () => {
      wrapper = createWrapper();
      const showModalMock = vi.fn();
      wrapper.vm.$refs.importComponentModal = { showModal: showModalMock };

      wrapper.vm.handleComponentAction("import");

      expect(showModalMock).toHaveBeenCalled();
    });

    it('routes "copy" action to NewComponentModal (copy mode)', () => {
      wrapper = createWrapper();
      const showModalMock = vi.fn();
      wrapper.vm.$refs.copyComponentModal = { showModal: showModalMock };

      wrapper.vm.handleComponentAction("copy");

      expect(showModalMock).toHaveBeenCalled();
    });

    it('routes "overlay" action to AddComponentModal', () => {
      wrapper = createWrapper();
      const showModalMock = vi.fn();
      wrapper.vm.$refs.addComponentModal = { showModal: showModalMock };

      wrapper.vm.handleComponentAction("overlay");

      expect(showModalMock).toHaveBeenCalled();
    });
  });

  // ==========================================
  // EMPTY STATE MESSAGES
  // ==========================================
  describe("empty state messages", () => {
    it("shows helpful message when no regular components", () => {
      const emptyProject = {
        ...defaultProps.initialProjectState,
        components: [],
      };
      wrapper = createWrapper({ initialProjectState: emptyProject });
      expect(wrapper.text()).toContain("No components yet");
      expect(wrapper.text()).toContain("New Component");
    });

    it("shows helpful message when no overlaid components", () => {
      wrapper = createWrapper();
      // Default project has no overlaid components
      expect(wrapper.text()).toContain("No overlaid components");
      expect(wrapper.text()).toContain("Add Overlaid Component");
    });

    it("does not show empty message when regular components exist", () => {
      const projectWithComponents = {
        ...defaultProps.initialProjectState,
        components: [{ id: 1, name: "Test Component", component_id: null }],
      };
      wrapper = createWrapper({ initialProjectState: projectWithComponents });
      expect(wrapper.text()).not.toContain("No components yet");
    });
  });

  // ==========================================
  // MODAL INSTANCES (NO OPENER BUTTONS)
  // ==========================================
  describe("modal instances without opener buttons", () => {
    it("NewComponentModal instances exist for programmatic access", () => {
      wrapper = createWrapper();
      // Modals exist in template but don't render opener buttons (showOpener=false)
      expect(wrapper.findAllComponents({ name: "NewComponentModal" }).length).toBeGreaterThan(0);
    });

    it("AddComponentModal exists for programmatic access", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "AddComponentModal" }).exists()).toBe(true);
    });

    it("NewComponentModal does not pass showOpener prop (defaults to false = no button)", () => {
      wrapper = createWrapper();
      const modals = wrapper.findAllComponents({ name: "NewComponentModal" });
      modals.wrappers.forEach((modal) => {
        // showOpener prop should not be set (defaults to false)
        expect(modal.props("showOpener")).toBeFalsy();
      });
    });

    it("AddComponentModal does not pass showButton prop (defaults to false = no button)", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "AddComponentModal" });
      expect(modal.props("showButton")).toBeFalsy();
    });
  });

  // ==========================================
  // DOWNLOAD HANDLING (via ExportModal)
  // ==========================================
  describe("download handling", () => {
    it("openExportModal shows the export modal", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showExportModal).toBe(false);
      wrapper.vm.openExportModal();
      expect(wrapper.vm.showExportModal).toBe(true);
    });

    it("downloadExport calls exportProjectData with project id, type, and options", async () => {
      const { exportProjectData } = await import("@/api/projectsApi");
      // window.open is the real side effect (browser performs the download).
      // Spy + assert so jsdom never receives the un-implemented call (zero-noise).
      const openSpy = vi.spyOn(window, "open").mockImplementation(() => null);

      wrapper = createWrapper();
      wrapper.vm.downloadExport("csv", [1, 2], "working_copy", true, false, true);

      expect(exportProjectData).toHaveBeenCalledWith(1, "csv", {
        componentIds: [1, 2],
        mode: "working_copy",
        includeSrg: true,
        includeMemberships: false,
        excludeSatisfiedBy: true,
      });

      await flushPromises(wrapper);
      expect(openSpy).toHaveBeenCalledWith("/projects/1/export/csv?component_ids=1");
      openSpy.mockRestore();
    });

    it("renders ExportModal component", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ExportModal" }).exists()).toBe(true);
    });
  });

  // ==========================================
  // NO RIGHT SIDEBAR (REGRESSION TEST)
  // ==========================================
  describe("layout - no right sidebar", () => {
    it("does not have col-md-2 right sidebar", () => {
      wrapper = createWrapper();
      // The old layout had col-md-10 and col-md-2
      // With shallowMount, check for stubbed BCol with md="2"
      const cols = wrapper.findAllComponents({ name: "BCol" });
      const hasMd2 = cols.wrappers.some((col) => col.attributes("md") === "2");
      expect(hasMd2).toBe(false);
    });

    it("main content uses full width (md=12)", () => {
      wrapper = createWrapper();
      // Find BCol components and verify one has md="12"
      const cols = wrapper.findAllComponents({ name: "BCol" });
      const hasMd12 = cols.wrappers.some((col) => col.attributes("md") === "12");
      expect(hasMd12).toBe(true);
    });
  });
});
