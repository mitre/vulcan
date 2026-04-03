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

      <BackupPreview
        :summary="summary"
        :component-details="summary.component_details || []"
        :warnings="warnings"
      />
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
import BackupPreview from "../shared/BackupPreview.vue";

export default {
  name: "RestoreProjectModal",
  components: { BackupPreview },
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
          globalThis.location = response.data.redirect_url;
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
