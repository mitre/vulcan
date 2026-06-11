<template>
  <span>
    <b-button
      v-b-tooltip.hover="disabled ? disabledTitle : is_project_table ? 'Edit' : ''"
      :class="is_project_table ? '' : 'px-2 m-2'"
      :size="is_project_table ? 'sm' : undefined"
      :variant="is_project_table ? 'outline-secondary' : 'success'"
      :disabled="disabled"
      :title="disabled ? disabledTitle : is_project_table ? 'Edit' : ''"
      @click="showModal()"
    >
      <b-icon :icon="is_project_table ? 'pencil' : 'wrench'" aria-hidden="true" />
      <span v-if="!is_project_table">Update Details</span>
    </b-button>
    <b-modal
      ref="updateProjectDetailsModal"
      title="Update Project Details"
      size="lg"
      ok-title="Update Project Details"
      @show="resetModal()"
      @ok="updateProjectDetails()"
    >
      <b-form @submit="updateProjectDetails()">
        <!-- Name of the project -->
        <b-form-group label="Name">
          <b-form-input v-model="name" placeholder="Project Name" required autocomplete="off" />
        </b-form-group>
        <!-- Description -->
        <b-form-group label="Description">
          <b-form-textarea v-model="description" placeholder="" rows="3" />
        </b-form-group>

        <!-- Allow the enter button to submit the form -->
        <b-btn type="submit" class="d-none" @click.prevent="updateProjectDetails()" />
      </b-form>
    </b-modal>
  </span>
</template>

<script>
import { updateProject } from "../../api/projectsApi";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "UpdateProjectDetailsModal",
  // AlertMixin migrates with the toast architecture (useToast). FormMixin
  // was a dead import — authenticityToken was never consumed.
  mixins: [AlertMixinVue],
  props: {
    project: {
      type: Object,
      required: true,
    },
    is_project_table: {
      type: Boolean,
      required: false,
      default: false,
    },
    // Per the locked vulcan-disabled-not-hidden rule: render the opener
    // button visibly disabled with an explanatory tooltip when the current
    // user can't perform this action, instead of hiding the control with v-if.
    disabled: {
      type: Boolean,
      default: false,
    },
    disabledTitle: {
      type: String,
      default: "",
    },
  },
  data: function () {
    return {
      name: this.project.name,
      description: this.project.description,
    };
  },
  methods: {
    resetModal: function () {
      this.name = this.project.name;
      this.description = this.project.description;
    },
    showModal: function () {
      this.$refs["updateProjectDetailsModal"].show();
    },
    updateProjectDetails: function () {
      this.$refs["updateProjectDetailsModal"].hide();
      updateProject(this.project.id, { name: this["name"], description: this["description"] })
        .then(this.editProjectSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    editProjectSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("projectUpdated");
    },
  },
};
</script>

<style scoped></style>
