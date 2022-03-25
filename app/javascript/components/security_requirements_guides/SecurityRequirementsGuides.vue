<template>
  <div>
    <b-row>
      <b-col md="10">
        <h1>Security Requirements Guides</h1>
        <h6 class="card-subtitle text-muted mb-2">
          Use the following guides to start a new Project
        </h6>
      </b-col>
      <b-col v-if="is_vulcan_admin" md="2" class="align-self-center">
        <b-button href="#" class="float-right" @click="showUploadComponent = !showUploadComponent">
          <i class="mdi mdi-file-upload-outline" aria-hidden="true" />
          Upload SRG
        </b-button>
      </b-col>
    </b-row>
    <SecurityRequirementsGuidesTable :srgs="srgs" :is_vulcan_admin="is_vulcan_admin" />
    <SecurityRequirementsGuidesUpload v-model="showUploadComponent" @uploaded="loadSrgs" />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import SecurityRequirementsGuidesTable from "./SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "./SecurityRequirementsGuidesUpload";

export default {
  name: "SecurityRequirementsGuides",
  components: { SecurityRequirementsGuidesTable, SecurityRequirementsGuidesUpload },
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
  mounted: function () {
    this.srgs = this.givensrgs;
  },
  methods: {
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
