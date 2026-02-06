<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <b-button variant="outline-secondary" size="sm" :href="listPath">
          <b-icon icon="arrow-left" /> Back to {{ typeLabel }}s
        </b-button>
        <b-button variant="outline-secondary" size="sm" class="ml-2" @click="openExportModal">
          <b-icon icon="download" /> Download
        </b-button>
      </template>
      <template #right>
        <!-- No panels for viewer page -->
      </template>
    </BaseCommandBar>

    <!-- Three-Column Layout -->
    <b-row>
      <!-- Left: Item List -->
      <b-col md="3">
        <RuleList
          :rules="filteredItems"
          :initial-selected-rule="selectedItem"
          :type="type"
          @rule-selected="selectItem"
        />
      </b-col>

      <!-- Middle: Item Details -->
      <b-col md="6">
        <RuleDetails :selected-rule="selectedItem" :type="type" />
      </b-col>

      <!-- Right: Item Overview -->
      <b-col md="3">
        <RuleOverview :selected-rule="selectedItem" :type="type" />
      </b-col>
    </b-row>

    <!-- Export Modal -->
    <ExportModal
      v-if="showExportModal"
      v-model="showExportModal"
      :components="[benchmark]"
      @export="handleExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import axios from "axios";
import BaseCommandBar from "./BaseCommandBar.vue";
import ExportModal from "./ExportModal.vue";
import RuleList from "../benchmarks/RuleList.vue";
import RuleDetails from "../benchmarks/RuleDetails.vue";
import RuleOverview from "../benchmarks/RuleOverview.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { useBenchmarkViewer } from "../../composables";

export default {
  name: "BenchmarkViewer",
  components: {
    BaseCommandBar,
    ExportModal,
    RuleList,
    RuleDetails,
    RuleOverview,
  },
  mixins: [AlertMixinVue],
  props: {
    benchmark: {
      type: Object,
      required: true,
    },
    type: {
      type: String,
      required: true,
      validator: (value) => ["stig", "srg", "cis"].includes(value),
    },
  },
  setup(props) {
    const {
      selectedItem,
      items,
      filteredItems,
      searchTerm,
      benchmarkType,
      itemTypeName,
      selectItem,
      selectNext,
      selectPrevious,
      setSearch,
    } = useBenchmarkViewer(props.benchmark, props.type);

    return {
      selectedItem,
      items,
      filteredItems,
      searchTerm,
      benchmarkType,
      itemTypeName,
      selectItem,
      selectNext,
      selectPrevious,
      setSearch,
    };
  },
  data() {
    return {
      showExportModal: false,
    };
  },
  computed: {
    breadcrumbs() {
      return [
        { text: this.typeLabel + "s", href: this.listPath },
        { text: `${this.benchmark.title} ${this.benchmark.version || ""}`, active: true },
      ];
    },
    typeLabel() {
      const labels = {
        stig: "STIG",
        srg: "SRG",
        cis: "CIS Benchmark",
      };
      return labels[this.type] || "Benchmark";
    },
    listPath() {
      const paths = {
        stig: "/stigs",
        srg: "/srgs",
        cis: "/stigs", // CIS shown in STIGs list
      };
      return paths[this.type] || "/";
    },
  },
  methods: {
    openExportModal() {
      this.showExportModal = true;
    },
    handleExport({ type, componentIds }) {
      const benchmarkType = this.type === "srg" ? "srgs" : "stigs";
      axios
        .get(`/${benchmarkType}/${this.benchmark.id}/export/${type}`)
        .then(() => {
          window.open(`/${benchmarkType}/${this.benchmark.id}/export/${type}`);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>
