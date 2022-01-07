<template>
  <span>
    <!-- Modal trigger button -->
    <span @click="showModal()">
      <slot name="opener">
        <b-button class="px-2 m-2" variant="primary"> {{ buttonText }} </b-button>
      </slot>
    </span>

    <!-- Add component modal -->
    <b-modal
      ref="AddComponentModal"
      :title="submitText"
      size="lg"
      :ok-title="loading ? 'Loading...' : submitText"
      :ok-disabled="loading"
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
            <b-form-group label="Name and Version">
              <b-form-input
                v-model="version"
                placeholder="Component V1R1"
                required
                autocomplete="off"
              />
            </b-form-group>
            <!-- Import from existing spreadsheet -->
            <b-form-group
              v-if="spreadsheet_import"
              label="Import Existing SRG Spreadsheet"
              description="Provide an existing filled out SRG Spreadsheet for import into the Vulcan application"
            >
              <b-form-file
                v-model="file"
                placeholder="Choose or drop a filled out SRG Spreadsheet here..."
                drop-placeholder="Drop SRG Spreadsheet here..."
                accept="appliction/xlsx, application/xls"
              />
            </b-form-group>
            <!-- Set the prefix -->
            <b-form-group
              v-else
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
  </span>
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
    spreadsheet_import: {
      type: Boolean,
      default: false,
    },
    component_to_duplicate: {
      type: Number,
      required: false,
    },
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
  },
  data: function () {
    return {
      loading: false,
      prefix: this.predetermined_prefix,
      security_requirements_guide_id: this.predetermined_security_requirements_guide_id,
      version: "",
      srgs: [],
      file: null,
    };
  },
  computed: {
    buttonText: function () {
      if (this.spreadsheet_import) {
        return "Import From Spreadsheet";
      } else if (this.newComponent) {
        return "Create a New Component";
      } else {
        return "Duplicate Component";
      }
    },
    newComponent: function () {
      return !this.component_to_duplicate;
    },
    submitText: function () {
      if (this.spreadsheet_import) {
        return "Import Component";
      } else if (this.newComponent) {
        return "Create Component";
      } else {
        return "Duplicate Component";
      }
    },
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
      this.loading = true;
      let failed = false;
      bvModalEvt.preventDefault();

      // Guard before POST
      if (!this.prefix && !this.spreadsheet_import) {
        this.$bvToast.toast("Please enter a prefix", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        failed = true;
      }
      if (!this.file && this.spreadsheet_import) {
        this.$bvToast.toast("Please select a spreadsheet to import", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        failed = true;
      }
      if (!this.security_requirements_guide_id) {
        this.$bvToast.toast("Please select an SRG", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        failed = true;
      }
      if (!this.version) {
        this.$bvToast.toast("Please enter a version", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        failed = true;
      }
      if (failed) {
        this.loading = false;
        return;
      }

      let formData = new FormData();
      formData.append(
        "component[security_requirements_guide_id]",
        this.security_requirements_guide_id
      );
      formData.append("component[version]", this.version);
      if (!this.newComponent) {
        formData.append("component[duplicate]", !this.newComponent);
        formData.append("component[id]", this.component_to_duplicate);
      }
      if (this.file) {
        formData.append("component[file]", this.file);
      } else {
        formData.append("component[prefix]", this.prefix);
      }

      axios
        .post(`/projects/${this.project_id}/components`, formData, {
          headers: {
            "Content-Type": "multipart/form-data",
          },
        })
        .then(this.addComponentSuccess)
        .catch(this.alertOrNotifyResponse)
        .finally(this.completeLoading);
    },
    completeLoading: function () {
      this.loading = false;
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
