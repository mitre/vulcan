<script>
export default {
  name: 'NewProject',
  computed: {
    // Only include CSRF token, not JSON headers since this is HTML form submission
    authenticityToken() {
      return document.querySelector('meta[name=\'csrf-token\']').getAttribute('content')
    },
  },
  methods: {
    formAction() {
      return '/projects'
    },
  },
}
</script>

<template>
  <div class="p-3">
    <h1>Start a New Project</h1>
    <b-form :action="formAction()" method="post">
      <input
        id="NewProjectAuthenticityToken"
        type="hidden"
        name="authenticity_token"
        :value="authenticityToken"
      >
      <b-row>
        <b-col md="6">
          <!-- Name -->
          <b-form-group label="Project Title">
            <b-form-input
              placeholder="Project Title"
              required
              name="project[name]"
              autocomplete="off"
            />
          </b-form-group>
          <!-- Description -->
          <b-form-group label="Project Description">
            <b-form-textarea
              placeholder="Project Description"
              required
              name="project[description]"
              autocomplete="off"
            />
          </b-form-group>
          <!-- Visibility -->
          <b-form-group
            label="Visibility"
            description="Marking the project as discoverable means that non-members will see the project's details (name, description, etc.) on the projects' list and can request access."
          >
            <b-form-select
              required
              name="project[visibility]"
              :options="['discoverable', 'hidden']"
            />
          </b-form-group>
          <!-- Slack Channel ID -->
          <b-form-group
            label="Slack Channel ID"
            description="Provide a slack channel ID for slack notification about activities on this project"
          >
            <b-form-input
              placeholder="Example... C123456, #general"
              name="project[slack_channel_id]"
              autocomplete="off"
            />
          </b-form-group>
          <b-button type="submit" variant="primary">
            Create Project
          </b-button>
        </b-col>
      </b-row>
    </b-form>
  </div>
</template>

<style scoped></style>
