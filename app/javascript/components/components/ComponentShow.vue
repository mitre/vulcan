<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>{{ project.name }}</h1>
      </b-col>
      <b-col md="4" class="text-muted text-md-right">
        {{ `${project.based_on.title} ${project.based_on.version}` }}
        <div v-if="lastAudit" class="text-muted">
          <template v-if="lastAudit.created_at">
            Last update on {{ friendlyDateTime(lastAudit.created_at) }}
          </template>
          <template v-if="lastAudit.user_id"> by {{ lastAudit.user_id }} </template>
        </div>
      </b-col>
    </b-row>
    <b-row v-if="project.admins && project.admins.length" class="pb-4">
      <b-col>
        <div class="text-muted">Component Administrators: {{ adminList }}</div>
      </b-col>
    </b-row>

    <b-row>
      <b-col md="10" class="border-right">
        <!-- Tab view for project information -->
        <b-tabs v-model="projectTabIndex" content-class="mt-3" justified>
          <!-- Project rules -->
          <b-tab :title="`Controls (${project.rules.length})`">
            <b-button
              v-if="project_permissions"
              class="m-2"
              variant="primary"
              :href="`/projects/${project.id}/controls`"
            >
              Edit Component Controls
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

          <!-- Project members -->
          <b-tab v-if="project_permissions" :title="`Members (${project.project_members.length})`">
            <ProjectMembersTable
              :editable="project_permissions == 'admin'"
              :project="project"
              :project_members="project.project_members"
              :project_members_count="project.project_members.length"
              :available_members="available_members"
              :available_roles="available_roles"
            />
          </b-tab>
        </b-tabs>
      </b-col>
      <b-col md="2">
        <b-row>
          <b-col>
            <div class="clickable" @click="showHistory = !showHistory">
              <h5 class="m-0 d-inline-block">Component History</h5>

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
import RulesReadOnlyView from "../rules/RulesReadOnlyView.vue";

export default {
  name: "ComponentShow",
  components: {
    History,
    ProjectMembersTable,
    RulesReadOnlyView,
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
    available_members: {
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
      showMetadata: true,
      showHistory: true,
      project: this.initialProjectState,
      projectTabIndex: 0,
    };
  },
  computed: {
    adminList: function () {
      return this.project.admins.map((a) => `${a.name} <${a.email}>`).join(", ");
    },
    lastAudit: function () {
      return this.project.histories.slice(0, 1).pop();
    },
    breadcrumbs: function () {
      return [
        {
          text: "Components",
          href: "/components",
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
};
</script>

<style scoped></style>
