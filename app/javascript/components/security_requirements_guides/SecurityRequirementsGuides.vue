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
          data-testid="upload-srg-btn"
          @click="openUploadModal"
        >
          <b-icon icon="cloud-upload" /> Upload SRG
        </b-button>
      </template>
      <template #right>
        <!-- No panels for list page -->
      </template>
    </BaseCommandBar>

    <p>
      <b>SRG Count:</b> <b-badge variant="secondary">{{ srgs.length }}</b-badge>
    </p>

    <SecurityRequirementsGuidesTable :srgs="srgs" :is_vulcan_admin="is_vulcan_admin" />

    <SecurityRequirementsGuidesUpload v-model="showUploadComponent" @uploaded="loadSrgs" />

    <!-- Export Modal -->
    <ExportModal
      v-model="showExportModal"
      :components="srgs"
      :formats="['xccdf', 'csv']"
      :column-definitions="csvColumns"
      title="Export SRGs"
      @export="handleExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import SecurityRequirementsGuidesTable from "./SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "./SecurityRequirementsGuidesUpload";
import ExportModal from "../shared/ExportModal.vue";
import { SRG_CSV_COLUMNS } from "../../constants/csvColumns";

export default {
  name: "SecurityRequirementsGuides",
  components: {
    BaseCommandBar,
    SecurityRequirementsGuidesTable,
    SecurityRequirementsGuidesUpload,
    ExportModal,
  },
  mixins: [AlertMixinVue],
  props: {
    givensrgs: {
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
      srgs: [],
      csvColumns: SRG_CSV_COLUMNS,
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: "SRGs", active: true }];
    },
  },
  mounted: function () {
    this.srgs = this.givensrgs;
  },
  methods: {
    openUploadModal() {
      this.showUploadComponent = true;
    },
    openExportModal() {
      this.showExportModal = true;
    },
    handleExport({ type, componentIds, columns }) {
      // For now, export each selected SRG individually (bulk export not yet implemented)
      componentIds.forEach((id) => {
        let url = `/srgs/${id}/export/${type}`;
        if (columns && columns.length > 0) {
          url += `?columns=${columns.join(",")}`;
        }
        window.open(url);
      });
    },
    loadSrgs: function () {
      axios
        .get("/srgs")
        .then(({ data }) => {
          this.srgs = data;
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped></style>
