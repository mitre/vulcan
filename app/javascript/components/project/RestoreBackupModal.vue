<template>
  <b-modal v-model="modalShow" title="Restore From Backup" size="lg" centered @hidden="resetState">
    <!-- Step 1: Upload -->
    <div v-if="step === 'upload'">
      <p class="mb-3">
        Upload a JSON archive (.zip) exported from Vulcan to restore components into this project.
      </p>

      <b-form-group label="Backup file" label-for="backup-file">
        <b-form-file
          id="backup-file"
          v-model="file"
          data-testid="backup-file-input"
          placeholder="Choose or drop a .zip backup here..."
          drop-placeholder="Drop .zip here..."
          accept=".zip"
        />
      </b-form-group>

      <b-form-checkbox v-model="includeReviews" data-testid="include-reviews-checkbox">
        Include review history
      </b-form-checkbox>

      <b-form-checkbox v-model="includeMemberships" data-testid="include-memberships-checkbox">
        Include project memberships
      </b-form-checkbox>
    </div>

    <!-- Step 2: Preview -->
    <div v-if="step === 'preview' && summary">
      <p class="mb-3">
        Preview of what will be imported from
        <strong>{{ file ? file.name : "" }}</strong
        >:
      </p>

      <BackupPreview
        :summary="summary"
        :component-details="summary.component_details || []"
        :warnings="warnings"
        :selectable="true"
        :existing-names="existingComponentNames"
        @selection-change="onSelectionChange"
      />
    </div>

    <!-- Footer -->
    <template #modal-footer>
      <template v-if="step === 'upload'">
        <b-button variant="outline-secondary" @click="modalShow = false">Cancel</b-button>
        <b-button
          variant="primary"
          data-testid="preview-btn"
          :disabled="!file || loading"
          @click="submitDryRun"
        >
          {{ loading ? "Checking..." : "Preview Import" }}
        </b-button>
      </template>

      <template v-if="step === 'preview'">
        <b-button variant="outline-secondary" data-testid="back-btn" @click="step = 'upload'">
          Back
        </b-button>
        <b-button
          variant="success"
          data-testid="import-btn"
          :disabled="loading || selectedComponentCount === 0 || hasUnresolvedConflicts"
          @click="submitImport"
        >
          {{ loading ? "Importing..." : "Import" }}
        </b-button>
      </template>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import BackupPreview from "../shared/BackupPreview.vue";

export default {
  name: "RestoreBackupModal",
  components: { BackupPreview },
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    project_id: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      modalShow: false,
      step: "upload",
      file: null,
      includeReviews: true,
      includeMemberships: false,
      loading: false,
      summary: null,
      warnings: [],
      selectedComponentCount: 0,
      hasUnresolvedConflicts: false,
      componentFilter: null,
      existingComponentNames: [],
    };
  },
  methods: {
    showModal() {
      this.resetState();
      this.modalShow = true;
    },
    resetState() {
      this.step = "upload";
      this.file = null;
      this.includeReviews = true;
      this.includeMemberships = false;
      this.loading = false;
      this.summary = null;
      this.warnings = [];
      this.selectedComponentCount = 0;
      this.hasUnresolvedConflicts = false;
      this.componentFilter = null;
      this.existingComponentNames = [];
    },
    onSelectionChange({ selectedCount, componentFilter, hasUnresolvedConflicts }) {
      this.selectedComponentCount = selectedCount;
      this.componentFilter = componentFilter;
      this.hasUnresolvedConflicts = hasUnresolvedConflicts;
    },
    buildFormData(dryRun) {
      const formData = new FormData();
      formData.append("file", this.file);
      formData.append("dry_run", String(dryRun));
      formData.append("include_reviews", String(this.includeReviews));
      formData.append("include_memberships", String(this.includeMemberships));
      if (!dryRun && this.componentFilter) {
        formData.append("component_filter", JSON.stringify(this.componentFilter));
      }
      return formData;
    },
    async submitDryRun() {
      this.loading = true;
      try {
        const response = await axios.post(
          `/projects/${this.project_id}/import_backup`,
          this.buildFormData(true),
          { headers: { "Content-Type": "multipart/form-data" } },
        );
        this.summary = response.data.summary;
        this.warnings = response.data.warnings || [];
        // Extract existing names from conflicting components
        const details = response.data.summary.component_details || [];
        this.existingComponentNames = details.filter((d) => d.conflict).map((d) => d.name);
        // Initialize selection count from summary
        this.selectedComponentCount = response.data.summary.components_imported || 0;
        this.step = "preview";
      } catch (error) {
        this.alertOrNotifyResponse(error.response);
      } finally {
        this.loading = false;
      }
    },
    async submitImport() {
      this.loading = true;
      try {
        const response = await axios.post(
          `/projects/${this.project_id}/import_backup`,
          this.buildFormData(false),
          { headers: { "Content-Type": "multipart/form-data" } },
        );
        this.alertOrNotifyResponse(response);
        this.$emit("projectUpdated");
        this.modalShow = false;
      } catch (error) {
        this.alertOrNotifyResponse(error.response);
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
