<template>
  <div>
    <b-row>
      <b-col md="10">
        <h1>Security Requirements Guides</h1>
        <h6 class="card-subtitle text-muted mb-2">
          Use the following guides to start a new Project
        </h6>
      </b-col>
      <b-col md="2" class="align-self-center">
        <b-button href="#" class="float-right" @click="showUploadComponent = !showUploadComponent">
          <i class="mdi mdi-file-upload-outline" aria-hidden="true" />
          Upload SRG
        </b-button>
      </b-col>
    </b-row>
    <SecurityRequirementsGuidesTable :srgs="srgs" :refresh="refresh" />
    <SecurityRequirementsGuidesUpload v-model="showUploadComponent" @uploaded="srgUploaded" />
  </div>
</template>

<script>
import SecurityRequirementsGuidesTable from "./SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "./SecurityRequirementsGuidesUpload";

export default {
  name: "SecurityRequirementsGuides",
  components: { SecurityRequirementsGuidesTable, SecurityRequirementsGuidesUpload },
  props: {
    srgs: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      showUploadComponent: false,
      refresh: false,
    };
  },
  methods: {
    srgUploaded: function () {
      this.refresh = !this.refresh;
    },
  },
};
</script>

<style scoped></style>
