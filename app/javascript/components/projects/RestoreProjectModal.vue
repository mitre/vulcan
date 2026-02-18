<template>
  <b-modal
    v-model="modalShow"
    title="New Project From Backup"
    size="lg"
    centered
    @hidden="resetState"
  >
    <!-- Step 1: Upload + Config -->
    <div v-if="step === 'upload'">
      <p class="mb-3">
        Upload a JSON archive (.zip) exported from Vulcan to create a new project with all its data.
      </p>

      <b-form-group label="Backup file" label-for="restore-backup-file">
        <b-form-file
          id="restore-backup-file"
          v-model="file"
          data-testid="backup-file-input"
          placeholder="Choose or drop a .zip backup here..."
          drop-placeholder="Drop .zip here..."
          accept=".zip"
        />
      </b-form-group>

      <b-form-group label="Project name" label-for="restore-project-name">
        <b-form-input
          id="restore-project-name"
          v-model="projectName"
          data-testid="project-name-input"
          :placeholder="projectDefaults.name || 'Project name'"
        />
      </b-form-group>

      <b-form-group label="Description" label-for="restore-project-description">
        <b-form-textarea
          id="restore-project-description"
          v-model="projectDescription"
          data-testid="project-description-input"
          rows="2"
        />
      </b-form-group>

      <b-form-group label="Visibility" label-for="restore-project-visibility">
        <b-form-select
          id="restore-project-visibility"
          v-model="projectVisibility"
          data-testid="project-visibility-select"
          :options="visibilityOptions"
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
        A new project <strong>{{ projectName }}</strong> will be created with:
      </p>

      <!-- Component list -->
      <div v-if="componentDetails.length > 0" class="mb-3" data-testid="component-list">
        <h6 class="font-weight-bold mb-2">Components ({{ componentDetails.length }})</h6>
        <div
          v-for="(comp, index) in componentDetails"
          :key="index"
          class="d-flex justify-content-between align-items-center py-1 border-bottom"
          data-testid="component-detail-row"
        >
          <span>
            <b-icon icon="folder" class="mr-1 text-muted" />
            {{ comp.name }}
          </span>
          <small class="text-muted">{{ comp.rule_count }} rules</small>
        </div>
      </div>

      <!-- Summary totals -->
      <table class="table table-sm table-bordered" data-testid="summary-table">
        <tbody>
          <tr>
            <td>Total Rules</td>
            <td class="text-right font-weight-bold">{{ summary.rules_imported }}</td>
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
          :disabled="!file || !projectName || loading"
          @click="submitDryRun"
        >
          {{ loading ? "Checking..." : "Preview" }}
        </b-button>
      </template>

      <template v-if="step === 'preview'">
        <b-button variant="outline-secondary" data-testid="back-btn" @click="step = 'upload'">
          Back
        </b-button>
        <b-button
          variant="success"
          data-testid="create-btn"
          :disabled="loading"
          @click="submitCreate"
        >
          {{ loading ? "Creating..." : "Create Project" }}
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
  name: "RestoreProjectModal",
  mixins: [FormMixinVue, AlertMixinVue],
  data() {
    return {
      modalShow: false,
      step: "upload",
      file: null,
      projectName: "",
      projectDescription: "",
      projectVisibility: "discoverable",
      includeReviews: true,
      includeMemberships: false,
      loading: false,
      summary: null,
      warnings: [],
      projectDefaults: {},
      visibilityOptions: [
        { value: "discoverable", text: "Discoverable" },
        { value: "hidden", text: "Hidden" },
      ],
    };
  },
  computed: {
    componentDetails() {
      if (!this.summary || !this.summary.component_details) return [];
      return this.summary.component_details;
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
      this.projectName = "";
      this.projectDescription = "";
      this.projectVisibility = "discoverable";
      this.includeReviews = true;
      this.includeMemberships = false;
      this.loading = false;
      this.summary = null;
      this.warnings = [];
      this.projectDefaults = {};
    },
    async submitDryRun() {
      this.loading = true;
      try {
        const formData = new FormData();
        formData.append("file", this.file);
        formData.append("dry_run", "true");
        formData.append("include_reviews", String(this.includeReviews));
        formData.append("include_memberships", String(this.includeMemberships));

        const response = await axios.post("/projects/create_from_backup", formData, {
          headers: { "Content-Type": "multipart/form-data" },
        });

        this.summary = response.data.summary;
        this.warnings = response.data.warnings || [];
        this.projectDefaults = response.data.project_defaults || {};

        // Pre-fill from archive if user hasn't typed anything
        if (!this.projectName && this.projectDefaults.name) {
          this.projectName = this.projectDefaults.name;
        }
        if (!this.projectDescription && this.projectDefaults.description) {
          this.projectDescription = this.projectDefaults.description;
        }
        if (this.projectDefaults.visibility) {
          this.projectVisibility = this.projectDefaults.visibility;
        }

        this.step = "preview";
      } catch (error) {
        this.alertOrNotifyResponse(error.response);
      } finally {
        this.loading = false;
      }
    },
    async submitCreate() {
      this.loading = true;
      try {
        const formData = new FormData();
        formData.append("file", this.file);
        formData.append("project_name", this.projectName);
        formData.append("project_description", this.projectDescription);
        formData.append("project_visibility", this.projectVisibility);
        formData.append("include_reviews", String(this.includeReviews));
        formData.append("include_memberships", String(this.includeMemberships));

        const response = await axios.post("/projects/create_from_backup", formData, {
          headers: { "Content-Type": "multipart/form-data" },
        });

        if (response.data.redirect_url) {
          window.location = response.data.redirect_url;
        } else {
          this.alertOrNotifyResponse(response);
          this.$emit("projectCreated");
          this.modalShow = false;
        }
      } catch (error) {
        this.alertOrNotifyResponse(error.response);
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
