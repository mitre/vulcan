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
        <b-button
          v-if="is_vulcan_admin"
          variant="primary"
          size="sm"
          class="ml-2"
          data-testid="upload-stig-btn"
          @click="openUploadModal"
        >
          <b-icon icon="cloud-upload" /> Upload STIG
        </b-button>
      </template>
      <template #right>
        <!-- No panels for list page -->
      </template>
    </BaseCommandBar>

    <p>
      <b>STIG Count:</b> <b-badge variant="secondary">{{ stigs.length }}</b-badge>
    </p>

    <SecurityRequirementsGuidesTable :srgs="stigs" :is_vulcan_admin="is_vulcan_admin" type="STIG" />

    <SecurityRequirementsGuidesUpload
      v-model="showUploadComponent"
      post_path="/stigs"
      @uploaded="loadStigs"
    />

    <!-- Export Modal -->
    <ExportModal
      v-model="showExportModal"
      :components="stigs"
      :formats="['xccdf', 'csv']"
      :column-definitions="csvColumns"
      title="Export STIGs"
      @export="handleExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import SecurityRequirementsGuidesTable from "../security_requirements_guides/SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "../security_requirements_guides/SecurityRequirementsGuidesUpload";
import ExportModal from "../shared/ExportModal.vue";
import { STIG_CSV_COLUMNS } from "../../constants/csvColumns";

export default {
  name: "Stigs",
  components: {
    BaseCommandBar,
    SecurityRequirementsGuidesTable,
    SecurityRequirementsGuidesUpload,
    ExportModal,
  },
  mixins: [AlertMixinVue],
  props: {
    givenstigs: {
      type: Array,
      required: true,
    },
    is_vulcan_admin: {
      type: Boolean,
      required: true,
    },
  },
  data: function () {
    return {
      showUploadComponent: false,
      showExportModal: false,
      stigs: [],
      csvColumns: STIG_CSV_COLUMNS,
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: "STIGs", active: true }];
    },
  },
  mounted: function () {
    this.stigs = this.givenstigs;
  },
  methods: {
    openUploadModal() {
      this.showUploadComponent = true;
    },
    openExportModal() {
      this.showExportModal = true;
    },
    handleExport({ type, componentIds, columns }) {
      // For now, export each selected STIG individually (bulk export not yet implemented)
      componentIds.forEach((id) => {
        let url = `/stigs/${id}/export/${type}`;
        if (columns && columns.length > 0) {
          url += `?columns=${columns.join(",")}`;
        }
        window.open(url);
      });
    },
    loadStigs: function () {
      axios
        .get("/stigs")
        .then(({ data }) => {
          this.stigs = data;
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped></style>
