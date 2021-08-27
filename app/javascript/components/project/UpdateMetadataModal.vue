<template>
  <div>
    <b-button class="px-2 m-2" variant="success" @click="showModal()"> Update Metadata </b-button>
    <b-modal
      ref="updateMetadataModal"
      title="Update Project Metadata"
      size="lg"
      ok-title="Update"
      @show="resetModal()"
      @ok="updateMetadata()"
    >
      <b-form @submit="updateMetadata()">
        <div v-for="(data, index) in metadata" :key="index" class="pb-2">
          <b-input-group>
            <b-form-input v-model="data.key" placeholder="Key" required />
            <b-form-input v-model="data.value" placeholder="Value" required />
            <!-- Add button for removing metadata entry -->
            <b-button variant="danger" size="sm" class="ml-2" @click="removeMetadata(index)">
              X
            </b-button>
          </b-input-group>
        </div>
        <b-row>
          <b-col>
            <b-button @click="addMetadata">Add</b-button>
          </b-col>
        </b-row>
        <!-- Allow the enter button to submit the form -->
        <b-btn type="submit" class="d-none" @click.prevent="updateMetadata()" />
      </b-form>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

function initialState(project) {
  return {
    metadata: Object.entries(project.metadata || {}).map(([key, value]) => {
      return { key: key, value: value };
    }),
  };
}

export default {
  name: "UpdateMetadataModal",
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return initialState(this.project);
  },
  methods: {
    resetModal: function () {
      Object.assign(this.$data, initialState(this.project));
    },
    showModal: function () {
      this.$refs["updateMetadataModal"].show();
    },
    addMetadata: function () {
      this.metadata.push({ key: "", value: "" });
    },
    updateMetadata: function () {
      this.$refs["updateMetadataModal"].hide();
      let payload = {
        project: {
          project_metadata_attributes: {
            data: this.metadata.reduce((acc, curr) => {
              acc[curr.key] = curr.value;
              return acc;
            }, {}),
          },
        },
      };

      axios
        .put(`/projects/${this.project.id}`, payload)
        .then(this.updateMetadataSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    updateMetadataSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("projectUpdated");
    },
    removeMetadata: function (index) {
      this.metadata.splice(index, 1);
    },
  },
};
</script>

<style scoped></style>
