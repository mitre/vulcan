<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>{{ project.name }}</h1>
      </b-col>
      <b-col md="4" class="text-muted text-md-right">{{ project.based_on }}</b-col>
    </b-row>
    <b-row class="pb-4">
      <b-col>
        <div v-if="lastAudit" class="text-muted">
          <template v-if="lastAudit.created_at">
            Last update on {{ friendlyDateTime(lastAudit.created_at) }}
          </template>
          <template v-if="lastAudit.user_id"> by {{ lastAudit.user_id }} </template>
        </div>
        <div v-if="project.admins && project.admins.length" class="text-muted">
          Project Administrators: {{ adminList }}
        </div>
      </b-col>
    </b-row>

    <b-row>
      <b-col md="8" class="border-right">
        <!-- Tab view for project information -->
        <b-tabs content-class="mt-3" justified>
          <!-- Project rules -->
          <b-tab :title="`Rules (${project.rules.length})`" active>
            <b-button
              v-if="project_permissions"
              variant="primary"
              :href="`/projects/${project.id}/controls`"
            >
              Edit Project Controls
            </b-button>

            <RulesReadOnlyView
              :project-permissions="project_permissions"
              :current-user-id="current_user_id"
              :project="project"
              :rules="project.rules"
              :statuses="statuses"
              :severities="severities"
            />
          </b-tab>

          <!-- Project components -->
          <b-tab :title="`Components (${project.components.length})`">
            <AddComponentModal
              v-if="project_permissions == 'admin'"
              :project_id="project.id"
              :available_components="sortedAvailableComponents"
              @projectUpdated="refreshProject"
            />

            <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
              <b-col v-for="component in sortedComponents" :key="component.id">
                <ComponentCard
                  :component="component"
                  @deleteComponent="deleteComponent($event)"
                />
              </b-col>
            </b-row>
          </b-tab>

          <!-- Project members -->
          <b-tab
            v-if="project_permissions"
            :title="`Project Members (${project.project_members.length})`"
          >
            <ProjectMembersTable
              :project="project"
              :project_members="project.project_members"
              :project_members_count="project.project_members.length"
            />
          </b-tab>
        </b-tabs>
      </b-col>
      <b-col md="4">
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
import History from "../shared/History.vue";
import ProjectMembersTable from "../project_members/ProjectMembersTable.vue";
import UpdateMetadataModal from "./UpdateMetadataModal.vue";
import RulesReadOnlyView from "../rules/RulesReadOnlyView.vue";
import ComponentCard from "../components/ComponentCard.vue";
import AddComponentModal from "../components/AddComponentModal.vue";

export default {
  name: "Project",
  components: {
    History,
    ProjectMembersTable,
    UpdateMetadataModal,
    RulesReadOnlyView,
    ComponentCard,
    AddComponentModal,
  },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    project_permissions: {
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
  },
  data: function () {
    return {
      showMetadata: true,
      showHistory: true,
      project: this.initialProjectState,
    };
  },
  computed: {
    sortedComponents: function () {
      return _.sortBy(this.project.components, ['child_project_name'], ['asc']);
    },
    sortedAvailableComponents: function () {
      return _.sortBy(this.project.available_components, ['child_project_name'], ['asc']);
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
  methods: {
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
  },
};
</script>

<style scoped></style>
