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

    <!-- Component search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <b-icon icon="search" aria-hidden="true" />
            </div>
          </div>
          <input
            id="componentSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search components..."
          />
        </div>
      </div>
    </div>

    <br />

    <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
      <b-col v-for="component in sortedFilteredComponents()" :key="component.id">
        <ComponentCard :component="component" :actionable="false" />
      </b-col>
    </b-row>

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
import ComponentCard from "./ComponentCard.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import ExportModal from "../shared/ExportModal.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "Projectcomponent",
  components: {
    ComponentCard,
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
      search: "",
      showExportModal: false,
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: 'Released Components', active: true }];
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
      const idsParam = componentIds.join(',');
      axios
        .get(`/components/export/${type}?component_ids=${idsParam}`)
        .then(() => {
          window.open(`/components/export/${type}?component_ids=${idsParam}`);
        })
        .catch(this.alertOrNotifyResponse);
    },
    sortedFilteredComponents() {
      let downcaseSearch = this.search.toLowerCase();
      let filteredComponents = this.components.filter((component) =>
        component.name.toLowerCase().includes(downcaseSearch),
      );

      return filteredComponents.sort((c_1, c_2) => {
        return c_1.name.toLowerCase().localeCompare(c_2.name.toLowerCase());
      });
    },
  },
};
</script>

<style scoped></style>
