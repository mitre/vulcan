<template>
  <span>
    <!-- Modal trigger button (only if showOpener prop is true) -->
    <span v-if="showOpener" @click="showModal()">
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
      :ok-disabled="
        loading ||
        awaitingProfileChoice ||
        !(security_requirements_guide_id || component_to_duplicate)
      "
      @show="fetchData"
      @ok="createComponent"
    >
      <!-- Searchable projects -->
      <b-form @submit.prevent>
        <input
          id="NewComponentAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        />
        <!-- Creation-time profile choice — first step; the selection
             gates the rest of the form. Duplicate/copy/spreadsheet
             flows have a determined type and skip the picker. -->
        <template v-if="profilePickerMode">
          <DocumentTypePicker v-model="document_type" />
          <small v-if="awaitingProfileChoice" class="text-muted d-block mb-3">
            Choose one to enable the rest of the form.
          </small>
          <!-- Declared sources come right after the profile choice
               (profile → sources → identity): 1..N eligible SRGs with
               a primary designation, replacing the single-SRG select
               for the create-new flow. -->
          <SourceSrgPicker v-model="sourceSelection" :srgs="srgs" :document-type="document_type" />
        </template>
        <b-row>
          <b-col>
            <!-- Select a SRG -->
            <b-form-group v-if="copy_component" label="Select an existing Project to copy from">
              <vue-multiselect
                v-model="selectedProjectObj"
                :options="projects"
                label="name"
                track-by="id"
                :searchable="true"
                :allow-empty="true"
                placeholder="Search for an existing Project..."
                @input="setSelectedProject($event)"
              />
            </b-form-group>

            <!-- Select a Component -->
            <b-form-group v-if="copy_component" label="Select an existing Component to copy from">
              <vue-multiselect
                :key="componentKey"
                v-model="selectedComponentObj"
                :options="components"
                label="displayed"
                track-by="id"
                :searchable="true"
                :allow-empty="true"
                :disabled="!selected_project_id"
                placeholder="Search for an existing Component..."
                @input="setSelectedComponent($event)"
              />
            </b-form-group>

            <!-- Select a SRG (single-source flows only: the create-new
                 flow declares sources through SourceSrgPicker above) -->
            <b-form-group
              v-if="!profilePickerMode && predetermined_security_requirements_guide_id == null"
              label="Select a Security Requirements Guide"
            >
              <vue-multiselect
                v-model="selectedSrgObj"
                :options="copy_component ? displayedSrgs : srgs"
                label="displayed"
                track-by="id"
                :searchable="true"
                :allow-empty="true"
                :disabled="detecting || awaitingProfileChoice"
                placeholder="Search for an SRG..."
                @input="setSelectedSrg($event)"
              />
              <small v-if="detecting" class="text-muted">
                <b-spinner small type="grow" /> Detecting SRG from spreadsheet...
              </small>
              <small v-else-if="srgAutoDetected" class="text-success">
                <i class="bi-check-circle" /> SRG auto-detected from spreadsheet
              </small>
            </b-form-group>
            <!-- Name the component -->
            <b-form-group label="Name">
              <b-form-input
                v-model="name"
                placeholder="Component Name"
                required
                autocomplete="off"
                :disabled="awaitingProfileChoice"
              />
            </b-form-group>
            <!-- Version and Release -->
            <b-form-row>
              <b-col>
                <b-form-group label="Version">
                  <b-form-input
                    v-model="version"
                    autocomplete="off"
                    :disabled="awaitingProfileChoice"
                  />
                </b-form-group>
              </b-col>
              <b-col>
                <b-form-group label="Release">
                  <b-form-input
                    v-model="release"
                    autocomplete="off"
                    :disabled="awaitingProfileChoice"
                  />
                </b-form-group>
              </b-col>
            </b-form-row>
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
                accept=".xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv"
              />
            </b-form-group>
            <!-- Set the prefix — copy resolves per the chosen document kind -->
            <b-form-group
              v-else
              :label="prefixFieldCopy.label"
              :description="prefixFieldCopy.description"
            >
              <b-form-input
                v-model="prefix"
                :placeholder="prefixFieldCopy.placeholder"
                required
                autocomplete="off"
                :disabled="awaitingProfileChoice"
              />
            </b-form-group>
            <!-- Title -->
            <b-form-group label="Title">
              <b-form-input
                v-model="title"
                placeholder="Component Title"
                required
                autocomplete="off"
                :disabled="awaitingProfileChoice"
              />
            </b-form-group>
            <!-- Description -->
            <b-form-group label="Description">
              <b-form-textarea
                v-model="description"
                placeholder=""
                rows="3"
                :disabled="awaitingProfileChoice"
              />
            </b-form-group>
            <!-- Select PoC -->
            <b-form-group
              v-if="project"
              label="Select the Point of Contact"
              description="If no user selected, the PoC will be set to the user creating the component"
            >
              <vue-multiselect
                v-model="selectedPocObj"
                :options="potentialPocs"
                label="name"
                track-by="id"
                :searchable="true"
                :allow-empty="true"
                :disabled="awaitingProfileChoice"
                placeholder="Search for eligible PoC..."
                @input="setComponentPoc($event)"
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
                :disabled="awaitingProfileChoice"
              />
            </b-form-group>
          </b-col>
        </b-row>
      </b-form>
    </b-modal>
  </span>
</template>

<script>
import { getSrgs, getProjects, getProject } from "../../api/projectsApi";
import { detectSrg, createComponentInProject } from "../../api/componentsApi";
import { prefixField } from "../../constants/terminology";
import { useAuthToken } from "../../composables/useAuthToken";
import { useToast } from "../../composables/useToast";
import { useDisplayedComponent } from "../../composables/useDisplayedComponent";
import DocumentTypePicker from "./DocumentTypePicker.vue";
import SourceSrgPicker from "./SourceSrgPicker.vue";
import VueMultiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";

export default {
  name: "NewComponentModal",
  components: {
    DocumentTypePicker,
    SourceSrgPicker,
    VueMultiselect,
  },
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
      default: null,
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
    showOpener: {
      type: Boolean,
      default: false,
    },
  },
  // setup() runs before data(), so the setup-returned
  // addDisplayNameToComponents is available to data() below.
  setup() {
    const { authenticityToken } = useAuthToken();
    const { addDisplayNameToComponents } = useDisplayedComponent();
    const { alertOrNotifyResponse } = useToast();
    return { authenticityToken, addDisplayNameToComponents, alertOrNotifyResponse };
  },
  data: function () {
    return {
      loading: false,
      // The creation-time profile choice. Starts empty — the author
      // must pick; posted as component[document_type] (immutable).
      document_type: null,
      // The declared source set + primary designation for the
      // create-new flow (SourceSrgPicker v-model).
      sourceSelection: { sourceIds: [], primaryId: null },
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
        ? this.addDisplayNameToComponents(this.project?.components || [])
        : [],
      srgs: [],
      displayedSrgs: [],
      file: null,
      detecting: false,
      srgAutoDetected: false,
      componentKey: 0,
      potentialPocs: this.project?.users || [],
      admin_name: "",
      admin_email: "",
      selectedProjectObj: null,
      selectedComponentObj: null,
      selectedSrgObj: null,
      selectedPocObj: null,
    };
  },
  computed: {
    buttonText: function () {
      if (this.spreadsheet_import) {
        return "Import From Spreadsheet";
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
    // The "What are you authoring?" step exists only where a choice
    // exists: duplicate/copy inherit the source's document_type and
    // spreadsheet import is Rule-based (stig).
    profilePickerMode: function () {
      return this.newComponent && !this.copy_component && !this.spreadsheet_import;
    },
    awaitingProfileChoice: function () {
      return this.profilePickerMode && !this.document_type;
    },
    // Kind-keyed prefix copy; flows without kind knowledge (duplicate,
    // copy — the kind is inherited server-side) resolve the stig default.
    prefixFieldCopy: function () {
      return prefixField(this.document_type);
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
  watch: {
    file: function (newFile) {
      if (newFile && this.spreadsheet_import) {
        this.detectSrg(newFile);
      } else {
        this.srgAutoDetected = false;
      }
    },
    // The primary designation IS security_requirements_guide_id (the
    // backend contract), so the existing guards and ok-disabled
    // bindings keep working unchanged in the picker flow. Deep: the
    // mirror must hold whether the selection object is replaced (the
    // picker emits fresh state) or mutated in place.
    sourceSelection: {
      deep: true,
      handler: function (selection) {
        this.security_requirements_guide_id = selection.primaryId;
      },
    },
  },
  methods: {
    detectSrg: function (file) {
      this.detecting = true;
      this.srgAutoDetected = false;
      let formData = new FormData();
      formData.append("file", file);
      detectSrg(formData)
        .then((response) => {
          const detected = response.data;
          this.security_requirements_guide_id = detected.id;
          this.security_requirements_guide_displayed = `${detected.title} (${detected.version})`;
          this.srgAutoDetected = true;
        })
        .catch(() => {
          // Detection failed — user picks manually, no error needed
          this.srgAutoDetected = false;
        })
        .finally(() => {
          this.detecting = false;
        });
    },
    showModal: function () {
      this.document_type = null;
      this.sourceSelection = { sourceIds: [], primaryId: null };
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
      this.file = null;
      this.detecting = false;
      this.srgAutoDetected = false;
      this.$refs["AddComponentModal"].show();
    },
    setComponentPoc: function (user) {
      if (!user) return;
      this.admin_email = user.email;
      this.admin_name = user.name;
    },
    fetchData: function (_bvModalEvt) {
      getSrgs().then((response) => {
        this.srgs = response.data;
        this.srgs.forEach((srg) => {
          srg.displayed = `${srg.title} (${srg.version})`;
        });
      });
      getProjects().then((response) => {
        this.projects = response.data;
      });
    },
    setSelectedProject: function (project) {
      if (!project) return;
      if (!this.selected_project_id || this.selected_project_id !== project.id) {
        this.selected_component_id = null;
        this.security_requirements_guide_id = null;
        this.security_requirements_guide_displayed = null;
        getProject(project.id).then((response) => {
          this.components = this.addDisplayNameToComponents(response.data.components);
          this.componentKey += 1;
        });
      }
      this.selected_project_id = project.id;
    },
    setSelectedComponent: function (component) {
      if (!component) return;
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
      if (!srg) return;
      this.security_requirements_guide_id = srg.id;
    },
    createComponent: function (bvModalEvt) {
      // Prevent double submissions (B7 fix)
      if (this.loading) return;
      this.loading = true;
      let failed = false;

      // Guard before POST — preventDefault keeps modal open on validation errors
      if (this.awaitingProfileChoice) {
        this.$bvToast.toast("Please choose what you are authoring", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        failed = true;
      }
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
        // Keep modal open on validation errors
        if (bvModalEvt) bvModalEvt.preventDefault();
        this.loading = false;
        return;
      }

      // Modal closes naturally (no preventDefault) — show background progress
      this.$bvToast.toast("Creating component — this may take a moment for large SRGs...", {
        title: "Creating Component",
        variant: "info",
        solid: true,
        noAutoHide: true,
        id: "create-component-progress",
      });

      let formData = new FormData();
      formData.append(
        "component[security_requirements_guide_id]",
        this.security_requirements_guide_id,
      );
      formData.append("component[name]", this.name);
      // Only the picker flow posts the choice — duplicate/copy inherit
      // the source's document_type server-side.
      if (this.profilePickerMode) {
        formData.append("component[document_type]", this.document_type);
        // The full declared source set; the primary already rides
        // security_requirements_guide_id above.
        this.sourceSelection.sourceIds.forEach((id) => {
          formData.append("component[declared_source_srg_ids][]", id);
        });
      }
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

      createComponentInProject(this.project_id, formData)
        .then(this.addComponentSuccess)
        .catch(this.alertOrNotifyResponse)
        .finally(this.completeLoading);
    },
    completeLoading: function () {
      this.loading = false;
      this.$bvToast.hide("create-component-progress");
    },
    addComponentSuccess: function (response) {
      this.alertOrNotifyResponse(response);
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
