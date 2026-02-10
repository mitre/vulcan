<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <b-button
          variant="outline-secondary"
          size="sm"
          data-testid="download-btn"
          @click="openExportModal"
        >
          <b-icon icon="download" /> Download
        </b-button>
      </template>
      <template #right>
        <!-- No panels for list page -->
      </template>
    </BaseCommandBar>

    <p>
      <b>Component Count:</b> <span>{{ components.length }}</span>
    </p>

    <SecurityRequirementsGuidesTable :srgs="components" :is_vulcan_admin="false" type="Component" />

    <!-- Export Modal -->
    <ExportModal
      v-model="showExportModal"
      :components="components"
      @export="handleExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import axios from "axios";
import SecurityRequirementsGuidesTable from "../security_requirements_guides/SecurityRequirementsGuidesTable.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import ExportModal from "../shared/ExportModal.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "Projectcomponent",
  components: {
    SecurityRequirementsGuidesTable,
    BaseCommandBar,
    ExportModal,
  },
  mixins: [AlertMixinVue],
  props: {
    components: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      showExportModal: false,
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: "Released Components", active: true }];
    },
  },
  methods: {
    openExportModal() {
      this.showExportModal = true;
    },
    handleExport({ type, componentIds }) {
      this.downloadExport(type, componentIds);
    },
    downloadExport(type, componentIds) {
      // Export released components
      const idsParam = componentIds.join(",");
      axios
        .get(`/components/export/${type}?component_ids=${idsParam}`)
        .then(() => {
          window.open(`/components/export/${type}?component_ids=${idsParam}`);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped></style>
