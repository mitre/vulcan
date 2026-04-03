import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import Stigs from "@/components/stigs/Stigs.vue";
import axios from "axios";

// Mock axios
vi.mock("axios", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * STIGs List Page Requirements:
 *
 * 1. BREADCRUMB:
 *    - Shows "STIGs" as the active breadcrumb
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar for layout
 *    - Download button always visible (left slot)
 *    - Upload STIG button visible only for admin users (left slot)
 *    - Upload button hidden for non-admin
 *
 * 3. STIG COUNT:
 *    - Displays STIG count in a badge
 *    - Count reflects the stigs data array length
 *
 * 4. TABLE:
 *    - Renders SecurityRequirementsGuidesTable with type="STIG"
 *    - Passes stigs data to the table
 *
 * 5. DATA INITIALIZATION:
 *    - Initializes stigs from givenstigs prop on mount
 *
 * 6. UPLOAD MODAL:
 *    - openUploadModal sets showUploadComponent=true
 *    - SecurityRequirementsGuidesUpload uses post_path="/stigs"
 *
 * 7. EXPORT MODAL:
 *    - openExportModal sets showExportModal=true
 *    - handleExport opens window for each selected STIG
 *
 * 8. LOAD STIGS:
 *    - loadStigs calls GET /stigs and updates stigs data
 */
describe("Stigs", () => {
  let wrapper;

  const sampleStigs = [
    { id: 1, stig_id: "STIG-001", title: "RHEL 9 STIG", version: "1" },
    { id: 2, stig_id: "STIG-002", title: "Windows Server 2025", version: "2" },
    { id: 3, stig_id: "STIG-003", title: "PostgreSQL STIG", version: "1" },
  ];

  // Use mount (not shallowMount) so BootstrapVue components render properly.
  // Stub only custom child components that have their own complex dependencies.
  const createWrapper = (props = {}) => {
    return mount(Stigs, {
      localVue,
      propsData: {
        givenstigs: sampleStigs,
        is_vulcan_admin: true,
        ...props,
      },
      stubs: {
        BaseCommandBar: {
          template:
            '<div class="base-command-bar-stub"><slot name="left" /><slot name="right" /></div>',
        },
        SecurityRequirementsGuidesTable: {
          template: "<div />",
          props: ["srgs", "is_vulcan_admin", "type"],
        },
        SecurityRequirementsGuidesUpload: {
          template: "<div />",
          props: ["value", "post_path"],
        },
        ExportModal: {
          template: "<div />",
          props: ["value", "components", "formats", "columnDefinitions", "title"],
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
    vi.clearAllMocks();
  });

  // ==========================================
  // BREADCRUMB
  // ==========================================
  describe("breadcrumb", () => {
    it("renders breadcrumb component", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(true);
    });

    it("breadcrumb shows STIGs as active item", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.breadcrumbs).toEqual([{ text: "STIGs", active: true }]);
    });
  });

  // ==========================================
  // COMMAND BAR BUTTONS
  // ==========================================
  describe("command bar", () => {
    it("renders BaseCommandBar", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".base-command-bar-stub").exists()).toBe(true);
    });

    it("shows Download button always", () => {
      wrapper = createWrapper({ is_vulcan_admin: false });
      const downloadBtn = wrapper.find('[data-testid="download-btn"]');
      expect(downloadBtn.exists()).toBe(true);
      expect(downloadBtn.text()).toContain("Download");
    });

    it("shows Upload STIG button for admin users", () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      const uploadBtn = wrapper.find('[data-testid="upload-stig-btn"]');
      expect(uploadBtn.exists()).toBe(true);
      expect(uploadBtn.text()).toContain("Upload STIG");
    });

    it("hides Upload STIG button for non-admin users", () => {
      wrapper = createWrapper({ is_vulcan_admin: false });
      const uploadBtn = wrapper.find('[data-testid="upload-stig-btn"]');
      expect(uploadBtn.exists()).toBe(false);
    });
  });

  // ==========================================
  // STIG COUNT
  // ==========================================
  describe("STIG count", () => {
    it("displays STIG count badge with correct number", async () => {
      wrapper = createWrapper();
      await wrapper.vm.$nextTick();
      const badge = wrapper.findComponent({ name: "BBadge" });
      expect(badge.exists()).toBe(true);
      expect(badge.text()).toBe("3");
    });

    it("updates count when stigs data changes", async () => {
      wrapper = createWrapper();
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.stigs.length).toBe(3);

      wrapper.vm.stigs = [...sampleStigs, { id: 4, title: "New STIG" }];
      await wrapper.vm.$nextTick();

      const badge = wrapper.findComponent({ name: "BBadge" });
      expect(badge.text()).toBe("4");
    });
  });

  // ==========================================
  // TABLE
  // ==========================================
  describe("table", () => {
    it("renders SecurityRequirementsGuidesTable", () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.exists()).toBe(true);
    });

    it('passes type="STIG" to table', () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("type")).toBe("STIG");
    });

    it("passes stigs data to table as srgs prop", async () => {
      wrapper = createWrapper();
      await wrapper.vm.$nextTick();
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("srgs")).toEqual(sampleStigs);
    });

    it("passes is_vulcan_admin to table", () => {
      wrapper = createWrapper({ is_vulcan_admin: false });
      const table = wrapper.findComponent({ name: "SecurityRequirementsGuidesTable" });
      expect(table.props("is_vulcan_admin")).toBe(false);
    });
  });

  // ==========================================
  // DATA INITIALIZATION
  // ==========================================
  describe("data initialization", () => {
    it("initializes stigs from givenstigs prop on mount", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.stigs).toEqual(sampleStigs);
    });

    it("starts with showUploadComponent as false", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showUploadComponent).toBe(false);
    });

    it("starts with showExportModal as false", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showExportModal).toBe(false);
    });
  });

  // ==========================================
  // UPLOAD MODAL
  // ==========================================
  describe("upload modal", () => {
    it("openUploadModal sets showUploadComponent to true", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showUploadComponent).toBe(false);

      wrapper.vm.openUploadModal();
      expect(wrapper.vm.showUploadComponent).toBe(true);
    });

    it("passes post_path=/stigs to upload component", async () => {
      wrapper = createWrapper();
      await wrapper.vm.$nextTick();
      const upload = wrapper.findComponent({ name: "SecurityRequirementsGuidesUpload" });
      expect(upload.exists()).toBe(true);
      // post_path uses underscores — Vue 2 only converts kebab-case to camelCase,
      // NOT snake_case, so the prop name stays as-is.
      expect(upload.props("post_path")).toBe("/stigs");
    });
  });

  // ==========================================
  // EXPORT MODAL
  // ==========================================
  describe("export modal", () => {
    it("openExportModal sets showExportModal to true", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showExportModal).toBe(false);

      wrapper.vm.openExportModal();
      expect(wrapper.vm.showExportModal).toBe(true);
    });

    it("handleExport opens window for each selected STIG", () => {
      wrapper = createWrapper();
      const openSpy = vi.spyOn(globalThis, "open").mockImplementation(() => {});

      wrapper.vm.handleExport({
        type: "xccdf",
        componentIds: [1, 2],
        columns: [],
      });

      expect(openSpy).toHaveBeenCalledTimes(2);
      expect(openSpy).toHaveBeenCalledWith("/stigs/1/export/xccdf");
      expect(openSpy).toHaveBeenCalledWith("/stigs/2/export/xccdf");

      openSpy.mockRestore();
    });

    it("handleExport appends columns as query parameter for CSV", () => {
      wrapper = createWrapper();
      const openSpy = vi.spyOn(globalThis, "open").mockImplementation(() => {});

      wrapper.vm.handleExport({
        type: "csv",
        componentIds: [1],
        columns: ["title", "version"],
      });

      expect(openSpy).toHaveBeenCalledWith("/stigs/1/export/csv?columns=title,version");

      openSpy.mockRestore();
    });

    it("passes formats to ExportModal", () => {
      wrapper = createWrapper();
      const exportModal = wrapper.findComponent({ name: "ExportModal" });
      expect(exportModal.exists()).toBe(true);
      expect(exportModal.props("formats")).toEqual(["xccdf", "csv"]);
    });
  });

  // ==========================================
  // LOAD STIGS
  // ==========================================
  describe("loadStigs", () => {
    it("fetches STIGs from /stigs and updates data", async () => {
      const newStigs = [{ id: 10, title: "Refreshed STIG" }];
      axios.get.mockResolvedValueOnce({ data: newStigs });

      wrapper = createWrapper();
      await wrapper.vm.loadStigs();

      // Wait for promise resolution
      await wrapper.vm.$nextTick();

      expect(axios.get).toHaveBeenCalledWith("/stigs");
      expect(wrapper.vm.stigs).toEqual(newStigs);
    });
  });
});
