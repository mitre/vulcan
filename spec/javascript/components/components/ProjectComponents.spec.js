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
 * 3. COMPONENT GRID:
 *    - Shows ComponentCards (read-only, no actions)
 *    - Search functionality
 *    - Sorted alphabetically
 *
 * 4. EXPORT/DOWNLOAD:
 *    - Download button uses ExportModal
 *    - Can export selected or all released components
 */
describe("ProjectComponents", () => {
  let wrapper;

  const sampleComponents = [
    { id: 1, name: "Component A", version: "1", release: "1" },
    { id: 2, name: "Component B", version: "2", release: "1" },
    { id: 3, name: "Component C", version: "1", release: "2" },
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
        ComponentCard: true,
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
  // SEARCH AND FILTERING
  // ==========================================
  describe("search functionality", () => {
    it("filters components by search term", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ search: "Component A" });
      const filtered = wrapper.vm.sortedFilteredComponents();
      expect(filtered.length).toBe(1);
      expect(filtered[0].name).toBe("Component A");
    });

    it("search is case insensitive", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ search: "component a" });
      const filtered = wrapper.vm.sortedFilteredComponents();
      expect(filtered.length).toBe(1);
    });

    it("returns all components when search is empty", () => {
      wrapper = createWrapper();
      const filtered = wrapper.vm.sortedFilteredComponents();
      expect(filtered.length).toBe(3);
    });

    it("sorts components alphabetically", () => {
      const unsorted = [
        { id: 1, name: "Zebra", version: "1", release: "1" },
        { id: 2, name: "Apple", version: "1", release: "1" },
        { id: 3, name: "Mango", version: "1", release: "1" },
      ];
      wrapper = createWrapper({ components: unsorted });
      const sorted = wrapper.vm.sortedFilteredComponents();
      expect(sorted[0].name).toBe("Apple");
      expect(sorted[1].name).toBe("Mango");
      expect(sorted[2].name).toBe("Zebra");
    });
  });

  // ==========================================
  // COMPONENT CARDS
  // ==========================================
  describe("component cards", () => {
    it("renders ComponentCard for each component", () => {
      wrapper = createWrapper();
      const cards = wrapper.findAllComponents({ name: "ComponentCard" });
      expect(cards.length).toBe(3);
    });

    it("passes actionable=false to ComponentCards (read-only)", () => {
      wrapper = createWrapper();
      const cards = wrapper.findAllComponents({ name: "ComponentCard" });
      cards.wrappers.forEach((card) => {
        expect(card.props("actionable")).toBe(false);
      });
    });
  });
});
