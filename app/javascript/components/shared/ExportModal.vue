<template>
  <b-modal :visible="visible" :title="modalTitle" centered @hidden="onHidden" @hide="onHide">
    <!-- Format Selection (Radio Buttons) -->
    <div class="mb-3">
      <label class="font-weight-bold d-block mb-2">Format</label>
      <b-form-radio-group v-model="selectedFormat" stacked>
        <b-form-radio v-if="showFormat('disa_excel')" value="disa_excel" class="mb-2">
          <span class="font-weight-medium">DISA Excel</span>
          <small class="text-muted d-block">DoD/DISA format</small>
        </b-form-radio>
        <b-form-radio v-if="showFormat('excel')" value="excel" class="mb-2">
          <span class="font-weight-medium">Excel</span>
          <small class="text-muted d-block">Standard spreadsheet</small>
        </b-form-radio>
        <b-form-radio v-if="showFormat('inspec')" value="inspec" class="mb-2">
          <span class="font-weight-medium">InSpec</span>
          <small class="text-muted d-block">Chef InSpec profile</small>
        </b-form-radio>
        <b-form-radio v-if="showFormat('xccdf')" value="xccdf" class="mb-2">
          <span class="font-weight-medium">{{ xccdfLabel }}</span>
          <small class="text-muted d-block">SCAP XML format</small>
        </b-form-radio>
        <b-form-radio v-if="showFormat('csv')" value="csv" class="mb-2">
          <span class="font-weight-medium">CSV</span>
          <small class="text-muted d-block">Comma-separated values</small>
        </b-form-radio>
      </b-form-radio-group>
    </div>

    <hr v-if="showComponentSelection" />

    <!-- Component Selection (hidden when single benchmark export) -->
    <div v-if="showComponentSelection">
      <label class="font-weight-bold d-block mb-2">Components</label>

      <!-- Single Component: Simplified View -->
      <div v-if="isSingleComponent" data-testid="single-mode">
        <p class="mb-0">
          <b-icon-check-circle-fill variant="success" class="mr-1" />
          {{ singleComponentLabel }}
        </p>
      </div>

      <!-- Multiple Components: Checkbox Selection -->
      <div v-else data-testid="multi-mode">
        <!-- Select All -->
        <b-form-checkbox
          data-testid="select-all"
          :checked="allSelected"
          :indeterminate="someSelected && !allSelected"
          class="mb-2"
          @change="toggleSelectAll"
        >
          All {{ components.length }} components
        </b-form-checkbox>

        <!-- Individual Component Checkboxes -->
        <b-form-checkbox-group
          v-model="selectedComponentIds"
          :options="componentOptions"
          stacked
          class="ml-4"
        />
      </div>
    </div>

    <!-- Column Picker (CSV only, when columnDefinitions provided) -->
    <template v-if="showColumnPicker">
      <hr />
      <div>
        <label class="font-weight-bold d-block mb-2">Columns</label>
        <div v-for="col in columnDefinitions" :key="col.key" class="mb-1">
          <b-form-checkbox
            :checked="selectedColumns.includes(col.key)"
            @change="toggleColumn(col.key, $event)"
          >
            <span class="font-weight-medium">{{ col.header }}</span>
            <small class="text-muted ml-1">{{ col.example }}</small>
          </b-form-checkbox>
        </div>
        <div class="mt-2">
          <b-button size="sm" variant="outline-secondary" class="mr-1" @click="selectAllColumns">
            Select All
          </b-button>
          <b-button size="sm" variant="outline-secondary" @click="resetColumnsToDefaults">
            Defaults
          </b-button>
        </div>
      </div>
    </template>

    <!-- Footer -->
    <template #modal-footer>
      <b-button variant="outline-secondary" data-testid="cancel-btn" @click="onCancel">
        Cancel
      </b-button>
      <b-button variant="primary" data-testid="export-btn" :disabled="!canExport" @click="onExport">
        Export
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import { EXPORT_FORMATS } from "../../constants/terminology";

/**
 * ExportModal - Unified export modal with format, component, and column selection
 *
 * Usage:
 *   <ExportModal
 *     v-model="showExportModal"
 *     :components="components"
 *     :column-definitions="STIG_CSV_COLUMNS"
 *     @export="handleExport"
 *     @cancel="handleCancel"
 *   />
 *
 * Props:
 *   - components: Array of { id, name, version?, release? }
 *   - visible: Boolean (use v-model)
 *   - title: Optional custom title (default: "Export Project")
 *   - formats: Optional array of format values to show (default: all)
 *   - hideComponentSelection: Boolean to hide the component selection section
 *   - columnDefinitions: Optional array of { key, header, example, default } for CSV column picker
 *
 * Emits:
 *   - export: { type: string, componentIds: number[], columns?: string[] }
 *   - cancel: User cancelled
 *   - update:visible: For v-model support
 */
export default {
  name: "ExportModal",
  model: {
    prop: "visible",
    event: "update:visible",
  },
  props: {
    components: {
      type: Array,
      required: true,
    },
    visible: {
      type: Boolean,
      default: false,
    },
    title: {
      type: String,
      default: null,
    },
    formats: {
      type: Array,
      default: null,
    },
    hideComponentSelection: {
      type: Boolean,
      default: false,
    },
    columnDefinitions: {
      type: Array,
      default: null,
    },
  },
  data() {
    return {
      selectedFormat: null,
      selectedComponentIds: [],
      selectedColumns: [],
    };
  },
  computed: {
    isSingleComponent() {
      return this.components.length === 1;
    },
    singleComponentLabel() {
      if (!this.isSingleComponent) return "";
      const c = this.components[0];
      const vr = c.version && c.release ? ` - V${c.version}R${c.release}` : "";
      return `${c.name}${vr}`;
    },
    modalTitle() {
      return this.title || "Export Project";
    },
    componentOptions() {
      return this.components.map((c) => {
        const vr = c.version && c.release ? ` - V${c.version}R${c.release}` : "";
        return {
          text: `${c.name}${vr}`,
          value: c.id,
        };
      });
    },
    allSelected() {
      return this.selectedComponentIds.length === this.components.length;
    },
    someSelected() {
      return this.selectedComponentIds.length > 0;
    },
    showComponentSelection() {
      return !this.hideComponentSelection;
    },
    xccdfLabel() {
      return EXPORT_FORMATS.xccdf;
    },
    showColumnPicker() {
      return (
        this.columnDefinitions &&
        this.columnDefinitions.length > 0 &&
        this.selectedFormat === "csv"
      );
    },
    canExport() {
      // Must have format selected AND at least one component
      return this.selectedFormat !== null && this.selectedComponentIds.length > 0;
    },
  },
  watch: {
    visible: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          // Auto-select format when only one is available
          if (this.formats && this.formats.length === 1) {
            this.selectedFormat = this.formats[0];
          } else {
            this.selectedFormat = null;
          }
          if (this.isSingleComponent) {
            // Auto-select single component
            this.selectedComponentIds = [this.components[0].id];
          } else {
            this.selectedComponentIds = [];
          }
          // Reset columns to defaults
          this.resetColumnsToDefaults();
        }
      },
    },
  },
  methods: {
    showFormat(format) {
      return this.formats === null || this.formats.includes(format);
    },
    toggleSelectAll(checked) {
      if (checked) {
        this.selectedComponentIds = this.components.map((c) => c.id);
      } else {
        this.selectedComponentIds = [];
      }
    },
    toggleColumn(key, checked) {
      if (checked) {
        if (!this.selectedColumns.includes(key)) {
          this.selectedColumns.push(key);
        }
      } else {
        this.selectedColumns = this.selectedColumns.filter((k) => k !== key);
      }
    },
    selectAllColumns() {
      if (this.columnDefinitions) {
        this.selectedColumns = this.columnDefinitions.map((c) => c.key);
      }
    },
    resetColumnsToDefaults() {
      if (this.columnDefinitions) {
        this.selectedColumns = this.columnDefinitions
          .filter((c) => c.default)
          .map((c) => c.key);
      } else {
        this.selectedColumns = [];
      }
    },
    onCancel() {
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
    onExport() {
      const payload = {
        type: this.selectedFormat,
        componentIds: [...this.selectedComponentIds],
      };
      // Include columns only for CSV format
      if (this.selectedFormat === "csv" && this.selectedColumns.length > 0) {
        payload.columns = [...this.selectedColumns];
      }
      this.$emit("export", payload);
      this.$emit("update:visible", false);
    },
    onHidden() {
      // Emitted when modal is hidden (backdrop click, escape, etc.)
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
    onHide(event) {
      // Prevent double-emit when Cancel/Export buttons are clicked
      if (event.trigger === "ok" || event.trigger === "cancel") {
        event.preventDefault();
      }
    },
  },
};
</script>
