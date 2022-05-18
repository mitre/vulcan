<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>{{ project.name }}</h1>
      </b-col>
      <b-col md="4" class="text-muted text-md-right">
        <p v-if="lastAudit" class="text-muted mb-1">
          <template v-if="lastAudit.created_at">
            Last update on {{ friendlyDateTime(lastAudit.created_at) }}
          </template>
          <template v-if="lastAudit.user_id"> by {{ lastAudit.user_id }} </template>
        </p>
        <p class="mb-1">
          <span v-if="project.admin_name">
            {{ project.admin_name }}
            {{ project.admin_email ? `(${project.admin_email})` : "" }}
          </span>
          <em v-else>No Project Admin</em>
        </p>
      </b-col>
    </b-row>

    <b-row>
      <b-col md="10" class="border-right">
        <!-- Tab view for project information -->
        <b-tabs v-model="projectTabIndex" content-class="mt-3" justified>
          <!-- Project components -->
          <b-tab :title="`Components (${project.components.length})`">
            <h2>Project Components</h2>
            <div>
              <NewComponentModal
                v-if="role_gte_to(effective_permissions, 'admin')"
                :project_id="project.id"
                @projectUpdated="refreshProject"
              />
              <NewComponentModal
                v-if="role_gte_to(effective_permissions, 'admin')"
                :project_id="project.id"
                :spreadsheet_import="true"
                @projectUpdated="refreshProject"
              />
              <NewComponentModal
                v-if="role_gte_to(effective_permissions, 'admin')"
                :project_id="project.id"
                :project="project"
                :copy_component="true"
                @projectUpdated="refreshProject"
              />
              <b-dropdown right text="Download" variant="secondary" class="px-2 m2">
                <b-dropdown-item @click="downloadExport('excel')">Excel Export</b-dropdown-item>
                <b-dropdown-item @click="downloadExport('xccdf')">Xccdf Export</b-dropdown-item>
                <b-dropdown-item @click="downloadExport('inspec')">InSpec Profile</b-dropdown-item>
              </b-dropdown>
            </div>
            <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
              <b-col v-for="component in sortedRegularComponents()" :key="component.id">
                <ComponentCard
                  :component="component"
                  :effective-permissions="effective_permissions"
                  @deleteComponent="deleteComponent($event)"
                  @projectUpdated="refreshProject"
                />
              </b-col>
            </b-row>

            <h2>Overlaid Components</h2>
            <AddComponentModal
              v-if="role_gte_to(effective_permissions, 'admin')"
              :project_id="project.id"
              :available_components="sortedAvailableComponents"
              @projectUpdated="refreshProject"
            />
            <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
              <b-col v-for="component in sortedOverlayComponents()" :key="component.id">
                <ComponentCard
                  :component="component"
                  :effective-permissions="effective_permissions"
                  @deleteComponent="deleteComponent($event)"
                  @projectUpdated="refreshProject"
                />
              </b-col>
            </b-row>
          </b-tab>

          <!-- Diff View -->
          <b-tab title="Diff Viewer" lazy>
            <DiffViewer :project="initialProjectState" />
          </b-tab>

          <!-- Revision History -->
          <b-tab title="Revision History">
            <RevisionHistory
              :project="initialProjectState"
              :unique-component-names="uniqueComponentNames"
            />
          </b-tab>

          <!-- Project members -->
          <b-tab :title="`Members (${project.memberships_count})`">
            <MembershipsTable
              :editable="role_gte_to(effective_permissions, 'admin')"
              :membership_type="'Project'"
              :membership_id="project.id"
              :memberships="project.memberships"
              :memberships_count="project.memberships_count"
              :available_members="project.available_members"
              :available_roles="available_roles"
            />
          </b-tab>
        </b-tabs>
      </b-col>
      <b-col md="2">
        <b-row class="pb-4">
          <b-col>
            <div class="clickable" @click="showDetails = !showDetails">
              <h5 class="m-0 d-inline-block">Project Details</h5>

              <i v-if="showDetails" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
              <i v-if="!showDetails" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-details" v-model="showDetails">
              <p class="ml-2 mb-0 mt-2">
                <strong>Applicable - Configurable: </strong> {{ project.details.ac }} ({{
                  ((project.details.ac / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Applicable - Inherently Meets: </strong> {{ project.details.aim }} ({{
                  ((project.details.aim / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Applicable - Does Not Meet: </strong> {{ project.details.adnm }} ({{
                  ((project.details.adnm / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Not Applicable: </strong> {{ project.details.na }} ({{
                  ((project.details.na / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Not Yet Determined: </strong> {{ project.details.nyd }} ({{
                  ((project.details.nyd / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Not Under Review: </strong> {{ project.details.nur }} ({{
                  ((project.details.nur / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Under Review: </strong> {{ project.details.ur }} ({{
                  ((project.details.ur / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2">
                <strong>Locked: </strong> {{ project.details.lck }} ({{
                  ((project.details.lck / project.details.total) * 100).toFixed(2)
                }}%)
              </p>
              <p class="ml-2 mb-0 mt-2"><strong>Total: </strong> {{ project.details.total }}</p>
            </b-collapse>
          </b-col>
        </b-row>
        <b-row class="pb-4">
          <b-col>
            <div class="clickable" @click="showMetadata = !showMetadata">
              <h5 class="m-0 d-inline-block">Project Metadata</h5>

              <i
                v-if="showMetadata"
                class="mdi mdi-menu-down superVerticalAlign collapsableArrow"
              />
              <i v-if="!showMetadata" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showMetadata">
              <div v-for="(value, propertyName) in project.metadata" :key="propertyName">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>{{ propertyName }}: </strong>{{ value }}
                </p>
              </div>
              <UpdateMetadataModal :project="project" @projectUpdated="refreshProject" />
            </b-collapse>
          </b-col>
        </b-row>
        <b-row>
          <b-col>
            <div class="clickable" @click="showHistory = !showHistory">
              <h5 class="m-0 d-inline-block">Project History</h5>

              <i v-if="showHistory" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
              <i v-if="!showHistory" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showHistory">
              <History :histories="project.histories" :revertable="false" />
            </b-collapse>
          </b-col>
        </b-row>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import History from "../shared/History.vue";
import MembershipsTable from "../memberships/MembershipsTable.vue";
import UpdateMetadataModal from "./UpdateMetadataModal.vue";
import ComponentCard from "../components/ComponentCard.vue";
import AddComponentModal from "../components/AddComponentModal.vue";
import NewComponentModal from "../components/NewComponentModal.vue";
import DiffViewer from "./DiffViewer.vue";
import RevisionHistory from "./RevisionHistory.vue";

export default {
  name: "Project",
  components: {
    History,
    MembershipsTable,
    UpdateMetadataModal,
    ComponentCard,
    AddComponentModal,
    NewComponentModal,
    DiffViewer,
    RevisionHistory,
  },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue, RoleComparisonMixin],
  props: {
    effective_permissions: {
      type: String,
    },
    initialProjectState: {
      type: Object,
      required: true,
    },
    current_user_id: {
      type: Number,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      showDetails: true,
      showMetadata: true,
      showHistory: true,
      project: this.initialProjectState,
      projectTabIndex: 0,
    };
  },
  computed: {
    sortedAvailableComponents: function () {
      return _.sortBy(this.project.available_components, ["child_project_name"], ["asc"]);
    },
    uniqueComponentNames: function () {
      return _.uniq(this.sortedComponents().map((c) => c["name"]));
    },
    adminList: function () {
      return this.project.admins.map((a) => `${a.name} <${a.email}>`).join(", ");
    },
    lastAudit: function () {
      return this.project.histories.slice(0, 1).pop();
    },
    breadcrumbs: function () {
      return [
        {
          text: "Projects",
          href: "/projects",
        },
        {
          text: this.project.name,
          active: true,
        },
      ];
    },
  },
  watch: {
    projectTabIndex: function (_) {
      localStorage.setItem(
        `projectTabIndex-${this.project.id}`,
        JSON.stringify(this.projectTabIndex)
      );
    },
  },
  mounted: function () {
    // Persist `currentTab` across page loads
    if (localStorage.getItem(`projectTabIndex-${this.project.id}`)) {
      try {
        this.$nextTick(
          () =>
            (this.projectTabIndex = JSON.parse(
              localStorage.getItem(`projectTabIndex-${this.project.id}`)
            ))
        );
      } catch (e) {
        localStorage.removeItem(`projectTabIndex-${this.project.id}`);
      }
    }
  },
  methods: {
    sortedComponents: function () {
      return _.orderBy(
        this.project.components,
        [(component) => component.name.toLowerCase(), "version", "release"],
        ["asc"]
      );
    },
    sortedOverlayComponents: function () {
      return this.sortedComponents().filter((e) => e.component_id != null);
    },
    sortedRegularComponents: function () {
      return this.sortedComponents().filter((e) => e.component_id == null);
    },
    refreshProject: function () {
      axios.get(`/projects/${this.project.id}`).then((response) => {
        this.project = response.data;
      });
    },
    // Having deleteComponent on the `ComponentCard` causes it to
    // disappear almost immediately because the component gets
    // destroyed once `refreshProject` executes
    deleteComponent: function (componentId) {
      axios
        .delete(`/components/${componentId}`)
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.refreshProject();
        })
        .catch(this.alertOrNotifyResponse);
    },
    downloadExport: function (type) {
      axios
        .get(`/projects/${this.project.id}/export/${type}`)
        .then((_res) => {
          // Once it is validated that there is content to download, prompt
          // the user to save the file
          window.open(`/projects/${this.project.id}/export/${type}`);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped></style>
