<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <b-button
          v-if="is_vulcan_admin"
          variant="primary"
          size="sm"
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
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import SecurityRequirementsGuidesTable from "./SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "./SecurityRequirementsGuidesUpload";

export default {
  name: "SecurityRequirementsGuides",
  components: {
    BaseCommandBar,
    SecurityRequirementsGuidesTable,
    SecurityRequirementsGuidesUpload,
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
      srgs: [],
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
