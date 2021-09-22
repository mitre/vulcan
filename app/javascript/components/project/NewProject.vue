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
      <input
        type="hidden"
        name="project[srg_id]"
        :value="selectedSrgId"
      />
      <b-row>
        <b-col md="6">
          <b-form-group
            label="Select a Security Requirements Guide"
          >
            <vue-simple-suggest
              ref="srgSearch"
              :list="srgs"
              display-attribute="title"
              value-attribute="id"
              placeholder="Search for an SRG..."
              :min-length="0"
              :number="0"
              @select="setSelectedSrg($refs.srgSearch.selected)"
            />
          </b-form-group>
          <b-form-group
            label="Project Title"
          >
            <b-form-input
              placeholder="Project Title"
              required
              name="project[name]"
              autocomplete="off"
            />
          </b-form-group>
          <b-form-group
            label="STIG ID Prefix"
            description="STIG IDs for each control will be automatically generated based on this prefix value"
          >
            <b-form-input
              placeholder="Example... ABCD-EF, ABCD-00"
              name="project[prefix]"
              required
              autocomplete="off"
            />
          </b-form-group>
          <b-button
            type="submit"
            variant="primary"
          >
            Create Project
          </b-button>
        </b-col>
      </b-row>
    </b-form>
  </div>
</template>

<script>
import VueSimpleSuggest from "vue-simple-suggest";
import "vue-simple-suggest/dist/styles.css";
import FormMixinVue from "../../mixins/FormMixin.vue";


export default {
  name: "NewProject",
  mixins: [FormMixinVue],
  components: { VueSimpleSuggest },
  props: {
    srgs: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      selectedSrgId: "",
    }
  },
  methods: {
    formAction: function () {
      return "/projects";
    },
    setSelectedSrg: function (srg) {
      this.selectedSrgId = srg.id;
    }
  }
};
</script>

<style scoped></style>
