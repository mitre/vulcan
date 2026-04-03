<template>
  <b-modal :visible="visible" title="Add Component" centered @hidden="onHidden">
    <!-- Option Selection -->
    <div>
      <p class="mb-3">Choose how you want to add a component to this project:</p>

      <b-form-radio-group v-model="selectedAction" stacked>
        <b-form-radio value="create" class="mb-3">
          <div class="d-flex align-items-start">
            <b-icon icon="file-earmark-plus" font-scale="1.5" class="mr-3 text-primary" />
            <div>
              <div class="font-weight-bold">Create New Component</div>
              <small class="text-muted">Start from scratch with an SRG baseline</small>
            </div>
          </div>
        </b-form-radio>

        <b-form-radio value="import" class="mb-3">
          <div class="d-flex align-items-start">
            <b-icon icon="file-earmark-spreadsheet" font-scale="1.5" class="mr-3 text-success" />
            <div>
              <div class="font-weight-bold">Import From Spreadsheet</div>
              <small class="text-muted">Upload XLSX or CSV with component data</small>
            </div>
          </div>
        </b-form-radio>

        <b-form-radio value="copy" class="mb-3">
          <div class="d-flex align-items-start">
            <b-icon icon="files" font-scale="1.5" class="mr-3 text-info" />
            <div>
              <div class="font-weight-bold">Copy Existing Component</div>
              <small class="text-muted">Duplicate from this project</small>
            </div>
          </div>
        </b-form-radio>

        <b-form-radio value="overlay" class="mb-3">
          <div class="d-flex align-items-start">
            <b-icon icon="layers" font-scale="1.5" class="mr-3 text-warning" />
            <div>
              <div class="font-weight-bold">Add Overlaid Component</div>
              <small class="text-muted">Import released STIG as overlay</small>
            </div>
          </div>
        </b-form-radio>

        <b-form-radio v-if="showRestore" value="restore" class="mb-3">
          <div class="d-flex align-items-start">
            <b-icon icon="archive" font-scale="1.5" class="mr-3 text-danger" />
            <div>
              <div class="font-weight-bold">Restore From Backup</div>
              <small class="text-muted">Import components from a JSON archive (.zip)</small>
            </div>
          </div>
        </b-form-radio>
      </b-form-radio-group>
    </div>

    <!-- Footer -->
    <template #modal-footer>
      <b-button variant="outline-secondary" data-testid="cancel-btn" @click="onCancel">
        Cancel
      </b-button>
      <b-button
        variant="primary"
        data-testid="next-btn"
        :disabled="!selectedAction"
        @click="onNext"
      >
        Next
      </b-button>
    </template>
  </b-modal>
</template>

<script>
/**
 * ComponentActionPicker - Modal for selecting how to add a component
 *
 * Usage:
 *   <ComponentActionPicker
 *     v-model="showPicker"
 *     @next="handleActionSelected"
 *     @cancel="handleCancel"
 *   />
 *
 * Props:
 *   - visible: Boolean (use v-model)
 *
 * Emits:
 *   - next: String - Action type ('create' | 'import' | 'copy' | 'overlay' | 'restore')
 *   - cancel: User cancelled
 *   - update:visible: For v-model support
 */
export default {
  name: "ComponentActionPicker",
  model: {
    prop: "visible",
    event: "update:visible",
  },
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    showRestore: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedAction: null,
    };
  },
  watch: {
    visible(newVal) {
      if (newVal) {
        // Reset selection when modal opens
        this.selectedAction = null;
      }
    },
  },
  methods: {
    onCancel() {
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
    onNext() {
      if (this.selectedAction) {
        this.$emit("next", this.selectedAction);
        this.$emit("update:visible", false);
      }
    },
    onHidden() {
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
  },
};
</script>
