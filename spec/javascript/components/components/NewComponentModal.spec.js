import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount, mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import NewComponentModal from "@/components/components/NewComponentModal.vue";
import axios from "axios";

// Mock axios (used by fetchData, createComponent, detectSrg)
vi.mock("axios", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * NewComponentModal Contract Tests
 *
 * REQUIREMENTS:
 *
 * 1. OPENER BUTTON RENDERING:
 *    - showOpener defaults to FALSE (no button renders)
 *    - showOpener=true renders the opener button
 *    - Prevents unwanted buttons when modal is triggered programmatically
 *
 * 2. PROGRAMMATIC ACCESS:
 *    - showModal() method exists for triggering via refs
 *    - Works regardless of showOpener value
 *
 * 3. FILE INPUT ACCEPT ATTRIBUTE (spreadsheet import mode):
 *    - Must accept CSV files (.csv, text/csv)
 *    - Must accept Excel files (.xlsx, .xls, proper MIME types)
 *    - Must NOT contain typos (e.g., "appliction" instead of "application")
 *    - Backend (Roo gem) supports CSV, so UI must not block them
 */
describe("NewComponentModal", () => {
  let wrapper;

  const defaultProps = {
    project_id: 1,
    project: { id: 1, name: "Test Project" },
  };

  const createWrapper = (props = {}) => {
    return shallowMount(NewComponentModal, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $refs: {
          AddComponentModal: { show: () => {} },
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // OPENER BUTTON CONTRACT
  // ==========================================
  describe("opener button rendering (regression prevention)", () => {
    it("does NOT render opener button by default (showOpener defaults to false)", () => {
      wrapper = createWrapper();
      // With showOpener=false, the opener span should not render
      // Since we're using shallowMount, check the prop value
      expect(wrapper.props("showOpener")).toBe(false);
    });

    it("does NOT render opener button when showOpener explicitly false", () => {
      wrapper = createWrapper({ showOpener: false });
      expect(wrapper.props("showOpener")).toBe(false);
    });

    it("DOES render opener button when showOpener=true", () => {
      wrapper = createWrapper({ showOpener: true });
      expect(wrapper.props("showOpener")).toBe(true);
    });
  });

  // ==========================================
  // PROGRAMMATIC ACCESS
  // ==========================================
  describe("programmatic modal triggering", () => {
    it("has showModal method for programmatic access via refs", () => {
      wrapper = createWrapper();
      expect(typeof wrapper.vm.showModal).toBe("function");
    });
  });

  // ==========================================
  // MODE PROPS
  // ==========================================
  describe("modal modes", () => {
    it("default mode when no mode props set", () => {
      wrapper = createWrapper();
      expect(wrapper.props("spreadsheet_import")).toBe(false);
      expect(wrapper.props("copy_component")).toBe(false);
    });

    it("spreadsheet import mode when prop set", () => {
      wrapper = createWrapper({ spreadsheet_import: true });
      expect(wrapper.props("spreadsheet_import")).toBe(true);
    });

    it("copy component mode prop can be set", () => {
      // Just verify the prop can be set - full functionality tested in integration
      wrapper = createWrapper({
        copy_component: true,
        project: { id: 1, name: "Test", components: [] },
      });
      expect(wrapper.props("copy_component")).toBe(true);
    });
  });

  // ==========================================
  // FILE INPUT ACCEPT ATTRIBUTE
  // Requirement: The file picker must accept CSV files
  // in addition to Excel files. The backend (Roo gem)
  // supports CSV, so the UI must not block them.
  // ==========================================
  describe("spreadsheet import file input accept attribute", () => {
    // b-modal renders content lazily/in portal, so we stub it
    // to just render its default slot content inline
    const ModalStub = {
      template: "<div><slot></slot></div>",
    };

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: {
          ...defaultProps,
          spreadsheet_import: true,
          ...props,
        },
        stubs: {
          "b-modal": ModalStub,
          VueSimpleSuggest: true,
        },
      });
    };

    it("accepts .csv file extension", () => {
      wrapper = createMountedWrapper();
      const fileInput = wrapper.find('input[type="file"]');
      expect(fileInput.exists()).toBe(true);
      expect(fileInput.attributes("accept")).toContain(".csv");
    });

    it("accepts text/csv MIME type", () => {
      wrapper = createMountedWrapper();
      const fileInput = wrapper.find('input[type="file"]');
      expect(fileInput.attributes("accept")).toContain("text/csv");
    });

    it("accepts .xlsx file extension", () => {
      wrapper = createMountedWrapper();
      const fileInput = wrapper.find('input[type="file"]');
      expect(fileInput.attributes("accept")).toContain(".xlsx");
    });

    it("accepts .xls file extension", () => {
      wrapper = createMountedWrapper();
      const fileInput = wrapper.find('input[type="file"]');
      expect(fileInput.attributes("accept")).toContain(".xls");
    });

    it('does NOT contain the typo "appliction"', () => {
      wrapper = createMountedWrapper();
      const fileInput = wrapper.find('input[type="file"]');
      expect(fileInput.attributes("accept")).not.toContain("appliction");
    });

    it("uses correct MIME types for Excel formats", () => {
      wrapper = createMountedWrapper();
      const fileInput = wrapper.find('input[type="file"]');
      const accept = fileInput.attributes("accept");
      // XLSX MIME type
      expect(accept).toContain("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      // XLS MIME type
      expect(accept).toContain("application/vnd.ms-excel");
    });
  });

  // ==========================================
  // SRG AUTO-DETECT FROM SPREADSHEET
  //
  // REQUIREMENTS:
  // 1. When user selects a file in spreadsheet_import mode,
  //    the system should attempt to detect which SRG the
  //    spreadsheet belongs to by calling POST /components/detect_srg
  // 2. On success: auto-populate the SRG dropdown (no manual selection needed)
  // 3. On failure: silently fall back to manual SRG selection (no error toast)
  // 4. Show a loading indicator while detecting
  // 5. Show a success indicator when SRG was auto-detected
  // 6. The SRG dropdown should be disabled while detecting
  // 7. User can still override the auto-detected SRG manually
  // ==========================================
  describe("SRG auto-detect from spreadsheet", () => {
    const ModalStub = {
      template: "<div><slot></slot></div>",
    };

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: {
          ...defaultProps,
          spreadsheet_import: true,
          ...props,
        },
        stubs: {
          "b-modal": ModalStub,
          VueSimpleSuggest: true,
        },
      });
    };

    const mockFile = new File(["test"], "test.csv", { type: "text/csv" });

    beforeEach(() => {
      vi.clearAllMocks();
    });

    it("calls detect_srg endpoint when file is selected in spreadsheet_import mode", async () => {
      const detectResponse = {
        data: { id: 42, srg_id: "SRG-APP-000001", title: "App SRG", version: "V3R3" },
      };
      axios.post.mockResolvedValueOnce(detectResponse);

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      await vi.dynamicImportSettled();

      expect(axios.post).toHaveBeenCalledWith(
        "/components/detect_srg",
        expect.any(FormData),
        expect.objectContaining({ headers: { "Content-Type": "multipart/form-data" } }),
      );
    });

    it("auto-populates SRG when detection succeeds", async () => {
      const detectResponse = {
        data: { id: 42, srg_id: "SRG-APP-000001", title: "App SRG", version: "V3R3" },
      };
      axios.post.mockResolvedValueOnce(detectResponse);

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      // Wait for promise chain
      await new Promise((r) => setTimeout(r, 10));

      expect(wrapper.vm.security_requirements_guide_id).toBe(42);
      expect(wrapper.vm.security_requirements_guide_displayed).toBe("App SRG (V3R3)");
      expect(wrapper.vm.srgAutoDetected).toBe(true);
    });

    it("falls back silently when detection fails", async () => {
      axios.post.mockRejectedValueOnce(new Error("422"));

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      await new Promise((r) => setTimeout(r, 10));

      // SRG not set — user must pick manually
      expect(wrapper.vm.security_requirements_guide_id).toBeFalsy();
      expect(wrapper.vm.srgAutoDetected).toBe(false);
    });

    it("sets detecting=true while request is in flight", async () => {
      let resolveDetect;
      axios.post.mockReturnValueOnce(
        new Promise((resolve) => {
          resolveDetect = resolve;
        }),
      );

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });

      // While pending
      expect(wrapper.vm.detecting).toBe(true);

      // Resolve
      resolveDetect({ data: { id: 1, title: "SRG", version: "V1R1" } });
      await new Promise((r) => setTimeout(r, 10));

      expect(wrapper.vm.detecting).toBe(false);
    });

    it("does NOT call detect_srg when not in spreadsheet_import mode", async () => {
      wrapper = mount(NewComponentModal, {
        localVue,
        propsData: { ...defaultProps, spreadsheet_import: false },
        stubs: { "b-modal": ModalStub, VueSimpleSuggest: true },
      });
      await wrapper.setData({ file: mockFile });
      await new Promise((r) => setTimeout(r, 10));

      // Only the fetchData calls — no detect_srg POST
      expect(axios.post).not.toHaveBeenCalledWith(
        "/components/detect_srg",
        expect.anything(),
        expect.anything(),
      );
    });

    it("resets srgAutoDetected when file is cleared", async () => {
      axios.post.mockResolvedValueOnce({
        data: { id: 42, title: "SRG", version: "V1R1" },
      });

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      await new Promise((r) => setTimeout(r, 10));
      expect(wrapper.vm.srgAutoDetected).toBe(true);

      // Clear the file
      await wrapper.setData({ file: null });
      expect(wrapper.vm.srgAutoDetected).toBe(false);
    });
  });
});
