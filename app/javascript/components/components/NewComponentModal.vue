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
      :ok-disabled="loading || !(security_requirements_guide_id || component_to_duplicate) || (spreadsheet_import && !file)"
      @show="fetchData"
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
            <b-form-group v-if="copy_component" label="Select an existing Project to copy from">
              <vue-simple-suggest
                ref="projectSearch"
                :value="project.name"
                :list="projects"
                display-attribute="name"
                value-attribute="id"
                placeholder="Search for an existing Project..."
                :min-length="0"
                :max-suggestions="0"
                :number="0"
                @select="setSelectedProject($refs.projectSearch.selected)"
              />
            </b-form-group>

            <!-- Select a Component -->
            <b-form-group v-if="copy_component" label="Select an existing Component to copy from">
              <vue-simple-suggest
                :key="componentKey"
                ref="componentSearch"
                :list="components"
                display-attribute="displayed"
                value-attribute="id"
                placeholder="Search for an existing Component..."
                :disabled="!selected_project_id"
                :filter-by-query="true"
                :min-length="0"
                :max-suggestions="0"
                :number="0"
                @select="setSelectedComponent($refs.componentSearch.selected)"
              />
            </b-form-group>

            <!-- Select a SRG -->
            <b-form-group
              v-if="predetermined_security_requirements_guide_id == null"
              label="Select a Security Requirements Guide"
            >
              <vue-simple-suggest
                ref="srgSearch"
                :value="security_requirements_guide_displayed"
                :list="copy_component ? displayedSrgs : srgs"
                display-attribute="displayed"
                value-attribute="id"
                placeholder="Search for an SRG..."
                :filter-by-query="copy_component ? false : true"
                :min-length="0"
                :max-suggestions="0"
                :number="0"
                @select="setSelectedSrg($refs.srgSearch.selected)"
              />
            </b-form-group>
            <!-- Name the component -->
            <b-form-group label="Name">
              <b-form-input
                v-model="name"
                placeholder="Component Name"
                required
                autocomplete="off"
              />
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
            <!-- Import from existing spreadsheet -->
            <b-form-group
              v-if="spreadsheet_import"
              label="Import Component from File"
              description="Import from SRG Spreadsheet (.xlsx, .xls, .csv, .ods) or XCCDF/STIG XML (.xml)"
            >
              <b-form-file
                v-model="file"
                placeholder="Choose a spreadsheet or XCCDF file..."
                drop-placeholder="Drop file here..."
                accept=".xlsx,.xls,.csv,.ods,.xml"
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
            <!-- Title -->
            <b-form-group label="Title">
              <b-form-input
                v-model="title"
                placeholder="Component Title"
                required
                autocomplete="off"
              />
            </b-form-group>
            <!-- Description -->
            <b-form-group label="Description">
              <b-form-textarea v-model="description" placeholder="" rows="3" />
            </b-form-group>
            <!-- Select PoC -->
            <b-form-group
              v-if="project"
              label="Select the Point of Contact"
              description="If no user selected, the PoC will be set to the user creating the component"
            >
              <vue-simple-suggest
                ref="userSearch"
                :list="potentialPocs"
                display-attribute="name"
                value-attribute="email"
                placeholder="Search for eligible PoC..."
                :filter-by-query="true"
                :min-length="0"
                :max-suggestions="0"
                :number="0"
                @select="setComponentPoc($refs.userSearch.selected)"
              />
            </b-form-group>
            <!-- Slack Channel ID -->
            <b-form-group
              label="Slack Channel ID"
              description="Provide a slack channel ID for slack notification about activities on this component"
            >
              <b-form-input
                v-model="slackChannelId"
                placeholder="Example... C123456, #general"
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
import DisplayedComponentMixin from "../../mixins/DisplayedComponentMixin.vue";
import VueSimpleSuggest from "vue-simple-suggest";
import "vue-simple-suggest/dist/styles.css";

export default {
  name: "NewComponentModal",
  components: {
    VueSimpleSuggest,
  },
  mixins: [AlertMixinVue, FormMixinVue, DisplayedComponentMixin],
  props: {
    spreadsheet_import: {
      type: Boolean,
      default: false,
    },
    copy_component: {
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
    project: {
      type: Object,
      required: false,
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
      selected_project_id: this.project_id,
      selected_component_id: null,
      security_requirements_guide: null,
      security_requirements_guide_id:
        !this.copy_component && this.predetermined_security_requirements_guide_id,
      security_requirements_guide_displayed: "",
      name: "",
      version: "",
      release: "",
      title: "",
      description: "",
      prefix: this.predetermined_prefix,
      slackChannelId: "",
      projects: [],
      components: this.copy_component
        ? this.addDisplayNameToComponents(this.project.components)
        : [],
      srgs: [],
      displayedSrgs: [],
      file: null,
      componentKey: 0,
      potentialPocs: this.project ? this.project.users : [],
      admin_name: "",
      admin_email: "",
    };
  },
  computed: {
    buttonText: function () {
      if (this.spreadsheet_import) {
        return "Import Component from File";
      } else if (this.copy_component) {
        return "Copy Component";
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
      } else if (this.copy_component) {
        return "Copy Component";
      } else if (this.newComponent) {
        return "Create Component";
      } else {
        return "Duplicate Component";
      }
    },
  },
  methods: {
    showModal: function () {
      this.selected_project_id = this.project_id;
      this.selected_component_id = null;
      this.security_requirements_guide = null;
      this.security_requirements_guide_id =
        !this.copy_component && this.predetermined_security_requirements_guide_id;
      this.security_requirements_guide_displayed = "";
      this.name = "";
      this.version = "";
      this.release = "";
      this.title = "";
      this.description = "";
      this.prefix = this.predetermined_prefix;
      this.slackChannelId = "";
      this.components = this.copy_component
        ? this.addDisplayNameToComponents(this.project.components)
        : [];
      this.displayedSrgs = [];
      this.$refs["AddComponentModal"].show();
    },
    setComponentPoc: function (user) {
      this.admin_email = user.email;
      this.admin_name = user.name;
    },
    fetchData: function (_bvModalEvt) {
      axios.get("/srgs").then((response) => {
        this.srgs = response.data;
        this.srgs.forEach((srg) => {
          srg.displayed = `${srg.title} (${srg.version})`;
        });
      });
      axios.get("/projects").then((response) => {
        this.projects = response.data;
      });
    },
    setSelectedProject: function (project) {
      if (!this.selected_project_id || this.selected_project_id !== project.id) {
        this.selected_component_id = null;
        this.security_requirements_guide_id = null;
        this.security_requirements_guide_displayed = null;
        axios.get(`/projects/${project.id}`).then((response) => {
          this.components = this.addDisplayNameToComponents(response.data.components);
          this.componentKey += 1;
        });
      }
      this.selected_project_id = project.id;
    },
    setSelectedComponent: function (component) {
      this.selected_component_id = component.id;
      this.security_requirements_guide_id = component.security_requirements_guide_id;
      this.security_requirements_guide_displayed = this.srgs.find(
        (srg) => srg.id === component.security_requirements_guide_id,
      ).displayed;
      this.name = component.name;
      this.version = component.version;
      this.release = component.release;
      this.prefix = component.prefix;
      this.title = component.title;
      this.description = component.description;
      // only display srgs the selected component is based on
      this.displayedSrgs = this.srgs.filter((srg) => srg.title === component.based_on_title);
    },
    setSelectedSrg: function (srg) {
      this.security_requirements_guide_id = srg.id;
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
      if (!this.name) {
        this.$bvToast.toast("Please enter a name", {
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
        this.security_requirements_guide_id,
      );
      formData.append("component[name]", this.name);
      if (!this.newComponent) {
        formData.append("component[duplicate]", !this.newComponent);
        formData.append("component[id]", this.component_to_duplicate);
      }
      if (this.copy_component) {
        formData.append("component[copy_component]", true);
        formData.append("component[project_id]", this.project_id);
        formData.append("component[id]", this.selected_component_id);
      }
      if (this.version) {
        formData.append("component[version]", this.version);
      }
      if (this.release) {
        formData.append("component[release]", this.release);
      }
      if (this.file) {
        formData.append("component[file]", this.file);
      } else {
        formData.append("component[prefix]", this.prefix);
      }
      if (this.title) {
        formData.append("component[title]", this.title);
      }
      if (this.description) {
        formData.append("component[description]", this.description);
      }
      if (this.admin_name) {
        formData.append("component[admin_name]", this.admin_name);
      }
      if (this.admin_email) {
        formData.append("component[admin_email]", this.admin_email);
      }
      if (this.slackChannelId) {
        formData.append("component[slack_channel_id]", this.slackChannelId);
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
  },
};
</script>

<style scoped>
.flex1 {
  flex: 1;
}
</style>
