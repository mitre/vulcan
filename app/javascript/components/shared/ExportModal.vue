<template>
  <b-modal :visible="visible" :title="modalTitle" centered @hidden="onHidden" @hide="onHide">
    <!-- Format Selection (Radio Buttons) -->
    <div class="mb-3">
      <label class="font-weight-bold d-block mb-2">Format</label>
      <b-form-radio-group v-model="selectedFormat" stacked>
        <b-form-radio value="disa_excel" class="mb-2">
          <span class="font-weight-medium">DISA Excel</span>
          <small class="text-muted d-block">DoD/DISA format</small>
        </b-form-radio>
        <b-form-radio value="excel" class="mb-2">
          <span class="font-weight-medium">Excel</span>
          <small class="text-muted d-block">Standard spreadsheet</small>
        </b-form-radio>
        <b-form-radio value="inspec" class="mb-2">
          <span class="font-weight-medium">InSpec</span>
          <small class="text-muted d-block">Chef InSpec profile</small>
        </b-form-radio>
        <b-form-radio value="xccdf" class="mb-2">
          <span class="font-weight-medium">XCCDF</span>
          <small class="text-muted d-block">SCAP XML format</small>
        </b-form-radio>
      </b-form-radio-group>
    </div>

    <hr />

    <!-- Component Selection -->
    <div>
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
/**
 * ExportModal - Unified export modal with format and component selection
 *
 * Usage:
 *   <ExportModal
 *     v-model="showExportModal"
 *     :components="components"
 *     @export="handleExport"
 *     @cancel="handleCancel"
 *   />
 *
 * Props:
 *   - components: Array of { id, name, version?, release? }
 *   - visible: Boolean (use v-model)
 *   - title: Optional custom title (default: "Export Project")
 *
 * Emits:
 *   - export: { type: string, componentIds: number[] }
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
  },
  data() {
    return {
      selectedFormat: null,
      selectedComponentIds: [],
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
    canExport() {
      // Must have format selected AND at least one component
      return this.selectedFormat !== null && this.selectedComponentIds.length > 0;
    },
  },
  watch: {
    visible(newVal) {
      if (newVal) {
        // Reset selections when modal opens
        this.selectedFormat = null;
        if (this.isSingleComponent) {
          // Auto-select single component
          this.selectedComponentIds = [this.components[0].id];
        } else {
          this.selectedComponentIds = [];
        }
      }
    },
  },
  methods: {
    toggleSelectAll(checked) {
      if (checked) {
        this.selectedComponentIds = this.components.map((c) => c.id);
      } else {
        this.selectedComponentIds = [];
      }
    },
    onCancel() {
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
    onExport() {
      this.$emit("export", {
        type: this.selectedFormat,
        componentIds: [...this.selectedComponentIds],
      });
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
