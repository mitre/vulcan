import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ProjectSidepanels from "@/components/project/ProjectSidepanels.vue";

/**
 * ProjectSidepanels - Slideover panels for Project page
 *
 * REQUIREMENTS:
 *
 * 1. PANELS:
 *    - proj-details: Shows project details (name, description, stats)
 *    - proj-metadata: Shows project metadata with edit capability
 *    - proj-history: Shows project history
 *
 * 2. VISIBILITY:
 *    - Each panel opens when activePanel matches its ID
 *    - Emits 'close-panel' when sidebar is hidden
 *
 * 3. EDIT CAPABILITIES:
 *    - Details: UpdateProjectDetailsModal for admin
 *    - Metadata: UpdateMetadataModal for author+
 *
 * 4. CONSISTENCY:
 *    - Uses same b-sidebar pattern as ControlsSidepanels
 *    - Right-aligned slideovers
 */
describe("ProjectSidepanels", () => {
  let wrapper;

  const defaultProps = {
    project: {
      id: 1,
      name: "Test Project",
      description: "Test description",
      visibility: "hidden",
      metadata: { key: "value" },
      histories: [{ id: 1, action: "created" }],
      // Typed-sections shape ONLY — the legacy flat ac/aim/adnm/na/nyd
      // keys are deliberately ABSENT: the reader must consume the stig
      // section, never the removed mirrors.
      details: {
        stig: { ac: 10, aim: 5, adnm: 2, na: 3, nyd: 20, total: 40 },
        srg: { applicable: 4, na: 1, nyd: 3, total: 8 },
        nur: 15,
        ur: 5,
        lck: 2,
        total: 48,
      },
    },
    activePanel: null,
  };

  // Permissions come from the page-root provide (usePermissions inject),
  // matching production: Project.vue provides "effectivePermissions".
  const createWrapper = (props = {}, permissions = "admin") => {
    return shallowMount(ProjectSidepanels, {
      localVue,
      provide: { effectivePermissions: permissions },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BSidebar: true,
        History: true,
        UpdateProjectDetailsModal: true,
        UpdateMetadataModal: true,
        RevisionHistory: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // REQUIREMENT: permissions arrive via the root provide (usePermissions
  // inject). Details edit modal needs admin (canAdmin); Metadata edit modal
  // needs author or above (canEdit).
  describe("permissions via inject (usePermissions)", () => {
    it("canAdmin is true when admin permissions are provided", () => {
      wrapper = createWrapper({}, "admin");
      expect(wrapper.vm.canAdmin).toBe(true);
    });

    it("canAdmin is false for author permissions", () => {
      wrapper = createWrapper({}, "author");
      expect(wrapper.vm.canAdmin).toBe(false);
    });

    it("canEdit is true for author permissions", () => {
      wrapper = createWrapper({}, "author");
      expect(wrapper.vm.canEdit).toBe(true);
    });

    it("canEdit is false for viewer permissions", () => {
      wrapper = createWrapper({}, "viewer");
      expect(wrapper.vm.canEdit).toBe(false);
    });
  });

  // ==========================================
  // BASIC RENDERING
  // ==========================================
  describe("basic rendering", () => {
    it("renders the component", () => {
      wrapper = createWrapper();
      expect(wrapper.exists()).toBe(true);
    });

    it("renders all 4 sidebars (Details, Metadata, History, Revision History)", () => {
      wrapper = createWrapper();
      const sidebars = wrapper.findAllComponents({ name: "BSidebar" });
      expect(sidebars.length).toBe(4);
    });
  });

  // ==========================================
  // PANEL VISIBILITY
  // ==========================================
  describe("panel visibility", () => {
    it("shows proj-details sidebar when activePanel is proj-details", () => {
      wrapper = createWrapper({ activePanel: "proj-details" });
      const sidebar = wrapper.find('[data-testid="proj-details-sidebar"]');
      expect(sidebar.attributes("visible")).toBe("true");
    });

    it("shows proj-metadata sidebar when activePanel is proj-metadata", () => {
      wrapper = createWrapper({ activePanel: "proj-metadata" });
      const sidebar = wrapper.find('[data-testid="proj-metadata-sidebar"]');
      expect(sidebar.attributes("visible")).toBe("true");
    });

    it("shows proj-history sidebar when activePanel is proj-history", () => {
      wrapper = createWrapper({ activePanel: "proj-history" });
      const sidebar = wrapper.find('[data-testid="proj-history-sidebar"]');
      expect(sidebar.attributes("visible")).toBe("true");
    });

    it("shows proj-revision-history sidebar when activePanel is proj-revision-history", () => {
      wrapper = createWrapper({ activePanel: "proj-revision-history" });
      const sidebar = wrapper.find('[data-testid="proj-revision-history-sidebar"]');
      expect(sidebar.attributes("visible")).toBe("true");
    });

    it("hides all sidebars when activePanel is null", () => {
      wrapper = createWrapper({ activePanel: null });
      const detailsSidebar = wrapper.find('[data-testid="proj-details-sidebar"]');
      const metadataSidebar = wrapper.find('[data-testid="proj-metadata-sidebar"]');
      const historySidebar = wrapper.find('[data-testid="proj-history-sidebar"]');
      const revisionSidebar = wrapper.find('[data-testid="proj-revision-history-sidebar"]');
      expect(detailsSidebar.attributes("visible")).toBeFalsy();
      expect(metadataSidebar.attributes("visible")).toBeFalsy();
      expect(historySidebar.attributes("visible")).toBeFalsy();
      expect(revisionSidebar.attributes("visible")).toBeFalsy();
    });
  });

  // ==========================================
  // CLOSE PANEL EVENT
  // ==========================================
  describe("close panel event", () => {
    it("emits close-panel when sidebar is hidden", async () => {
      wrapper = createWrapper({ activePanel: "proj-details" });
      const sidebar = wrapper.findComponent({ name: "BSidebar" });
      sidebar.vm.$emit("hidden");
      expect(wrapper.emitted("close-panel")).toBeTruthy();
    });
  });

  // ==========================================
  // PROJECT DETAILS CONTENT
  // ==========================================
  describe("project details panel", () => {
    it("displays project name", () => {
      wrapper = createWrapper({ activePanel: "proj-details" });
      expect(wrapper.text()).toContain("Test Project");
    });

    it("displays project description", () => {
      wrapper = createWrapper({ activePanel: "proj-details" });
      expect(wrapper.text()).toContain("Test description");
    });

    it("displays status counts read from the typed stig section (flat keys absent)", () => {
      wrapper = createWrapper({ activePanel: "proj-details" });
      const text = wrapper.text().replace(/\s+/g, " ");
      // Counts come from details.stig.*; percentages use the
      // type-agnostic details.total (48).
      expect(text).toContain("Applicable - Configurable: 10 (20.83%)");
      expect(text).toContain("Applicable - Inherently Meets: 5 (10.42%)");
      expect(text).toContain("Applicable - Does Not Meet: 2 (4.17%)");
      expect(text).toContain("Not Applicable: 3 (6.25%)");
      expect(text).toContain("Not Yet Determined: 20 (41.67%)");
      expect(text).toContain("Total: 48");
    });

    it("displays the SRG section from details.srg with its own vocabulary", () => {
      wrapper = createWrapper({ activePanel: "proj-details" });
      const text = wrapper.text().replace(/\s+/g, " ");
      // Both kind sections carry their section totals; the overall
      // Total row stays type-agnostic (40 + 8 = 48).
      expect(text).toContain("STIG (40)");
      expect(text).toContain("SRG (8)");
      expect(text).toContain("Applicable: 4 (8.33%)");
      expect(text).toContain("Not Applicable: 1 (2.08%)");
      expect(text).toContain("Not Yet Determined: 3 (6.25%)");
    });

    it("shows edit button for admin", () => {
      wrapper = createWrapper({ activePanel: "proj-details", effectivePermissions: "admin" });
      expect(wrapper.findComponent({ name: "UpdateProjectDetailsModal" }).exists()).toBe(true);
    });
  });

  // ==========================================
  // PROJECT METADATA CONTENT
  // ==========================================
  describe("project metadata panel", () => {
    it("displays metadata key-value pairs", () => {
      wrapper = createWrapper({ activePanel: "proj-metadata" });
      expect(wrapper.text()).toContain("key");
    });

    it("shows edit button for author+", () => {
      wrapper = createWrapper({ activePanel: "proj-metadata", effectivePermissions: "author" });
      expect(wrapper.findComponent({ name: "UpdateMetadataModal" }).exists()).toBe(true);
    });
  });

  // ==========================================
  // PROJECT HISTORY CONTENT
  // ==========================================
  describe("project history panel", () => {
    it("renders History component", () => {
      wrapper = createWrapper({ activePanel: "proj-history" });
      expect(wrapper.findComponent({ name: "History" }).exists()).toBe(true);
    });

    it("passes histories to History component", () => {
      wrapper = createWrapper({ activePanel: "proj-history" });
      const history = wrapper.findComponent({ name: "History" });
      expect(history.props("histories")).toEqual(defaultProps.project.histories);
    });
  });

  // ==========================================
  // REVISION HISTORY PANEL
  // ==========================================
  describe("revision history panel", () => {
    it("renders RevisionHistory component", () => {
      wrapper = createWrapper({ activePanel: "proj-revision-history" });
      expect(wrapper.findComponent({ name: "RevisionHistory" }).exists()).toBe(true);
    });

    it("passes project to RevisionHistory", () => {
      wrapper = createWrapper({ activePanel: "proj-revision-history" });
      const revisionHistory = wrapper.findComponent({ name: "RevisionHistory" });
      expect(revisionHistory.props("project")).toEqual(defaultProps.project);
    });
  });
});
