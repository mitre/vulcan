<template>
  <div>
    <b-button class="px-2 m-2" variant="success" @click="showModal()"> Update Details </b-button>
    <b-modal
      ref="updateComponentDetailsModal"
      title="Update Details"
      size="lg"
      ok-title="Update Details"
      @show="resetModal()"
      @ok="updateComponentDetails()"
    >
      <b-form @submit="updateComponentDetails()">
        <!-- Name the component -->
        <b-form-group label="Name">
          <b-form-input v-model="name" placeholder="Component Name" required autocomplete="off" />
        </b-form-group>
        <!-- Version and Release -->
        <b-form-row>
          <b-col>
            <b-form-group label="Version">
              <b-form-input v-model="version" autocomplete="off" />
            </b-form-group>
          </b-col>
          <b-col>
            <b-form-group label="Release">
              <b-form-input v-model="release" autocomplete="off" />
            </b-form-group>
          </b-col>
        </b-form-row>
        <!-- Title -->
        <b-form-group label="Title">
          <b-form-input v-model="title" placeholder="Component Title" required autocomplete="off" />
        </b-form-group>
        <!-- Description -->
        <b-form-group label="Description">
          <b-form-textarea v-model="description" placeholder="" rows="3" />
        </b-form-group>
        <!-- Allow the enter button to submit the form -->
        <b-btn type="submit" class="d-none" @click.prevent="updateComponentDetails()" />
      </b-form>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "UpdateComponentDetailsModal",
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      name: this.component.name,
      version: this.component.version,
      release: this.component.release,
      title: this.component.title,
      description: this.component.description,
    };
  },
  methods: {
    resetModal: function () {
      this.name = this.component.name;
      this.version = this.component.version;
      this.release = this.component.release;
      this.title = this.component.title;
      this.description = this.component.description;
    },
    showModal: function () {
      this.$refs["updateComponentDetailsModal"].show();
    },
    updateComponentDetails: function () {
      this.$refs["updateComponentDetailsModal"].hide();
      let payload = { component: {} };
      ["name", "version", "release", "title", "description"].forEach((attr) => {
        if (payload.component[attr] !== this[attr]) {
          payload.component[attr] = this[attr];
        }
      });
      axios
        .put(`/components/${this.component.id}`, payload)
        .then(this.updateComponentDetailsSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    updateComponentDetailsSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("componentUpdated");
    },
  },
};
</script>

<style scoped></style>
