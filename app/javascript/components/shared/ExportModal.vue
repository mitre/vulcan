<template>
  <b-modal
    :visible="visible"
    :title="modalTitle"
    :size="modalSize"
    centered
    @hidden="onHidden"
    @hide="onHide"
  >
    <div :class="{ row: showComponentSelection }">
      <!-- Left Panel: Purpose + Format + Column Picker -->
      <div :class="{ 'col-5': showComponentSelection }" data-testid="config-panel">
        <!-- Mode/Purpose Selection (only when availableModes provided) -->
        <div v-if="hasModes" class="mb-3">
          <label
            id="export-mode-label"
            for="export-mode-group"
            class="font-weight-bold d-block mb-2"
            >Purpose</label
          >
          <b-form-radio-group
            id="export-mode-group"
            v-model="selectedMode"
            stacked
            aria-labelledby="export-mode-label"
            data-testid="mode-group"
          >
            <b-form-radio
              v-for="mode in availableModes"
              :key="mode"
              :value="mode"
              class="mb-2"
              :data-testid="`mode-${mode}`"
            >
              <span class="font-weight-medium">{{ getModeLabel(mode) }}</span>
              <small class="text-muted d-block">{{ getModeDescription(mode) }}</small>
            </b-form-radio>
          </b-form-radio-group>
        </div>

        <hr v-if="hasModes && selectedMode" />

        <!-- Format Selection -->
        <div v-if="showFormatSection" class="mb-3">
          <label
            id="export-format-label"
            for="export-format-group"
            class="font-weight-bold d-block mb-2"
            >Format</label
          >
          <b-form-radio-group
            id="export-format-group"
            v-model="selectedFormat"
            stacked
            aria-labelledby="export-format-label"
            data-testid="format-group"
          >
            <b-form-radio
              v-for="fmt in displayFormats"
              :key="fmt"
              :value="fmt"
              :disabled="!isFormatEnabled(fmt)"
              class="mb-2"
            >
              <span class="font-weight-medium">{{ getFormatLabel(fmt) }}</span>
              <small class="text-muted d-block">{{ getFormatDescription(fmt) }}</small>
            </b-form-radio>
          </b-form-radio-group>
        </div>

        <!-- Column Picker (CSV only, when columnDefinitions provided) -->
        <template v-if="showColumnPicker">
          <hr />
          <div role="group" aria-labelledby="export-columns-label">
            <span id="export-columns-label" class="font-weight-bold d-block mb-2">Columns</span>
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
              <b-button
                size="sm"
                variant="outline-secondary"
                class="mr-1"
                @click="selectAllColumns"
              >
                Select All
              </b-button>
              <b-button size="sm" variant="outline-secondary" @click="resetColumnsToDefaults">
                Defaults
              </b-button>
            </div>
          </div>
        </template>
      </div>

      <!-- Right Panel: Components (only when visible) -->
      <div v-if="showComponentSelection" class="col-7 border-left" data-testid="component-panel">
        <span id="export-components-label" class="font-weight-bold d-block mb-2">Components</span>

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

          <!-- Individual Component Checkboxes (two-column grid) -->
          <div class="row ml-2 component-scroll" data-testid="component-list">
            <div v-for="opt in componentOptions" :key="opt.value" class="col-6">
              <b-form-checkbox v-model="selectedComponentIds" :value="opt.value">
                {{ opt.text }}
              </b-form-checkbox>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Inline Summary (mode-aware only) -->
    <div
      v-if="summaryText"
      class="mt-3 p-2 bg-light rounded"
      aria-live="polite"
      data-testid="export-summary"
    >
      <small class="text-muted">{{ summaryText }}</small>
    </div>

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
import {
  EXPORT_MODES,
  MODE_FORMAT_MATRIX,
  FORMAT_LABELS,
  MODE_FORMAT_OVERRIDES,
  ALL_FORMATS,
} from "../../constants/exportConfig";

/**
 * ExportModal - Unified export modal with optional mode, format, component,
 * and column selection.
 *
 * Usage (mode-aware — projects):
 *   <ExportModal
 *     v-model="showExportModal"
 *     :components="project.components"
 *     :available-modes="['working_copy', 'vendor_submission', 'published_stig', 'backup']"
 *     @export="handleExport"
 *   />
 *
 * Usage (legacy — stigs/srgs/benchmarks):
 *   <ExportModal
 *     v-model="showExportModal"
 *     :components="[benchmark]"
 *     :formats="['xccdf', 'csv']"
 *     :hide-component-selection="true"
 *     @export="handleExport"
 *   />
 *
 * Emits:
 *   - export: { type: string, componentIds: number[], mode?: string, columns?: string[] }
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
    availableModes: {
      type: Array,
      default: null,
    },
  },
  data() {
    return {
      selectedMode: null,
      selectedFormat: null,
      selectedComponentIds: [],
      selectedColumns: [],
    };
  },
  computed: {
    hasModes() {
      return this.availableModes && this.availableModes.length > 0;
    },
    showFormatSection() {
      // Legacy: always show format section
      // Mode-aware: show after mode is selected (progressive disclosure)
      return !this.hasModes || this.selectedMode !== null;
    },
    displayFormats() {
      if (this.hasModes) {
        // Show all standard formats; disabled state handled by isFormatEnabled
        return ALL_FORMATS;
      }
      // Legacy: filter by formats prop using v-if logic
      if (this.formats) {
        return this.formats;
      }
      // Default: all formats including legacy disa_excel
      return ["disa_excel", "excel", "inspec", "xccdf", "csv"];
    },
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
    modalSize() {
      return this.showComponentSelection ? "xl" : null;
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
    showColumnPicker() {
      return (
        this.columnDefinitions && this.columnDefinitions.length > 0 && this.selectedFormat === "csv"
      );
    },
    canExport() {
      return this.selectedFormat !== null && this.selectedComponentIds.length > 0;
    },
    summaryText() {
      if (!this.hasModes || !this.selectedMode || !this.selectedFormat) return null;
      const modeLabel = EXPORT_MODES[this.selectedMode]?.label || this.selectedMode;
      const formatLabel = FORMAT_LABELS[this.selectedFormat]?.label || this.selectedFormat;
      const count = this.selectedComponentIds.length;
      if (count === 0) return `${modeLabel} as ${formatLabel}`;
      const noun = count === 1 ? "component" : "components";
      return `${modeLabel} as ${formatLabel} \u2014 ${count} ${noun}`;
    },
  },
  watch: {
    selectedMode(newMode) {
      if (!newMode) return;
      const validFormats = MODE_FORMAT_MATRIX[newMode] || [];
      // Clear format if not valid for new mode
      if (this.selectedFormat && !validFormats.includes(this.selectedFormat)) {
        this.selectedFormat = null;
      }
      // Auto-select when only one format available
      if (validFormats.length === 1) {
        this.selectedFormat = validFormats[0];
      }
    },
    visible: {
      immediate: true,
      handler(newVal) {
        if (newVal) {
          // Reset mode
          this.selectedMode = null;
          // Reset format
          if (!this.hasModes && this.formats && this.formats.length === 1) {
            this.selectedFormat = this.formats[0];
          } else {
            this.selectedFormat = null;
          }
          // Auto-select components
          if (this.isSingleComponent) {
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
    getModeLabel(mode) {
      return EXPORT_MODES[mode]?.label || mode;
    },
    getModeDescription(mode) {
      return EXPORT_MODES[mode]?.description || "";
    },
    getFormatLabel(fmt) {
      if (this.hasModes) {
        return FORMAT_LABELS[fmt]?.label || fmt;
      }
      // Legacy labels
      if (fmt === "disa_excel") return "DISA Excel";
      if (fmt === "xccdf") return EXPORT_FORMATS.xccdf;
      return FORMAT_LABELS[fmt]?.label || fmt.toUpperCase();
    },
    getFormatDescription(fmt) {
      // Mode-aware: check for overrides and disabled hints
      if (this.hasModes && this.selectedMode) {
        const override = MODE_FORMAT_OVERRIDES[this.selectedMode]?.[fmt];
        if (override) return override.description;
        const validFormats = MODE_FORMAT_MATRIX[this.selectedMode] || [];
        if (!validFormats.includes(fmt)) {
          const enabledBy = Object.entries(MODE_FORMAT_MATRIX)
            .filter(([, fmts]) => fmts.includes(fmt))
            .map(([mode]) => EXPORT_MODES[mode]?.label)
            .join(" or ");
          return `Available in ${enabledBy} mode`;
        }
      }
      // Standard descriptions
      if (this.hasModes) {
        return FORMAT_LABELS[fmt]?.description || "";
      }
      // Legacy descriptions
      const legacyDescriptions = {
        disa_excel: "DoD/DISA format",
        excel: "Standard spreadsheet",
        inspec: "Chef InSpec profile",
        xccdf: "SCAP XML format",
        csv: "Comma-separated values",
      };
      return legacyDescriptions[fmt] || "";
    },
    isFormatEnabled(fmt) {
      if (!this.hasModes || !this.selectedMode) return true;
      const validFormats = MODE_FORMAT_MATRIX[this.selectedMode] || [];
      return validFormats.includes(fmt);
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
        this.selectedColumns = this.columnDefinitions.filter((c) => c.default).map((c) => c.key);
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
      // Include mode when mode-aware
      if (this.hasModes && this.selectedMode) {
        payload.mode = this.selectedMode;
      }
      // Include columns only for CSV format
      if (this.selectedFormat === "csv" && this.selectedColumns.length > 0) {
        payload.columns = [...this.selectedColumns];
      }
      this.$emit("export", payload);
      this.$emit("update:visible", false);
    },
    onHidden() {
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
    onHide(event) {
      if (event.trigger === "ok" || event.trigger === "cancel") {
        event.preventDefault();
      }
    },
  },
};
</script>

<style scoped>
.component-scroll {
  max-height: 400px;
  overflow-y: auto;
}
</style>
