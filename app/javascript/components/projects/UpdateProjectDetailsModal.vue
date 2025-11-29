<script>
import axios from 'axios'
import AlertMixinVue from '../../mixins/AlertMixin.vue'
import FormMixinVue from '../../mixins/FormMixin.vue'

export default {
  name: 'UpdateProjectDetailsModal',
  mixins: [AlertMixinVue, FormMixinVue],
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
  },
  data() {
    return {
      name: this.project.name,
      description: this.project.description,
    }
  },
  methods: {
    resetModal() {
      this.name = this.project.name
      this.description = this.project.description
    },
    showModal() {
      this.$refs.updateProjectDetailsModal.show()
    },
    updateProjectDetails() {
      this.$refs.updateProjectDetailsModal.hide()
      const payload = { project: { name: this.name, description: this.description } }
      axios
        .put(`/projects/${this.project.id}`, payload)
        .then(this.editProjectSuccess)
        .catch(this.alertOrNotifyResponse)
    },
    editProjectSuccess(response) {
      this.alertOrNotifyResponse(response)
      this.$emit('projectUpdated')
    },
  },
}
</script>

<template>
  <span>
    <b-button
      class="px-2 m-2"
      :variant="is_project_table ? 'primary' : 'success'"
      @click="showModal()"
    >
      <i v-if="is_project_table" class="bi bi-wrench" aria-hidden="true" />
      {{ is_project_table ? "Update" : "Update Details" }}
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
        <b-button type="submit" class="d-none" @click.prevent="updateProjectDetails()" />
      </b-form>
    </b-modal>
  </span>
</template>

<style scoped></style>
