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
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import SecurityRequirementsGuidesTable from "../security_requirements_guides/SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "../security_requirements_guides/SecurityRequirementsGuidesUpload";

export default {
  name: "Stigs",
  components: {
    BaseCommandBar,
    SecurityRequirementsGuidesTable,
    SecurityRequirementsGuidesUpload
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
      stigs: [],
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: 'STIGs', active: true }];
    },
  },
  mounted: function () {
    this.stigs = this.givenstigs;
  },
  methods: {
    openUploadModal() {
      this.showUploadComponent = true;
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
