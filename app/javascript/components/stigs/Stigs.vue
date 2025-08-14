<template>
  <div>
    <b-row>
      <b-col md="10">
        <h1>
          Security Technical Implementation Guides
          <b-badge variant="secondary">{{ stigs.length }}</b-badge>
        </h1>
        <h6 class="card-subtitle text-muted mb-2">Published STIGs</h6>
      </b-col>
      <b-col v-if="is_vulcan_admin" md="2" class="align-self-center">
        <b-button href="#" class="float-right" @click="showUploadComponent = !showUploadComponent">
          <b-icon icon="cloud-upload" aria-hidden="true" />
          Upload STIG
        </b-button>
      </b-col>
    </b-row>
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
import SecurityRequirementsGuidesTable from "../security_requirements_guides/SecurityRequirementsGuidesTable";
import SecurityRequirementsGuidesUpload from "../security_requirements_guides/SecurityRequirementsGuidesUpload";

export default {
  name: "Stigs",
  components: { SecurityRequirementsGuidesTable, SecurityRequirementsGuidesUpload },
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
  mounted: function () {
    this.stigs = this.givenstigs;
  },
  methods: {
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
