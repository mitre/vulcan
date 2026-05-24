<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <BaseCommandBar>
      <template #left>
        <b-button
          variant="outline-secondary"
          size="sm"
          data-testid="download-btn"
          @click="showExportModal = true"
        >
          <b-icon icon="download" /> Download
        </b-button>
        <b-button
          v-if="isAdmin && config.canUpload"
          variant="primary"
          size="sm"
          class="ml-2"
          data-testid="upload-btn"
          @click="showUploadComponent = true"
        >
          <b-icon icon="cloud-upload" /> Upload {{ label }}
        </b-button>
      </template>
      <template #right />
    </BaseCommandBar>

    <p>
      <b>{{ label }} Count:</b>
      <b-badge variant="secondary">{{ items.length }}</b-badge>
    </p>

    <BenchmarkTable :srgs="items" :is_vulcan_admin="isAdmin" :type="type" @deleted="loadItems" />

    <BenchmarkUpload
      v-if="config.canUpload"
      v-model="showUploadComponent"
      :post_path="apiPath"
      @uploaded="loadItems"
    />

    <ExportModal
      v-model="showExportModal"
      :components="items"
      :formats="['xccdf', 'csv']"
      :column-definitions="csvColumns"
      :title="`Export ${pluralLabel}`"
      @export="handleExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import BaseCommandBar from "./BaseCommandBar.vue";
import BenchmarkTable from "./BenchmarkTable.vue";
import BenchmarkUpload from "./BenchmarkUpload.vue";
import ExportModal from "./ExportModal.vue";
import { SRG_CSV_COLUMNS, STIG_CSV_COLUMNS } from "../../constants/csvColumns";

const CONFIG = {
  SRG: { label: "SRG", plural: "SRGs", api: "/srgs", columns: SRG_CSV_COLUMNS, canUpload: true },
  STIG: {
    label: "STIG",
    plural: "STIGs",
    api: "/stigs",
    columns: STIG_CSV_COLUMNS,
    canUpload: true,
  },
  Component: {
    label: "Component",
    plural: "Released Components",
    api: "/components",
    columns: null,
    canUpload: false,
    bulkExport: true,
  },
};

export default {
  name: "BenchmarkListPage",
  components: { BaseCommandBar, BenchmarkTable, BenchmarkUpload, ExportModal },
  mixins: [AlertMixinVue],
  props: {
    type: { type: String, required: true, validator: (v) => v in CONFIG },
    givenItems: { type: Array, required: true },
    isAdmin: { type: Boolean, required: true },
  },
  data() {
    return {
      showUploadComponent: false,
      showExportModal: false,
      items: [],
    };
  },
  computed: {
    config() {
      return CONFIG[this.type];
    },
    label() {
      return this.config.label;
    },
    pluralLabel() {
      return this.config.plural;
    },
    apiPath() {
      return this.config.api;
    },
    csvColumns() {
      return this.config.columns;
    },
    breadcrumbs() {
      return [{ text: this.pluralLabel, active: true }];
    },
  },
  mounted() {
    this.items = this.givenItems;
  },
  methods: {
    handleExport({ type, componentIds, columns }) {
      if (this.config.bulkExport) {
        const url = `${this.apiPath}/bulk_export/${type}?component_ids=${componentIds.join(",")}`;
        window.open(url);
      } else {
        componentIds.forEach((id) => {
          let url = `${this.apiPath}/${id}/export/${type}`;
          if (columns && columns.length > 0) {
            url += `?columns=${columns.join(",")}`;
          }
          window.open(url);
        });
      }
    },
    loadItems() {
      axios
        .get(this.apiPath)
        .then(({ data }) => {
          this.items = data;
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>
