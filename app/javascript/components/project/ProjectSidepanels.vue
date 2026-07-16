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
        <!-- Counts read the typed sections; percentages stay against
             the type-agnostic total, so the two kind sections together
             account for the Total row. -->
        <p class="mb-1 font-weight-bold">STIG ({{ project.details.stig.total }})</p>
        <p class="mb-1">
          <strong>Applicable - Configurable:</strong> {{ project.details.stig.ac }} ({{
            percentage(project.details.stig.ac)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Applicable - Inherently Meets:</strong> {{ project.details.stig.aim }} ({{
            percentage(project.details.stig.aim)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Applicable - Does Not Meet:</strong> {{ project.details.stig.adnm }} ({{
            percentage(project.details.stig.adnm)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Not Applicable:</strong> {{ project.details.stig.na }} ({{
            percentage(project.details.stig.na)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Not Yet Determined:</strong> {{ project.details.stig.nyd }} ({{
            percentage(project.details.stig.nyd)
          }}%)
        </p>

        <p class="mb-1 mt-2 font-weight-bold">SRG ({{ project.details.srg.total }})</p>
        <p class="mb-1">
          <strong>Applicable:</strong> {{ project.details.srg.applicable }} ({{
            percentage(project.details.srg.applicable)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Not Applicable:</strong> {{ project.details.srg.na }} ({{
            percentage(project.details.srg.na)
          }}%)
        </p>
        <p class="mb-1">
          <strong>Not Yet Determined:</strong> {{ project.details.srg.nyd }} ({{
            percentage(project.details.srg.nyd)
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
          v-if="canAdmin"
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

        <small v-if="canAdmin && !hasSlackChannel" class="text-muted d-block mt-3">
          For Slack notifications, add metadata with key "Slack Channel ID".
        </small>

        <UpdateMetadataModal
          v-if="canEdit"
          :project="project"
          @projectUpdated="$emit('project-updated')"
        />
      </div>
    </b-sidebar>

    <!-- Project Changelog Sidebar -->
    <b-sidebar
      id="proj-history-sidebar"
      data-testid="proj-history-sidebar"
      title="Project Changelog"
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

    <!-- Version Comparison Sidebar -->
    <b-sidebar
      id="proj-revision-history-sidebar"
      data-testid="proj-revision-history-sidebar"
      title="Version Comparison"
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
import { usePermissions } from "../../composables/usePermissions";
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
  props: {
    project: {
      type: Object,
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
  setup() {
    // Permissions are provided by the page root (Project.vue) — see usePermissions.
    const { canAdmin, canEdit } = usePermissions();
    return { canAdmin, canEdit };
  },
  computed: {
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
