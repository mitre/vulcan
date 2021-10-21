<template>
  <div>
    <!-- Modal trigger button -->
    <span @click="showModal()">
      <slot name="opener">
        <b-button class="px-2 m-2" variant="primary"> Create a New Component </b-button>
      </slot>
    </span>

    <!-- Add component modal -->
    <b-modal
      ref="AddComponentModal"
      title="Create a New Component"
      size="lg"
      ok-title="Create Component"
      @show="fetchSrgs"
      @ok="createComponent"
    >
      <!-- Searchable projects -->
      <b-form @submit="createComponent()">
        <input
          id="NewProjectAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        />
        <b-row>
          <b-col>
            <!-- Select a SRG -->
            <b-form-group
              v-if="predetermined_security_requirements_guide_id == null"
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
            <!-- Name the component -->
            <b-form-group label="Component Version">
              <b-form-input
                v-model="version"
                placeholder="Component V1R1"
                required
                autocomplete="off"
              />
            </b-form-group>
            <!-- Set the prefix -->
            <b-form-group
              label="STIG ID Prefix"
              description="STIG IDs for each control will be automatically generated based on this prefix value"
            >
              <b-form-input
                v-model="prefix"
                placeholder="Example... ABCD-EF, ABCD-00"
                required
                autocomplete="off"
              />
            </b-form-group>
          </b-col>
        </b-row>
      </b-form>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import VueSimpleSuggest from "vue-simple-suggest";
import "vue-simple-suggest/dist/styles.css";

export default {
  name: "NewComponentModal",
  components: {
    VueSimpleSuggest,
  },
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    project_id: {
      type: Number,
      required: true,
    },
    predetermined_prefix: {
      type: String,
      required: false,
      default: "",
    },
    predetermined_security_requirements_guide_id: {
      type: Number,
      required: false,
      default: null,
    },
    predetermined_component_id: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data: function () {
    return {
      prefix: this.predetermined_prefix,
      security_requirements_guide_id: this.predetermined_security_requirements_guide_id,
      component_id: this.predetermined_component_id,
      version: "",
      srgs: [],
    };
  },
  methods: {
    fetchSrgs: function (_bvModalEvt) {
      axios.get("/srgs").then((response) => {
        this.srgs = response.data;
      });
    },
    showModal: function () {
      this.version = "";
      this.$refs["AddComponentModal"].show();
    },
    createComponent: function (bvModalEvt) {
      bvModalEvt.preventDefault();

      // Guard before POST
      if (!this.prefix) {
        this.$bvToast.toast("Please enter a prefix", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        return;
      }
      if (!this.security_requirements_guide_id) {
        this.$bvToast.toast("Please select an SRG", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        return;
      }
      if (!this.version) {
        this.$bvToast.toast("Please enter a version", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        return;
      }

      let payload = {
        component: {
          prefix: this.prefix,
          security_requirements_guide_id: this.security_requirements_guide_id,
          version: this.version,
          component_id: this.component_id,
        },
      };

      axios
        .post(`/projects/${this.project_id}/components`, payload)
        .then(this.addComponentSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    addComponentSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$refs["AddComponentModal"].hide();
      this.$emit("projectUpdated");
    },
    setSelectedSrg: function (srg) {
      this.security_requirements_guide_id = srg.id;
    },
  },
};
</script>

<style scoped>
.flex1 {
  flex: 1;
}
</style>
