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

      <!-- Component Selection (when component_details available) -->
      <div v-if="componentSelections.length > 0" data-testid="component-picker">
        <h6 class="font-weight-bold mb-2">Select components to import:</h6>
        <div class="component-list mb-3">
          <div
            v-for="(comp, index) in componentSelections"
            :key="index"
            class="d-flex align-items-center py-1 border-bottom"
            data-testid="component-row"
          >
            <b-form-checkbox
              v-model="comp.selected"
              :data-testid="'component-checkbox-' + index"
              class="mr-2"
            />
            <div class="flex-grow-1">
              <template v-if="comp.conflict && comp.selected">
                <b-form-input
                  v-model="comp.importName"
                  size="sm"
                  :data-testid="'component-name-input-' + index"
                  class="d-inline-block"
                  style="width: 250px"
                />
              </template>
              <template v-else>
                {{ comp.name }}
              </template>
            </div>
            <small class="text-muted mr-2">{{ comp.ruleCount }} rules</small>
            <b-badge v-if="comp.conflict" variant="warning" data-testid="conflict-badge">
              conflict
            </b-badge>
            <b-icon v-else icon="check-circle" variant="success" />
          </div>
        </div>
      </div>

      <!-- Summary Table -->
      <table class="table table-sm table-bordered" data-testid="summary-table">
        <thead>
          <tr>
            <th>Item</th>
            <th class="text-right">Count</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Components</td>
            <td class="text-right font-weight-bold">{{ selectedComponentCount }}</td>
          </tr>
          <tr>
            <td>Rules</td>
            <td class="text-right font-weight-bold">{{ selectedRuleCount }}</td>
          </tr>
          <tr>
            <td>Satisfactions</td>
            <td class="text-right font-weight-bold">{{ summary.satisfactions_imported }}</td>
          </tr>
          <tr>
            <td>Reviews</td>
            <td class="text-right font-weight-bold">{{ summary.reviews_imported }}</td>
          </tr>
          <tr v-if="summary.memberships_imported !== undefined">
            <td>Memberships</td>
            <td class="text-right font-weight-bold">{{ summary.memberships_imported }}</td>
          </tr>
        </tbody>
      </table>

      <b-alert v-for="(warning, index) in warnings" :key="index" variant="warning" show>
        {{ warning }}
      </b-alert>
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
          :disabled="loading || selectedComponentCount === 0"
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

export default {
  name: "RestoreBackupModal",
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
      componentSelections: [],
    };
  },
  computed: {
    selectedComponentCount() {
      if (this.componentSelections.length === 0) {
        return this.summary ? this.summary.components_imported : 0;
      }
      return this.componentSelections.filter((c) => c.selected).length;
    },
    selectedRuleCount() {
      if (this.componentSelections.length === 0) {
        return this.summary ? this.summary.rules_imported : 0;
      }
      return this.componentSelections
        .filter((c) => c.selected)
        .reduce((sum, c) => sum + c.ruleCount, 0);
    },
    componentFilter() {
      if (this.componentSelections.length === 0) return null;
      const filter = {};
      this.componentSelections
        .filter((c) => c.selected)
        .forEach((c) => {
          filter[c.name] = c.importName;
        });
      return filter;
    },
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
      this.componentSelections = [];
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
    buildComponentSelections(details) {
      if (!details || !Array.isArray(details)) return [];
      return details.map((d) => ({
        name: d.name,
        importName: d.conflict ? `${d.name} (restored)` : d.name,
        ruleCount: d.rule_count,
        conflict: d.conflict,
        selected: true,
      }));
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
        this.componentSelections = this.buildComponentSelections(
          response.data.summary.component_details,
        );
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
