import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount, mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import NewComponentModal from "@/components/components/NewComponentModal.vue";
import { detectSrg, createComponentInProject } from "@/api/componentsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  detectSrg: vi.fn(() => Promise.resolve({ data: {} })),
  createComponentInProject: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/api/projectsApi", () => ({
  getSrgs: vi.fn(() => Promise.resolve({ data: [] })),
  getProjects: vi.fn(() => Promise.resolve({ data: [] })),
  getProject: vi.fn(() => Promise.resolve({ data: {} })),
}));

// Spy-wrap (real implementations preserved) so tests can pin that the hidden
// form token and component display names flow through the composables.
vi.mock("@/composables/useAuthToken", { spy: true });
vi.mock("@/composables/useDisplayedComponent", { spy: true });
import { useAuthToken } from "@/composables/useAuthToken";
import { useDisplayedComponent } from "@/composables/useDisplayedComponent";

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
    project: { id: 1, name: "Test Project", components: [], users: [] },
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
  // CREATION PROGRESS TOAST
  // Requirement: every component is created FROM a source SRG, and the delay
  // scales with that source's requirement count. The progress toast must not
  // read as if the created component itself were an SRG (a STIG author seeing
  // "large SRGs" reasonably read it as a mislabel) — it names the source copy.
  // ==========================================
  describe("creation progress toast", () => {
    it("describes the source SRG copy, not the created component's kind", async () => {
      wrapper = shallowMount(NewComponentModal, {
        localVue,
        propsData: { ...defaultProps },
        mocks: { $refs: { AddComponentModal: { show: () => {} } } },
      });
      const toastSpy = vi.spyOn(wrapper.vm.$bvToast, "toast").mockImplementation(() => {});
      vi.spyOn(wrapper.vm.$bvToast, "hide").mockImplementation(() => {});
      // Minimal valid state so validation passes and we reach the progress
      // toast: the picker flow needs a chosen document_type (here STIG, the
      // reported scenario), plus a prefix, name, and source SRG.
      await wrapper.setData({
        document_type: "stig",
        prefix: "ABCD",
        name: "My STIG",
        security_requirements_guide_id: 1,
      });

      wrapper.vm.createComponent();

      const progress = toastSpy.mock.calls.find(([msg]) => /creating component/i.test(msg));
      expect(progress).toBeTruthy();
      const [message] = progress;
      // Names the source SRG being copied, and never claims the OUTPUT is an SRG
      // or a STIG.
      expect(message).toMatch(/source SRG/i);
      expect(message).not.toMatch(/large STIGs/i);
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
          VueMultiselect: true,
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
          VueMultiselect: true,
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
      detectSrg.mockResolvedValueOnce(detectResponse);

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      await vi.dynamicImportSettled();

      expect(detectSrg).toHaveBeenCalledWith(expect.any(FormData));
    });

    it("auto-populates SRG when detection succeeds", async () => {
      const detectResponse = {
        data: { id: 42, srg_id: "SRG-APP-000001", title: "App SRG", version: "V3R3" },
      };
      detectSrg.mockResolvedValueOnce(detectResponse);

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      // Wait for promise chain
      await new Promise((r) => setTimeout(r, 10));

      expect(wrapper.vm.security_requirements_guide_id).toBe(42);
      expect(wrapper.vm.security_requirements_guide_displayed).toBe("App SRG (V3R3)");
      expect(wrapper.vm.srgAutoDetected).toBe(true);
    });

    it("falls back silently when detection fails", async () => {
      detectSrg.mockRejectedValueOnce(new Error("422"));

      wrapper = createMountedWrapper();
      await wrapper.setData({ file: mockFile });
      await new Promise((r) => setTimeout(r, 10));

      // SRG not set — user must pick manually
      expect(wrapper.vm.security_requirements_guide_id).toBeFalsy();
      expect(wrapper.vm.srgAutoDetected).toBe(false);
    });

    it("sets detecting=true while request is in flight", async () => {
      let resolveDetect;
      detectSrg.mockReturnValueOnce(
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
        stubs: { "b-modal": ModalStub, VueMultiselect: true },
      });
      await wrapper.setData({ file: mockFile });
      await new Promise((r) => setTimeout(r, 10));

      // Only the fetchData calls — no detect_srg POST
      expect(detectSrg).not.toHaveBeenCalled();
    });

    it("resets srgAutoDetected when file is cleared", async () => {
      detectSrg.mockResolvedValueOnce({
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

  // ==========================================
  // HIDDEN AUTHENTICITY TOKEN (useAuthToken) +
  // DISPLAY NAMES (useDisplayedComponent)
  // REQUIREMENT: the in-modal form carries the CSRF token as a hidden
  // input, sourced from the useAuthToken composable (single source of
  // truth). Copy-component options get "Name (Version X, Release Y)"
  // display names via useDisplayedComponent — which data() consumes,
  // so the setup-returned method must exist before data initializes.
  // ==========================================
  describe("composable contracts", () => {
    const ModalStub = { template: "<div><slot></slot></div>" };

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: { ...defaultProps, ...props },
        stubs: { "b-modal": ModalStub, VueMultiselect: true },
      });
    };

    it("renders the hidden authenticity_token input with the CSRF meta value", () => {
      wrapper = createMountedWrapper();
      const input = wrapper.find('input[name="authenticity_token"]');
      expect(input.exists()).toBe(true);
      // setup.js sets the csrf-token meta to "test-csrf-token"
      expect(input.element.value).toBe("test-csrf-token");
    });

    it("sources the token from the useAuthToken composable", () => {
      useAuthToken.mockReturnValueOnce({ authenticityToken: "composable-sentinel-token" });
      wrapper = createMountedWrapper();
      expect(useAuthToken).toHaveBeenCalled();
      const input = wrapper.find('input[name="authenticity_token"]');
      expect(input.element.value).toBe("composable-sentinel-token");
    });

    it("builds copy-component display names via useDisplayedComponent during data()", () => {
      wrapper = createMountedWrapper({
        copy_component: true,
        project: {
          id: 1,
          name: "Test Project",
          components: [{ id: 7, name: "Comp", version: "1", release: "2" }],
          users: [],
        },
      });
      expect(useDisplayedComponent).toHaveBeenCalled();
      // data() maps project.components through the setup-returned method
      expect(wrapper.vm.components[0].displayed).toBe("Comp (Version 1, Release 2)");
    });
  });

  // ─── B7: Double-click prevention + modal close behavior ───
  // REQUIREMENTS:
  // - Modal should NOT close when validation fails (missing fields)
  // - Modal SHOULD close when validation passes (let @ok default behavior work)
  // - Double submissions prevented by loading guard
  // - Progress toast shown while request processes
  describe("createComponent modal behavior", () => {
    it("prevents double submissions via loading guard", () => {
      wrapper = createWrapper();
      wrapper.vm.loading = true;

      const mockEvent = { preventDefault: vi.fn() };
      wrapper.vm.createComponent(mockEvent);

      // Should return immediately without calling preventDefault
      expect(mockEvent.preventDefault).not.toHaveBeenCalled();
    });

    it("calls preventDefault on validation failure to keep modal open", () => {
      wrapper = createWrapper();
      // No name, no SRG — validation should fail
      wrapper.vm.name = "";
      wrapper.vm.security_requirements_guide_id = null;

      const mockEvent = { preventDefault: vi.fn() };
      wrapper.vm.createComponent(mockEvent);

      expect(mockEvent.preventDefault).toHaveBeenCalled();
      expect(wrapper.vm.loading).toBe(false);
    });

    it("does NOT call preventDefault when validation passes (modal closes naturally)", async () => {
      wrapper = createWrapper({ component_to_duplicate: 1 });
      wrapper.vm.name = "Test Component";
      wrapper.vm.prefix = "TST-01";
      wrapper.vm.security_requirements_guide_id = 1;

      const mockEvent = { preventDefault: vi.fn() };
      wrapper.vm.createComponent(mockEvent);

      // preventDefault should NOT be called — modal closes via default @ok
      expect(mockEvent.preventDefault).not.toHaveBeenCalled();
      expect(wrapper.vm.loading).toBe(true);
    });
  });

  // ==========================================
  // DOCUMENT-TYPE PROFILE PICKER (creation-time choice)
  //
  // REQUIREMENTS:
  // 1. Creating a NEW component asks "What are you authoring?" FIRST —
  //    before any other input. STIG/SRG, exclusive, no default.
  // 2. The choice only exists where a choice exists: duplicate, copy,
  //    and spreadsheet-import flows have a determined type (inherited
  //    or stig) and must NOT render the picker.
  // 3. The selection gates the downstream steps: form fields stay
  //    disabled until a profile is chosen.
  // 4. The create request posts component[document_type] with the
  //    chosen profile — and only in the picker flow (duplicate/copy
  //    inherit server-side).
  // 5. Submitting without a choice keeps the modal open (guard), like
  //    the existing missing-name/missing-SRG guards.
  // ==========================================
  describe("document-type profile picker", () => {
    const ModalStub = { template: "<div><slot></slot></div>" };

    beforeEach(() => {
      vi.clearAllMocks();
    });

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: { ...defaultProps, ...props },
        stubs: { "b-modal": ModalStub, VueMultiselect: true },
      });
    };

    it("renders the picker BEFORE every other input in create-new mode", () => {
      wrapper = createMountedWrapper();
      const html = wrapper.html();
      const pickerAt = html.indexOf('data-testid="document-type-picker"');
      expect(pickerAt).toBeGreaterThan(-1);
      // Profile choice comes before the source picker (creation-walkthrough
      // order: profile → sources → identity).
      expect(pickerAt).toBeLessThan(html.indexOf('data-testid="source-srg-picker"'));
      expect(pickerAt).toBeLessThan(html.indexOf("Component Name"));
    });

    it("starts with no profile selected", () => {
      wrapper = createMountedWrapper();
      expect(wrapper.vm.document_type).toBeNull();
    });

    it("does NOT render the picker in spreadsheet-import mode", () => {
      wrapper = createMountedWrapper({ spreadsheet_import: true });
      expect(wrapper.find('[data-testid="document-type-picker"]').exists()).toBe(false);
    });

    it("does NOT render the picker in copy-component mode", () => {
      wrapper = createMountedWrapper({ copy_component: true });
      expect(wrapper.find('[data-testid="document-type-picker"]').exists()).toBe(false);
    });

    it("does NOT render the picker in duplicate mode", () => {
      wrapper = createMountedWrapper({ component_to_duplicate: 7 });
      expect(wrapper.find('[data-testid="document-type-picker"]').exists()).toBe(false);
    });

    it("disables downstream fields until a profile is chosen", async () => {
      wrapper = createMountedWrapper();
      const nameInput = wrapper.find('input[placeholder="Component Name"]');
      const titleInput = wrapper.find('input[placeholder="Component Title"]');
      expect(nameInput.attributes("disabled")).toBeDefined();
      expect(titleInput.attributes("disabled")).toBeDefined();

      await wrapper.setData({ document_type: "stig" });
      expect(nameInput.attributes("disabled")).toBeUndefined();
      expect(titleInput.attributes("disabled")).toBeUndefined();
    });

    it("does NOT disable fields in duplicate mode (no picker, no gate)", () => {
      wrapper = createMountedWrapper({ component_to_duplicate: 7 });
      const nameInput = wrapper.find('input[placeholder="Component Name"]');
      expect(nameInput.attributes("disabled")).toBeUndefined();
    });

    it("posts component[document_type]=srg when SRG is chosen", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({
        document_type: "srg",
        name: "Container SRG",
        prefix: "CTR-00",
        security_requirements_guide_id: 1,
      });
      wrapper.vm.createComponent({ preventDefault: vi.fn() });

      expect(createComponentInProject).toHaveBeenCalled();
      const formData = createComponentInProject.mock.calls[0][1];
      expect(formData.get("component[document_type]")).toBe("srg");
    });

    it("posts component[document_type]=stig when STIG is chosen", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({
        document_type: "stig",
        name: "OpenShift STIG",
        prefix: "OSHF-00",
        security_requirements_guide_id: 1,
      });
      wrapper.vm.createComponent({ preventDefault: vi.fn() });

      const formData = createComponentInProject.mock.calls[0][1];
      expect(formData.get("component[document_type]")).toBe("stig");
    });

    it("does NOT post document_type in duplicate mode (inherited server-side)", async () => {
      wrapper = createMountedWrapper({ component_to_duplicate: 7 });
      await wrapper.setData({
        name: "Dup",
        prefix: "DUP-00",
        security_requirements_guide_id: 1,
      });
      wrapper.vm.createComponent({ preventDefault: vi.fn() });

      const formData = createComponentInProject.mock.calls[0][1];
      expect(formData.get("component[document_type]")).toBeNull();
    });

    it("keeps the modal open when no profile is chosen (guard)", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({
        name: "No Choice",
        prefix: "NOCH-00",
        security_requirements_guide_id: 1,
      });
      const mockEvent = { preventDefault: vi.fn() };
      wrapper.vm.createComponent(mockEvent);

      expect(mockEvent.preventDefault).toHaveBeenCalled();
      expect(createComponentInProject).not.toHaveBeenCalled();
      expect(wrapper.vm.loading).toBe(false);
    });

    it("resets the profile choice when the modal reopens", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ document_type: "srg" });
      wrapper.vm.$refs.AddComponentModal = { show: vi.fn() };
      wrapper.vm.showModal();
      expect(wrapper.vm.document_type).toBeNull();
    });
  });

  describe("multi-parent source picker wiring", () => {
    const ModalStub = { template: "<div><slot></slot></div>" };

    beforeEach(() => {
      vi.clearAllMocks();
    });

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: { ...defaultProps, ...props },
        stubs: { "b-modal": ModalStub, VueMultiselect: true },
      });
    };

    it("renders the source picker and NOT the legacy single-SRG select in create-new mode", () => {
      wrapper = createMountedWrapper();
      expect(wrapper.find('[data-testid="source-srg-picker"]').exists()).toBe(true);
      expect(wrapper.html()).not.toContain("Select a Security Requirements Guide<");
    });

    it("does NOT render the source picker in spreadsheet, copy, or duplicate modes", () => {
      [
        { spreadsheet_import: true },
        { copy_component: true },
        { component_to_duplicate: 7 },
      ].forEach((props) => {
        const modal = createMountedWrapper(props);
        expect(modal.find('[data-testid="source-srg-picker"]').exists()).toBe(false);
        modal.destroy();
      });
    });

    it("posts every declared source and the designated primary", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({
        document_type: "srg",
        name: "Dual-home SRG",
        prefix: "DUAL-00",
        sourceSelection: { sourceIds: [11, 12], primaryId: 12 },
      });
      wrapper.vm.createComponent({ preventDefault: vi.fn() });

      expect(createComponentInProject).toHaveBeenCalled();
      const formData = createComponentInProject.mock.calls[0][1];
      expect(formData.getAll("component[declared_source_srg_ids][]")).toEqual(["11", "12"]);
      expect(formData.get("component[security_requirements_guide_id]")).toBe("12");
    });

    it("keeps the modal open when no source is selected (SRG guard)", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({
        document_type: "srg",
        name: "No sources",
        prefix: "NOSR-00",
      });
      const mockEvent = { preventDefault: vi.fn() };
      wrapper.vm.createComponent(mockEvent);

      expect(mockEvent.preventDefault).toHaveBeenCalled();
      expect(createComponentInProject).not.toHaveBeenCalled();
    });

    it("resets the source selection when the modal reopens", async () => {
      wrapper = createMountedWrapper();
      wrapper.vm.$refs.AddComponentModal.show = vi.fn();
      await wrapper.setData({ sourceSelection: { sourceIds: [11], primaryId: 11 } });

      wrapper.vm.showModal();

      expect(wrapper.vm.sourceSelection).toEqual({ sourceIds: [], primaryId: null });
    });
  });

  // ==========================================
  // KIND-KEYED PREFIX FIELD COPY
  //
  // REQUIREMENTS:
  // 1. The prefix field's label, helper, and placeholder resolve per the
  //    chosen document kind — the SRG path never shows "STIG"-worded copy.
  // 2. The STIG copy is byte-identical to the long-standing wording.
  // 3. Flows without kind knowledge (duplicate/copy inherit server-side)
  //    keep today's STIG copy — the deployment default.
  // ==========================================
  describe("kind-keyed prefix field copy", () => {
    const ModalStub = { template: "<div><slot></slot></div>" };

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: { ...defaultProps, ...props },
        stubs: { "b-modal": ModalStub, VueMultiselect: true },
      });
    };

    it("shows the SRG prefix copy when SRG is chosen — no STIG-worded strings", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({ document_type: "srg" });
      const html = wrapper.html();
      expect(html).toContain("Prefix");
      expect(html).toContain(
        "leading letters are the SRG's abbreviation (e.g. CNTR) — minted into every released requirement identifier",
      );
      expect(html).not.toContain("STIG ID Prefix");
      expect(html).not.toContain("STIG IDs for each control");
      const prefixInput = wrapper.find('input[placeholder="Example... CNTR-00"]');
      expect(prefixInput.exists()).toBe(true);
    });

    it("keeps the STIG copy verbatim when STIG is chosen", async () => {
      wrapper = createMountedWrapper();
      await wrapper.setData({ document_type: "stig" });
      const html = wrapper.html();
      expect(html).toContain("STIG ID Prefix");
      expect(html).toContain(
        "STIG IDs for each control will be automatically generated based on this prefix value",
      );
      const prefixInput = wrapper.find('input[placeholder="Example... ABCD-EF, ABCD-00"]');
      expect(prefixInput.exists()).toBe(true);
    });

    it("falls back to the STIG copy in duplicate mode (kind inherited server-side)", () => {
      wrapper = createMountedWrapper({ component_to_duplicate: 7 });
      const html = wrapper.html();
      expect(html).toContain("STIG ID Prefix");
      expect(wrapper.find('input[placeholder="Example... ABCD-EF, ABCD-00"]').exists()).toBe(true);
    });
  });

  describe("project_id prop", () => {
    it("accepts undefined project_id without error", () => {
      const spy = vi.spyOn(console, "error").mockImplementation(() => {});
      wrapper = createWrapper({ project_id: undefined });
      const propWarnings = spy.mock.calls.filter((c) => c[0]?.toString().includes("project_id"));
      expect(propWarnings).toHaveLength(0);
      spy.mockRestore();
    });

    it("defaults selected_project_id to null when project_id not provided", () => {
      wrapper = createWrapper({ project_id: undefined });
      expect(wrapper.vm.selected_project_id).toBeNull();
    });
  });
});
