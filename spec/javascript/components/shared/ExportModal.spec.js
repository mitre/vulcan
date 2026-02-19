import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ExportModal from "@/components/shared/ExportModal.vue";

/**
 * ExportModal Component Tests
 *
 * REQUIREMENTS:
 *
 * 1. FORMAT SELECTION (Radio Buttons):
 *    - Shows all export formats: DISA Excel, Excel, InSpec, XCCDF
 *    - Each format has a brief description
 *    - Single selection via radio buttons
 *    - No format pre-selected by default
 *
 * 2. COMPONENT SELECTION:
 *    - Shows "All X components" checkbox
 *    - Individual component checkboxes below
 *    - "All" toggles all components
 *    - Indeterminate state when some selected
 *    - Single component: auto-selected, simplified view
 *
 * 3. EXPORT BUTTON:
 *    - Disabled when no format selected
 *    - Disabled when no components selected
 *    - Enabled only when BOTH format AND components selected
 *
 * 4. EMITS:
 *    - 'export': { type: string, componentIds: number[] }
 *    - 'cancel': user cancelled
 *    - 'update:visible': for v-model support
 *
 * 5. MODAL BEHAVIOR:
 *    - Cancel closes modal
 *    - Export closes modal after emitting
 *    - Backdrop/escape closes modal
 */
describe("ExportModal", () => {
  let wrapper;

  const singleComponent = [{ id: 1, name: "My Component", version: "1", release: "1" }];

  const multipleComponents = [
    { id: 1, name: "Component A", version: "1", release: "1" },
    { id: 2, name: "Component B", version: "2", release: "1" },
    { id: 3, name: "Component C", version: "1", release: "2" },
  ];

  const createWrapper = (props = {}) => {
    return mount(ExportModal, {
      localVue,
      propsData: {
        components: multipleComponents,
        visible: true,
        ...props,
      },
      stubs: {
        "b-modal": {
          template: `
            <div class="modal" :class="{ 'd-block': visible, 'd-none': !visible }">
              <div class="modal-title">{{ title }}</div>
              <slot></slot>
              <slot name="modal-footer"></slot>
            </div>
          `,
          props: ["visible", "title", "centered", "size"],
          methods: {
            hide() {
              this.$emit("hidden");
            },
          },
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
  // FORMAT SELECTION
  // ==========================================
  describe("format selection", () => {
    it("renders all 5 export format options", () => {
      wrapper = createWrapper();
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.length).toBe(5);
    });

    it("shows DISA Excel option with description", () => {
      wrapper = createWrapper();
      const text = wrapper.text();
      expect(text).toContain("DISA Excel");
      expect(text).toContain("DoD/DISA format");
    });

    it("shows Excel option with description", () => {
      wrapper = createWrapper();
      const text = wrapper.text();
      expect(text).toContain("Excel");
      expect(text).toContain("Standard spreadsheet");
    });

    it("shows InSpec option with description", () => {
      wrapper = createWrapper();
      const text = wrapper.text();
      expect(text).toContain("InSpec");
      expect(text).toContain("Chef InSpec profile");
    });

    it("shows XCCDF-Benchmark option with description", () => {
      wrapper = createWrapper();
      const text = wrapper.text();
      expect(text).toContain("XCCDF-Benchmark");
      expect(text).toContain("SCAP XML format");
    });

    it("has no format selected by default", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedFormat).toBe(null);
    });

    it("updates selectedFormat when radio clicked", async () => {
      wrapper = createWrapper();
      const excelRadio = wrapper.find('input[value="excel"]');
      await excelRadio.setChecked();
      expect(wrapper.vm.selectedFormat).toBe("excel");
    });
  });

  // ==========================================
  // COMPONENT SELECTION - MULTIPLE
  // ==========================================
  describe("component selection (multiple)", () => {
    it('shows "All X components" checkbox', () => {
      wrapper = createWrapper({ components: multipleComponents });
      expect(wrapper.text()).toContain("All 3 components");
    });

    it("shows individual component checkboxes", () => {
      wrapper = createWrapper({ components: multipleComponents });
      expect(wrapper.text()).toContain("Component A");
      expect(wrapper.text()).toContain("Component B");
      expect(wrapper.text()).toContain("Component C");
    });

    it("has no components selected by default", () => {
      wrapper = createWrapper({ components: multipleComponents });
      expect(wrapper.vm.selectedComponentIds.length).toBe(0);
    });

    it('checking "All" selects all components', async () => {
      wrapper = createWrapper({ components: multipleComponents });
      const allCheckbox = wrapper.find('[data-testid="select-all"]');
      await allCheckbox.find("input").setChecked(true);
      expect(wrapper.vm.selectedComponentIds).toEqual([1, 2, 3]);
    });

    it('unchecking "All" deselects all components', async () => {
      wrapper = createWrapper({ components: multipleComponents });
      // First select all
      wrapper.vm.selectedComponentIds = [1, 2, 3];
      await wrapper.vm.$nextTick();
      // Then uncheck all
      wrapper.vm.toggleSelectAll(false);
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedComponentIds).toEqual([]);
    });

    it("shows indeterminate state when some components selected", async () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedComponentIds = [1];
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.someSelected).toBe(true);
      expect(wrapper.vm.allSelected).toBe(false);
    });

    it("allSelected is true when all components checked", async () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedComponentIds = [1, 2, 3];
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.allSelected).toBe(true);
    });
  });

  // ==========================================
  // TWO-PANEL LAYOUT (Option B)
  // ==========================================
  //
  // REQUIREMENTS:
  // 1. When components are visible, modal uses two-panel side-by-side layout
  //    - Left panel: Purpose + Format + Column Picker (config-panel)
  //    - Right panel: Components with two-column checkbox grid (component-panel)
  // 2. Modal uses xl size when two-panel layout is active
  // 3. Component checkboxes render in a two-column grid (col-6) inside right panel
  // 4. When hideComponentSelection is true, single-column layout (no right panel)
  // 5. Single component still shows simplified view in right panel (no checkbox grid)
  //
  describe("two-panel layout", () => {
    it("shows config-panel and component-panel when components are visible", () => {
      wrapper = createWrapper({ components: multipleComponents });
      expect(wrapper.find('[data-testid="config-panel"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="component-panel"]').exists()).toBe(true);
    });

    it("renders component checkboxes in a two-column grid", () => {
      wrapper = createWrapper({ components: multipleComponents });
      const grid = wrapper.find('[data-testid="component-list"]');
      expect(grid.exists()).toBe(true);
      const cols = grid.findAll(".col-6");
      expect(cols.length).toBe(multipleComponents.length);
    });

    it("does not show component-panel when hideComponentSelection is true", () => {
      wrapper = createWrapper({ hideComponentSelection: true, components: singleComponent });
      expect(wrapper.find('[data-testid="component-panel"]').exists()).toBe(false);
    });

    it("shows single component in component-panel without checkbox grid", () => {
      wrapper = createWrapper({ components: singleComponent });
      expect(wrapper.find('[data-testid="component-panel"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="component-list"]').exists()).toBe(false);
      expect(wrapper.find('[data-testid="single-mode"]').exists()).toBe(true);
    });

    it("uses xl modal size when two-panel layout active", () => {
      wrapper = createWrapper({ components: multipleComponents });
      expect(wrapper.vm.modalSize).toBe("xl");
    });

    it("uses default modal size when components hidden", () => {
      wrapper = createWrapper({ hideComponentSelection: true, components: singleComponent });
      expect(wrapper.vm.modalSize).toBeNull();
    });
  });

  // ==========================================
  // COMPONENT SELECTION - SINGLE
  // ==========================================
  describe("component selection (single)", () => {
    it("auto-selects single component", () => {
      wrapper = createWrapper({ components: singleComponent, visible: true });
      // immediate: true watcher auto-selects on creation
      expect(wrapper.vm.selectedComponentIds).toEqual([1]);
    });

    it("shows simplified view for single component", () => {
      wrapper = createWrapper({ components: singleComponent });
      // Should not show "All X components" checkbox for single
      expect(wrapper.text()).not.toContain("All 1 components");
    });

    it("shows component name in single component mode", () => {
      wrapper = createWrapper({ components: singleComponent });
      expect(wrapper.text()).toContain("My Component");
    });
  });

  // ==========================================
  // EXPORT BUTTON STATE
  // ==========================================
  describe("export button state", () => {
    it("is disabled when no format selected", () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedComponentIds = [1, 2];
      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      expect(exportBtn.attributes("disabled")).toBeDefined();
    });

    it("is disabled when no components selected", async () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedFormat = "excel";
      await wrapper.vm.$nextTick();
      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      expect(exportBtn.attributes("disabled")).toBeDefined();
    });

    it("is enabled when format AND components selected", async () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedFormat = "excel";
      wrapper.vm.selectedComponentIds = [1];
      await wrapper.vm.$nextTick();
      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      expect(exportBtn.attributes("disabled")).toBeUndefined();
    });
  });

  // ==========================================
  // EXPORT EVENT
  // ==========================================
  describe("export event", () => {
    it("emits export with type and componentIds", async () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedFormat = "disa_excel";
      wrapper.vm.selectedComponentIds = [1, 3];
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      expect(wrapper.emitted("export")).toBeTruthy();
      expect(wrapper.emitted("export")[0]).toEqual([
        {
          type: "disa_excel",
          componentIds: [1, 3],
        },
      ]);
    });

    it("emits update:visible false after export", async () => {
      wrapper = createWrapper({ components: multipleComponents });
      wrapper.vm.selectedFormat = "excel";
      wrapper.vm.selectedComponentIds = [1];
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      expect(wrapper.emitted("update:visible")).toBeTruthy();
      expect(wrapper.emitted("update:visible")[0]).toEqual([false]);
    });

    it("works with single component auto-selection", async () => {
      wrapper = createWrapper({ components: singleComponent, visible: true });
      // immediate: true watcher auto-selects component on creation
      wrapper.vm.selectedFormat = "inspec";
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      expect(wrapper.emitted("export")[0]).toEqual([
        {
          type: "inspec",
          componentIds: [1],
        },
      ]);
    });
  });

  // ==========================================
  // CANCEL
  // ==========================================
  describe("cancel", () => {
    it("Cancel button emits cancel event", async () => {
      wrapper = createWrapper();
      const cancelBtn = wrapper.find('[data-testid="cancel-btn"]');
      await cancelBtn.trigger("click");
      expect(wrapper.emitted("cancel")).toBeTruthy();
    });

    it("Cancel button emits update:visible false", async () => {
      wrapper = createWrapper();
      const cancelBtn = wrapper.find('[data-testid="cancel-btn"]');
      await cancelBtn.trigger("click");
      expect(wrapper.emitted("update:visible")[0]).toEqual([false]);
    });

    it("onHidden emits cancel and closes modal", () => {
      wrapper = createWrapper();
      wrapper.vm.onHidden();
      expect(wrapper.emitted("cancel")).toBeTruthy();
      expect(wrapper.emitted("update:visible")[0]).toEqual([false]);
    });
  });

  // ==========================================
  // MODAL TITLE
  // ==========================================
  describe("modal title", () => {
    it('shows "Export Project" as default title', () => {
      wrapper = createWrapper();
      expect(wrapper.find(".modal-title").text()).toBe("Export Project");
    });

    it("uses custom title when provided", () => {
      wrapper = createWrapper({ title: "Download Components" });
      expect(wrapper.find(".modal-title").text()).toBe("Download Components");
    });
  });

  // ==========================================
  // FORMAT FILTERING (formats prop)
  // ==========================================
  describe("format filtering", () => {
    it("shows all formats when formats prop is null (default)", () => {
      wrapper = createWrapper();
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.length).toBe(5);
    });

    it("shows only specified formats when formats prop provided", () => {
      wrapper = createWrapper({ formats: ["xccdf"] });
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.length).toBe(1);
      expect(wrapper.text()).toContain("XCCDF");
      expect(wrapper.text()).not.toContain("DISA Excel");
      expect(wrapper.text()).not.toContain("InSpec");
    });

    it("shows multiple specified formats", () => {
      wrapper = createWrapper({ formats: ["xccdf", "csv"] });
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.length).toBe(2);
      expect(wrapper.text()).toContain("XCCDF");
      expect(wrapper.text()).toContain("CSV");
    });

    it("auto-selects format when only one format available", async () => {
      wrapper = createWrapper({ formats: ["xccdf"], visible: false });
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedFormat).toBe("xccdf");
    });

    it("does not auto-select when multiple formats available", async () => {
      wrapper = createWrapper({ formats: ["xccdf", "inspec"], visible: false });
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedFormat).toBe(null);
    });
  });

  // ==========================================
  // HIDE COMPONENT SELECTION
  // ==========================================
  describe("hideComponentSelection", () => {
    it("shows component section by default", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Components");
    });

    it("hides component section when hideComponentSelection is true", () => {
      wrapper = createWrapper({ hideComponentSelection: true, components: singleComponent });
      expect(wrapper.text()).not.toContain("Components");
    });

    it("still auto-selects single component when hidden", async () => {
      wrapper = createWrapper({
        hideComponentSelection: true,
        components: singleComponent,
        visible: false,
      });
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedComponentIds).toEqual([1]);
    });
  });

  // ==========================================
  // RESET ON OPEN
  // ==========================================
  describe("reset on open", () => {
    it("resets format selection when modal opens", async () => {
      wrapper = createWrapper({ visible: false });
      wrapper.vm.selectedFormat = "excel";
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedFormat).toBe(null);
    });

    it("resets component selection when modal opens (multiple)", async () => {
      wrapper = createWrapper({ components: multipleComponents, visible: false });
      wrapper.vm.selectedComponentIds = [1, 2];
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedComponentIds).toEqual([]);
    });

    it("auto-selects single component when modal opens", async () => {
      wrapper = createWrapper({ components: singleComponent, visible: false });
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedComponentIds).toEqual([1]);
    });
  });

  // ==========================================
  // COLUMN PICKER (CSV Export)
  // ==========================================
  describe("column picker", () => {
    // REQUIREMENTS:
    // 1. Column picker section appears ONLY when CSV format is selected
    // 2. Column picker is NOT shown for XCCDF or other formats
    // 3. Each column has a checkbox, label, and example value
    // 4. Default columns are pre-checked on open
    // 5. Optional columns are unchecked by default
    // 6. "Select All" checks all columns
    // 7. "Defaults" resets to default column selection
    // 8. Export event includes selectedColumns array
    // 9. columnDefinitions prop controls which columns are available

    const stigColumns = [
      { key: "rule_id", header: "Rule ID", example: "SV-203591r557031_rule", default: true },
      { key: "version", header: "STIG ID", example: "RHEL-09-000001", default: true },
      { key: "srg_id", header: "SRG ID", example: "SRG-OS-000001-GPOS-00001", default: true },
      { key: "vuln_id", header: "Vuln ID", example: "V-203591", default: true },
      { key: "rule_severity", header: "Severity", example: "medium", default: true },
      { key: "title", header: "Title", example: "The operating system must…", default: true },
      { key: "status", header: "Status", example: "Applicable - Configurable", default: false },
      { key: "rule_weight", header: "Weight", example: "10.0", default: false },
    ];

    it("does not show column picker when no format selected", () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      expect(wrapper.text()).not.toContain("Columns");
    });

    it("does not show column picker when XCCDF selected", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      wrapper.vm.selectedFormat = "xccdf";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).not.toContain("Columns");
    });

    it("shows column picker when CSV selected", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).toContain("Columns");
    });

    it("shows all column labels", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).toContain("Rule ID");
      expect(wrapper.text()).toContain("STIG ID");
      expect(wrapper.text()).toContain("Status");
      expect(wrapper.text()).toContain("Weight");
    });

    it("shows example values for columns", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).toContain("SV-203591r557031_rule");
      expect(wrapper.text()).toContain("RHEL-09-000001");
    });

    it("pre-checks default columns", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns, visible: false });
      await wrapper.setProps({ visible: true });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      // Default columns should be selected
      expect(wrapper.vm.selectedColumns).toContain("rule_id");
      expect(wrapper.vm.selectedColumns).toContain("version");
      expect(wrapper.vm.selectedColumns).toContain("rule_severity");
    });

    it("does not pre-check optional columns", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns, visible: false });
      await wrapper.setProps({ visible: true });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedColumns).not.toContain("status");
      expect(wrapper.vm.selectedColumns).not.toContain("rule_weight");
    });

    it("selectAllColumns selects all columns", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      wrapper.vm.selectAllColumns();
      expect(wrapper.vm.selectedColumns.length).toBe(stigColumns.length);
    });

    it("resetColumnsToDefaults restores default selection", async () => {
      wrapper = createWrapper({ columnDefinitions: stigColumns });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      // Select all first
      wrapper.vm.selectAllColumns();
      expect(wrapper.vm.selectedColumns.length).toBe(stigColumns.length);
      // Reset to defaults
      wrapper.vm.resetColumnsToDefaults();
      const defaultKeys = stigColumns.filter((c) => c.default).map((c) => c.key);
      expect(wrapper.vm.selectedColumns).toEqual(defaultKeys);
    });

    it("includes selectedColumns in export event for CSV", async () => {
      wrapper = createWrapper({
        columnDefinitions: stigColumns,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const emitted = wrapper.emitted("export");
      expect(emitted).toBeTruthy();
      expect(emitted[0][0].columns).toBeDefined();
      expect(emitted[0][0].columns).toContain("rule_id");
    });

    it("does not include columns in export event for XCCDF", async () => {
      wrapper = createWrapper({
        formats: ["xccdf"],
        components: singleComponent,
        visible: true,
      });
      // immediate watcher auto-selects format and component
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const emitted = wrapper.emitted("export");
      expect(emitted[0][0].columns).toBeUndefined();
    });

    it("does not show column picker when columnDefinitions not provided", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).not.toContain("Columns");
    });
  });

  // ==========================================
  // MODE SELECTION (Phase 4: mode-first flow)
  // ==========================================
  //
  // REQUIREMENTS:
  // 1. When availableModes prop is provided, a "Purpose" radio group appears
  // 2. Format section is hidden until a mode is selected (progressive disclosure)
  // 3. All 4 standard formats are shown when mode is selected; incompatible ones disabled
  // 4. Single-format modes auto-select the format
  // 5. Changing mode clears incompatible format selection
  // 6. Export payload includes mode when mode-aware
  // 7. Disabled formats show hint text about which mode enables them
  // 8. Inline summary shows mode + format + component count
  // 9. Without availableModes, legacy behavior is unchanged

  const allModes = ["working_copy", "vendor_submission", "published_stig", "backup"];

  describe("mode selection", () => {
    it("does not show mode section when availableModes is null", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).not.toContain("Purpose");
      expect(wrapper.find('[data-testid="mode-group"]').exists()).toBe(false);
    });

    it("shows mode section when availableModes provided", () => {
      wrapper = createWrapper({ availableModes: allModes });
      expect(wrapper.text()).toContain("Purpose");
      expect(wrapper.find('[data-testid="mode-group"]').exists()).toBe(true);
    });

    it("renders all 4 mode options with labels and descriptions", () => {
      wrapper = createWrapper({ availableModes: allModes });
      expect(wrapper.text()).toContain("Working Copy");
      expect(wrapper.text()).toContain("Internal review and editing");
      expect(wrapper.text()).toContain("DISA Vendor Submission");
      expect(wrapper.text()).toContain("Submit to DISA for review");
      expect(wrapper.text()).toContain("STIG-Ready Publish Draft");
      expect(wrapper.text()).toContain("Draft STIG-Ready content for DISA review");
      expect(wrapper.text()).toContain("Backup");
      expect(wrapper.text()).toContain("Full-fidelity archive of all rules");
    });

    it("has no mode selected by default", () => {
      wrapper = createWrapper({ availableModes: allModes });
      expect(wrapper.vm.selectedMode).toBe(null);
    });

    it("hides format section until mode is selected (progressive disclosure)", () => {
      wrapper = createWrapper({ availableModes: allModes });
      // Format section should NOT be visible before mode selection
      expect(wrapper.find('[data-testid="format-group"]').exists()).toBe(false);
    });

    it("shows format section after mode is selected", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      expect(wrapper.find('[data-testid="format-group"]').exists()).toBe(true);
    });

    it("shows all 5 standard formats in mode-aware view", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      const radios = wrapper.findAll('[data-testid="format-group"] input[type="radio"]');
      expect(radios.length).toBe(5);
      expect(wrapper.text()).toContain("CSV");
      expect(wrapper.text()).toContain("Excel");
      expect(wrapper.text()).toContain("XCCDF");
      expect(wrapper.text()).toContain("InSpec");
      expect(wrapper.text()).toContain("JSON Archive");
    });

    it("does NOT show disa_excel in mode-aware view", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).not.toContain("DISA Excel");
    });
  });

  // ==========================================
  // FORMAT ENABLE/DISABLE BY MODE
  // ==========================================
  describe("format compatibility by mode", () => {
    it("enables csv and excel for working_copy mode", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.isFormatEnabled("csv")).toBe(true);
      expect(wrapper.vm.isFormatEnabled("excel")).toBe(true);
      expect(wrapper.vm.isFormatEnabled("xccdf")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("inspec")).toBe(false);
    });

    it("enables only excel for vendor_submission mode", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "vendor_submission";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.isFormatEnabled("csv")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("excel")).toBe(true);
      expect(wrapper.vm.isFormatEnabled("xccdf")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("inspec")).toBe(false);
    });

    it("enables xccdf and inspec for published_stig mode", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "published_stig";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.isFormatEnabled("csv")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("excel")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("xccdf")).toBe(true);
      expect(wrapper.vm.isFormatEnabled("inspec")).toBe(true);
    });

    it("enables only json_archive for backup mode", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.isFormatEnabled("csv")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("excel")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("xccdf")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("inspec")).toBe(false);
      expect(wrapper.vm.isFormatEnabled("json_archive")).toBe(true);
    });

    it("shows hint text for disabled formats", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      // XCCDF should show hint about which modes support it
      expect(wrapper.text()).toContain("Available in");
      expect(wrapper.text()).toContain("STIG-Ready Publish Draft");
    });

    it("shows mode-specific description override for vendor_submission + excel", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "vendor_submission";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).toContain("DISA 17-column strict template");
    });

    it("shows mode-specific description override for backup + json_archive", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();
      expect(wrapper.text()).toContain("Full-fidelity archive preserving all data");
    });
  });

  // ==========================================
  // AUTO-SELECT AND MODE SWITCHING
  // ==========================================
  describe("auto-select and mode switching", () => {
    it("auto-selects format when mode has only one valid format (vendor_submission)", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "vendor_submission";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedFormat).toBe("excel");
    });

    it("auto-selects format when mode has only one valid format (backup)", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedFormat).toBe("json_archive");
    });

    it("does not auto-select when mode has multiple formats (working_copy)", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedFormat).toBe(null);
    });

    it("clears format when switching to mode that does not support it", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();
      // Switch to published_stig — csv is not valid
      wrapper.vm.selectedMode = "published_stig";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedFormat).toBe(null);
    });

    it("clears format when switching to mode that no longer supports it", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "published_stig";
      await wrapper.vm.$nextTick();
      wrapper.vm.selectedFormat = "xccdf";
      await wrapper.vm.$nextTick();
      // Switch to backup — xccdf is NOT valid in backup (only json_archive)
      // Backup has exactly 1 format, so it auto-selects json_archive
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedFormat).toBe("json_archive");
    });

    it("resets mode when modal reopens", async () => {
      wrapper = createWrapper({ availableModes: allModes, visible: true });
      wrapper.vm.selectedMode = "published_stig";
      await wrapper.vm.$nextTick();
      // Close and reopen
      await wrapper.setProps({ visible: false });
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedMode).toBe(null);
    });
  });

  // ==========================================
  // EXPORT PAYLOAD WITH MODE
  // ==========================================
  describe("export payload with mode", () => {
    it("includes mode in export event when mode-aware", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "vendor_submission";
      await wrapper.vm.$nextTick();
      // vendor_submission auto-selects excel

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      expect(wrapper.emitted("export")).toBeTruthy();
      expect(wrapper.emitted("export")[0]).toEqual([
        {
          type: "excel",
          mode: "vendor_submission",
          componentIds: [1],
        },
      ]);
    });

    it("does not include mode when not mode-aware (legacy)", async () => {
      wrapper = createWrapper({
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedFormat = "xccdf";
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const payload = wrapper.emitted("export")[0][0];
      expect(payload.mode).toBeUndefined();
      expect(payload.type).toBe("xccdf");
    });

    it("includes mode + columns for csv in working_copy mode", async () => {
      const cols = [
        { key: "rule_id", header: "Rule ID", example: "SV-123", default: true },
        { key: "title", header: "Title", example: "Title...", default: true },
      ];
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        columnDefinitions: cols,
        visible: true,
      });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      wrapper.vm.selectedFormat = "csv";
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const payload = wrapper.emitted("export")[0][0];
      expect(payload.mode).toBe("working_copy");
      expect(payload.type).toBe("csv");
      expect(payload.columns).toContain("rule_id");
    });
  });

  // ==========================================
  // INLINE SUMMARY
  // ==========================================
  describe("inline summary", () => {
    it("does not show summary without mode selection", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[data-testid="export-summary"]').exists()).toBe(false);
    });

    it("does not show summary when mode but no format selected", async () => {
      wrapper = createWrapper({ availableModes: allModes });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();
      // working_copy has 2 formats, no auto-select
      expect(wrapper.find('[data-testid="export-summary"]').exists()).toBe(false);
    });

    it("shows summary when mode and format selected", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "vendor_submission";
      await wrapper.vm.$nextTick();
      // auto-selects excel, single component auto-selected

      const summary = wrapper.find('[data-testid="export-summary"]');
      expect(summary.exists()).toBe(true);
      expect(summary.text()).toContain("DISA Vendor Submission");
      expect(summary.text()).toContain("Excel");
      expect(summary.text()).toContain("1 component");
    });

    it("summary shows correct component count for multi-select", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: multipleComponents,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();
      wrapper.vm.selectedComponentIds = [1, 2, 3];
      await wrapper.vm.$nextTick();

      const summary = wrapper.find('[data-testid="export-summary"]');
      expect(summary.text()).toContain("3 components");
    });
  });

  // ==========================================
  // MEMBERSHIP CHECKBOX (backup mode)
  // ==========================================
  describe("include memberships checkbox", () => {
    const allModes = ["working_copy", "vendor_submission", "published_stig", "backup"];

    it("shows checkbox when backup mode selected", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();

      const checkbox = wrapper.find('[data-testid="include-memberships-checkbox"]');
      expect(checkbox.exists()).toBe(true);
    });

    it("hides checkbox in non-backup modes", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();

      const checkbox = wrapper.find('[data-testid="include-memberships-checkbox"]');
      expect(checkbox.exists()).toBe(false);
    });

    it("hides checkbox in legacy mode (no modes)", () => {
      wrapper = createWrapper({
        components: singleComponent,
        visible: true,
      });

      const checkbox = wrapper.find('[data-testid="include-memberships-checkbox"]');
      expect(checkbox.exists()).toBe(false);
    });

    it("includes includeMemberships in export payload for backup", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();
      // backup auto-selects json_archive

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const payload = wrapper.emitted("export")[0][0];
      expect(payload.includeMemberships).toBe(true);
    });

    it("does not include includeMemberships for non-backup modes", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "vendor_submission";
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const payload = wrapper.emitted("export")[0][0];
      expect(payload.includeMemberships).toBeUndefined();
    });

    it("resets to true on modal reopen", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      wrapper.vm.includeMemberships = false;

      // Re-trigger visible watcher
      await wrapper.setProps({ visible: false });
      await wrapper.setProps({ visible: true });

      expect(wrapper.vm.includeMemberships).toBe(true);
    });
  });

  describe("Include SRG checkbox", () => {
    it("shows checkbox in backup mode", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();

      const checkbox = wrapper.find('[data-testid="include-srg-checkbox"]');
      expect(checkbox.exists()).toBe(true);
    });

    it("hides checkbox in non-backup modes", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "working_copy";
      await wrapper.vm.$nextTick();

      const checkbox = wrapper.find('[data-testid="include-srg-checkbox"]');
      expect(checkbox.exists()).toBe(false);
    });

    it("includes includeSrg in export payload for backup", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      await wrapper.vm.$nextTick();

      const exportBtn = wrapper.find('[data-testid="export-btn"]');
      await exportBtn.trigger("click");

      const payload = wrapper.emitted("export")[0][0];
      expect(payload.includeSrg).toBe(true);
    });

    it("defaults to true and resets on modal reopen", async () => {
      wrapper = createWrapper({
        availableModes: allModes,
        components: singleComponent,
        visible: true,
      });
      wrapper.vm.selectedMode = "backup";
      wrapper.vm.includeSrg = false;

      await wrapper.setProps({ visible: false });
      await wrapper.setProps({ visible: true });

      expect(wrapper.vm.includeSrg).toBe(true);
    });
  });

  /**
   * NYD PRE-FLIGHT WARNING TESTS
   *
   * REQUIREMENTS:
   * 1. Components with ALL rules "Not Yet Determined" get a warning icon
   * 2. Warning message appears when DISA mode selected and NYD-only components are selected
   * 3. Danger variant when ALL selected components are NYD-only
   * 4. Warning variant when SOME selected components are NYD-only
   * 5. No warning for non-DISA modes (working_copy, backup)
   * 6. No warning when no NYD-only components are selected
   */
  describe("NYD pre-flight warning", () => {
    const nydComponent = {
      id: 10,
      name: "NYD Only",
      version: "1",
      release: "1",
      status_counts: {
        not_yet_determined: 50,
        applicable_configurable: 0,
        applicable_inherently_meets: 0,
        applicable_does_not_meet: 0,
        not_applicable: 0,
      },
    };

    const mixedComponent = {
      id: 20,
      name: "Mixed Status",
      version: "1",
      release: "1",
      status_counts: {
        not_yet_determined: 10,
        applicable_configurable: 30,
        applicable_inherently_meets: 5,
        applicable_does_not_meet: 0,
        not_applicable: 5,
      },
    };

    const acComponent = {
      id: 30,
      name: "All AC",
      version: "1",
      release: "1",
      status_counts: {
        not_yet_determined: 0,
        applicable_configurable: 40,
        applicable_inherently_meets: 0,
        applicable_does_not_meet: 0,
        not_applicable: 0,
      },
    };

    const allModes = ["working_copy", "vendor_submission", "published_stig", "backup"];

    it("shows warning icon on NYD-only components", async () => {
      wrapper = createWrapper({
        components: [nydComponent, mixedComponent],
        availableModes: allModes,
        visible: true,
      });

      const icons = wrapper.findAll('[data-testid="nyd-warning-icon"]');
      expect(icons.length).toBe(1);
    });

    it("does not show warning icon on components with exportable rules", async () => {
      wrapper = createWrapper({
        components: [mixedComponent, acComponent],
        availableModes: allModes,
        visible: true,
      });

      expect(wrapper.find('[data-testid="nyd-warning-icon"]').exists()).toBe(false);
    });

    it("shows danger alert when ALL selected components are NYD-only in vendor_submission mode", async () => {
      wrapper = createWrapper({
        components: [nydComponent],
        availableModes: allModes,
        visible: true,
      });

      // Select vendor_submission mode
      wrapper.vm.selectedMode = "vendor_submission";
      wrapper.vm.selectedComponentIds = [nydComponent.id];
      await wrapper.vm.$nextTick();

      const alert = wrapper.find('[data-testid="nyd-warning"]');
      expect(alert.exists()).toBe(true);
      expect(alert.find(".alert").classes()).toContain("alert-danger");
      expect(alert.text()).toContain("All selected components");
      expect(alert.text()).toContain("empty output");
    });

    it("shows warning alert when SOME selected components are NYD-only in published_stig mode", async () => {
      wrapper = createWrapper({
        components: [nydComponent, acComponent],
        availableModes: allModes,
        visible: true,
      });

      wrapper.vm.selectedMode = "published_stig";
      wrapper.vm.selectedComponentIds = [nydComponent.id, acComponent.id];
      await wrapper.vm.$nextTick();

      const alert = wrapper.find('[data-testid="nyd-warning"]');
      expect(alert.exists()).toBe(true);
      expect(alert.find(".alert").classes()).toContain("alert-warning");
      expect(alert.text()).toContain("1 selected component has");
      expect(alert.text()).toContain("empty worksheets");
    });

    it("does not show warning for working_copy mode", async () => {
      wrapper = createWrapper({
        components: [nydComponent],
        availableModes: allModes,
        visible: true,
      });

      wrapper.vm.selectedMode = "working_copy";
      wrapper.vm.selectedComponentIds = [nydComponent.id];
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="nyd-warning"]').exists()).toBe(false);
    });

    it("does not show warning for backup mode", async () => {
      wrapper = createWrapper({
        components: [nydComponent],
        availableModes: allModes,
        visible: true,
      });

      wrapper.vm.selectedMode = "backup";
      wrapper.vm.selectedComponentIds = [nydComponent.id];
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="nyd-warning"]').exists()).toBe(false);
    });

    it("does not show warning when no NYD-only components are selected", async () => {
      wrapper = createWrapper({
        components: [nydComponent, acComponent],
        availableModes: allModes,
        visible: true,
      });

      wrapper.vm.selectedMode = "vendor_submission";
      wrapper.vm.selectedComponentIds = [acComponent.id];
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="nyd-warning"]').exists()).toBe(false);
    });

    it("handles components without status_counts gracefully", async () => {
      const noCountsComponent = { id: 99, name: "No Counts", version: "1", release: "1" };
      wrapper = createWrapper({
        components: [noCountsComponent],
        availableModes: allModes,
        visible: true,
      });

      expect(wrapper.find('[data-testid="nyd-warning-icon"]').exists()).toBe(false);
    });
  });
});
