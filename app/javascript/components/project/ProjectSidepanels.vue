<template>
  <div>
    <!-- Project Details Sidebar -->
    <b-sidebar
      id="proj-details-sidebar"
      data-testid="proj-details-sidebar"
      title="Project Details"
      right
      shadow
      backdrop
      :visible="activePanel === 'proj-details'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <p class="mb-2"><strong>Name:</strong> {{ project.name }}</p>
        <p v-if="project.description" class="mb-2">
          <strong>Description:</strong> {{ project.description }}
        </p>

        <hr />

        <h6>Status Summary</h6>
        <p class="mb-1">
          <strong>Applicable - Configurable:</strong> {{ project.details.ac }} ({{
            percentage(project.details.ac)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Applicable - Inherently Meets:</strong> {{ project.details.aim }} ({{
            percentage(project.details.aim)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Applicable - Does Not Meet:</strong> {{ project.details.adnm }} ({{
            percentage(project.details.adnm)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Not Applicable:</strong> {{ project.details.na }} ({{
            percentage(project.details.na)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Not Yet Determined:</strong> {{ project.details.nyd }} ({{
            percentage(project.details.nyd)
          }}%)
        </p>

        <hr />

        <h6>Review Status</h6>
        <p class="mb-1">
          <strong>Not Under Review:</strong> {{ project.details.nur }} ({{
            percentage(project.details.nur)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Under Review:</strong> {{ project.details.ur }} ({{
            percentage(project.details.ur)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Locked:</strong> {{ project.details.lck }} ({{
            percentage(project.details.lck)
          }}%)
        </p>

        <hr />

        <p class="mb-2"><strong>Total:</strong> {{ project.details.total }}</p>

        <UpdateProjectDetailsModal
          v-if="isAdmin"
          :project="project"
          @projectUpdated="$emit('project-updated')"
        />
      </div>
    </b-sidebar>

    <!-- Project Metadata Sidebar -->
    <b-sidebar
      id="proj-metadata-sidebar"
      data-testid="proj-metadata-sidebar"
      title="Project Metadata"
      right
      shadow
      backdrop
      :visible="activePanel === 'proj-metadata'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <div v-if="hasMetadata">
          <div v-for="(value, key) in project.metadata" :key="key" class="mb-2">
            <p class="mb-0">
              <strong>{{ key }}:</strong> {{ value }}
            </p>
          </div>
        </div>
        <p v-else class="text-muted">No metadata defined.</p>

        <small v-if="isAdmin && !hasSlackChannel" class="text-muted d-block mt-3">
          For Slack notifications, add metadata with key "Slack Channel ID".
        </small>

        <UpdateMetadataModal
          v-if="canEditMetadata"
          :project="project"
          @projectUpdated="$emit('project-updated')"
        />
      </div>
    </b-sidebar>

    <!-- Project Activity Sidebar -->
    <b-sidebar
      id="proj-history-sidebar"
      data-testid="proj-history-sidebar"
      title="Project Activity"
      right
      shadow
      backdrop
      :visible="activePanel === 'proj-history'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <History :histories="project.histories" :revertable="false" />
      </div>
    </b-sidebar>

    <!-- Project Revisions Sidebar -->
    <b-sidebar
      id="proj-revision-history-sidebar"
      data-testid="proj-revision-history-sidebar"
      title="Component Revisions"
      right
      shadow
      backdrop
      :visible="activePanel === 'proj-revision-history'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <RevisionHistory :project="project" :unique-component-names="uniqueComponentNames" />
      </div>
    </b-sidebar>
  </div>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import History from "../shared/History.vue";
import UpdateProjectDetailsModal from "../projects/UpdateProjectDetailsModal.vue";
import UpdateMetadataModal from "./UpdateMetadataModal.vue";
import RevisionHistory from "./RevisionHistory.vue";

export default {
  name: "ProjectSidepanels",
  components: {
    History,
    UpdateProjectDetailsModal,
    UpdateMetadataModal,
    RevisionHistory,
  },
  mixins: [RoleComparisonMixin],
  props: {
    project: {
      type: Object,
      required: true,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    activePanel: {
      type: String,
      default: null,
    },
    uniqueComponentNames: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    isAdmin() {
      return this.effectivePermissions === "admin";
    },
    canEditMetadata() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    hasMetadata() {
      return this.project.metadata && Object.keys(this.project.metadata).length > 0;
    },
    hasSlackChannel() {
      return this.project.metadata && this.project.metadata.hasOwnProperty("Slack Channel ID");
    },
  },
  methods: {
    percentage(value) {
      if (!this.project.details.total) return "0.00";
      return ((value / this.project.details.total) * 100).toFixed(2);
    },
  },
};
</script>

<style scoped>
/* Sidepanel content styling */
</style>
