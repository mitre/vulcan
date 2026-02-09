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
          props: ["visible", "title", "centered"],
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
});
