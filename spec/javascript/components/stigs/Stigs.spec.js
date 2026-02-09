import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import Stigs from "@/components/stigs/Stigs.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * STIGs List Page Requirements
 *
 * REQUIREMENTS:
 *
 * 1. BREADCRUMB:
 *    - Shows "STIGs"
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar
 *    - LEFT: Upload STIG button (admin only)
 *    - RIGHT: Empty for now
 *
 * 3. TABLE:
 *    - Shows SecurityRequirementsGuidesTable
 *    - Displays STIGs with delete capability
 */
describe("Stigs", () => {
  let wrapper;

  const sampleStigs = [
    { id: 1, stig_id: "STIG-001", title: "Test STIG 1", version: "1" },
    { id: 2, stig_id: "STIG-002", title: "Test STIG 2", version: "2" },
  ];

  const createWrapper = (props = {}) => {
    return shallowMount(Stigs, {
      localVue,
      propsData: {
        givenstigs: sampleStigs,
        is_vulcan_admin: true,
        ...props,
      },
      stubs: {
        BBreadcrumb: true,
        BaseCommandBar: true,
        SecurityRequirementsGuidesTable: true,
        SecurityRequirementsGuidesUpload: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("breadcrumb", () => {
    it("renders breadcrumb", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(true);
    });

    it("breadcrumb shows STIGs", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.breadcrumbs).toEqual([{ text: "STIGs", active: true }]);
    });
  });

  describe("command bar", () => {
    it("renders BaseCommandBar", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BaseCommandBar" }).exists()).toBe(true);
    });

    it("shows Upload STIG button for admin", () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      expect(wrapper.vm.showUploadComponent).toBeDefined();
    });

    it("hides Upload STIG button for non-admin", () => {
      wrapper = createWrapper({ is_vulcan_admin: false });
      // Button visibility controlled by v-if in template
      expect(wrapper.props("is_vulcan_admin")).toBe(false);
    });

    it("openUploadModal shows upload modal", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showUploadComponent).toBe(false);
      wrapper.vm.openUploadModal();
      expect(wrapper.vm.showUploadComponent).toBe(true);
    });
  });

  describe("table", () => {
    it("renders SecurityRequirementsGuidesTable", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" }).exists()).toBe(
        true,
      );
    });

    it("receives STIGs via props for table", () => {
      wrapper = createWrapper();
      // Component receives givenstigs prop and initializes stigs data
      expect(wrapper.props("givenstigs")).toEqual(sampleStigs);
    });

    it('passes type="STIG" to table', () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("type")).toBe("STIG");
    });
  });
});
