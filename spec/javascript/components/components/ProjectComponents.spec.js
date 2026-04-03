import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ProjectComponents from "@/components/components/ProjectComponents.vue";

/**
 * Released Components Page Requirements
 *
 * REQUIREMENTS:
 *
 * 1. BREADCRUMB:
 *    - Shows "Released Components"
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar
 *    - LEFT: Download button (export released components)
 *    - RIGHT: Empty for now
 *
 * 3. COMPONENT TABLE:
 *    - Uses SecurityRequirementsGuidesTable with type="Component"
 *    - Passes components as data
 *    - Search/sort/pagination handled by table component
 *
 * 4. EXPORT/DOWNLOAD:
 *    - Download button uses ExportModal
 *    - Can export selected or all released components
 */
describe("ProjectComponents", () => {
  let wrapper;

  const sampleComponents = [
    { id: 1, name: "Component A", version: "1", release: "1", based_on_title: "GPOS SRG", updated_at: "2025-01-01" },
    { id: 2, name: "Component B", version: "2", release: "1", based_on_title: "Web SRG", updated_at: "2025-01-02" },
    { id: 3, name: "Component C", version: "1", release: "2", based_on_title: "DB SRG", updated_at: "2025-01-03" },
  ];

  const createWrapper = (props = {}) => {
    return shallowMount(ProjectComponents, {
      localVue,
      propsData: {
        components: sampleComponents,
        ...props,
      },
      stubs: {
        BBreadcrumb: true,
        BaseCommandBar: true,
        SecurityRequirementsGuidesTable: true,
        ExportModal: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // BREADCRUMB
  // ==========================================
  describe("breadcrumb", () => {
    it("renders breadcrumb", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(true);
    });

    it("breadcrumb shows Released Components", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.breadcrumbs).toEqual([{ text: "Released Components", active: true }]);
    });
  });

  // ==========================================
  // COMMAND BAR
  // ==========================================
  describe("command bar", () => {
    it("renders BaseCommandBar", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BaseCommandBar" }).exists()).toBe(true);
    });

    it("has Download button in command bar", () => {
      wrapper = createWrapper();
      // Download button should trigger export modal
      expect(wrapper.vm.showExportModal).toBeDefined();
    });

    it("openExportModal shows ExportModal", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showExportModal).toBe(false);
      wrapper.vm.openExportModal();
      expect(wrapper.vm.showExportModal).toBe(true);
    });
  });

  // ==========================================
  // EXPORT MODAL
  // ==========================================
  describe("export modal", () => {
    it("renders ExportModal", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ExportModal" }).exists()).toBe(true);
    });

    it("passes components to ExportModal", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "ExportModal" });
      expect(modal.props("components")).toEqual(sampleComponents);
    });

    it("handleExport triggers download", () => {
      wrapper = createWrapper();
      const spy = vi.spyOn(wrapper.vm, "downloadExport");

      wrapper.vm.handleExport({ type: "excel", componentIds: [1, 2] });

      expect(spy).toHaveBeenCalledWith("excel", [1, 2]);
    });
  });

  // ==========================================
  // COMPONENT TABLE
  // ==========================================
  describe("component table", () => {
    it("renders SecurityRequirementsGuidesTable", () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.exists()).toBe(true);
    });

    it("passes components to table", () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("srgs")).toEqual(sampleComponents);
    });

    it("sets type to Component", () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("type")).toBe("Component");
    });

    it("disables admin actions on table", () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("is_vulcan_admin")).toBe(false);
    });

    it("shows component count", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("3");
    });
  });
});
