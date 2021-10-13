<template>
  <div class="p-3">
    <h1>Start a New Project</h1>
    <b-form :action="formAction()" method="post">
      <input
        id="NewProjectAuthenticityToken"
        type="hidden"
        name="authenticity_token"
        :value="authenticityToken"
      />
      <b-row>
        <b-col md="6">
          <b-form-group label="Project Title">
            <b-form-input
              placeholder="Project Title"
              required
              name="project[name]"
              autocomplete="off"
            />
          </b-form-group>
          <b-button type="submit" variant="primary"> Create Project </b-button>
        </b-col>
      </b-row>
    </b-form>
  </div>
</template>

<script>
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "NewProject",
  mixins: [FormMixinVue],
  methods: {
    formAction: function () {
      return "/projects";
    },
  },
};
</script>

<style scoped></style>
