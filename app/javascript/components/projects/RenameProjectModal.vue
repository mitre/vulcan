<template>
  <span>
    <b-button class="px-2 m-2" variant="primary" @click="showModal()">
      <i class="mdi mdi-wrench" aria-hidden="true" />
      Rename
    </b-button>
    <b-modal
      ref="renameProjectModal"
      title="Rename"
      size="lg"
      ok-title="Rename"
      @show="resetModal()"
      @ok="renameProject()"
    >
      <b-form @submit="renameProject()">
        <!-- Name the component -->
        <b-form-group label="Name">
          <b-form-input v-model="name" placeholder="Project Name" required autocomplete="off" />
        </b-form-group>

        <!-- Allow the enter button to submit the form -->
        <b-btn type="submit" class="d-none" @click.prevent="renameProject()" />
      </b-form>
    </b-modal>
  </span>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "RenameProjectModal",
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      name: this.project.name,
    };
  },
  methods: {
    resetModal: function () {
      this.name = this.project.name;
    },
    showModal: function () {
      this.$refs["renameProjectModal"].show();
    },
    renameProject: function () {
      this.$refs["renameProjectModal"].hide();
      let payload = { project: { name: this["name"] } };
      axios
        .put(`/projects/${this.project.id}`, payload)
        .then(this.renameProjectSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    renameProjectSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("projectRenamed");
    },
  },
};
</script>

<style scoped></style>
