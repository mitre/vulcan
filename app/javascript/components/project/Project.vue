<template>
  <div>
    <b-breadcrumb :items="breadcrumbs"></b-breadcrumb>
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>{{this.project.name}}</h1>
      </b-col>
      <b-col md="4" class="text-muted text-md-right">
        STIG Version Info...
      </b-col>
    </b-row>
    <b-row class="pb-4">
      <b-col>
        <div class="text-muted" v-if="lastAudit">
          <template v-if='lastAudit.created_at'>
            Last update on {{ friendlyDateTime(lastAudit.created_at) }}
          </template>
          <template v-if='lastAudit.user_id'>
            by {{ lastAudit.user_id }}
          </template>
        </div>
        <div class="text-muted" v-if="project.admins && project.admins.length">
          Project Administrators: {{ adminList }}
        </div>
      </b-col>
    </b-row>

    <b-row>
      <b-col md="8" class="border-right">
        <ProjectMembersTable :project="project"
                             :project_members="project.project_members"
                             :project_members_count="project.project_members.length"
        />
      </b-col>
      <b-col md="4">
        <b-row class="pb-4">
          <b-col>
            <div @click="showMetadata = !showMetadata" class="clickable">
              <h5 class="m-0 d-inline-block">Project Metadata</h5>

              <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showMetadata"></i>
              <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showMetadata"></i>
            </div>
            <b-collapse id="collapse-metadata" v-model="showMetadata">
              <div :key="propertyName" v-for="(value, propertyName) in project.metadata">
                <p class="ml-2 mb-0 mt-2" v-linkified><strong>{{propertyName}}: </strong>{{value}}</p>
              </div>
              <UpdateMetadataModal
                :project="project"
                @projectUpdated="refreshProject"
              />
            </b-collapse>
          </b-col>
        </b-row>
        <b-row>
          <b-col>
            <div @click="showHistory = !showHistory" class="clickable">
              <h5 class="m-0 d-inline-block">Project History</h5>

              <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showHistory"></i>
              <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showHistory"></i>
            </div>
            <b-collapse id="collapse-metadata" v-model="showHistory">
              <History
                :histories="project.histories"
                :revertable="false"
              />
            </b-collapse>
          </b-col>
        </b-row>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import axios from 'axios'
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue';
import History from '../shared/History.vue'
import ProjectMembersTable from '../project_members/ProjectMembersTable.vue'
import UpdateMetadataModal from './UpdateMetadataModal.vue';

export default {
  name: 'Project',
  mixins: [DateFormatMixinVue],
  components: { History, ProjectMembersTable, UpdateMetadataModal },
  props: {
    initialProjectState: {
      type: Object,
      required: true,
    }
  },
  data: function () {
    return {
      showMetadata: true,
      showHistory: true,
      project: this.initialProjectState
    }
  },
  computed: {
    adminList: function() {
      return this.project.admins.map(a => `${a.name} <${a.email}>`).join(", ");
    },
    lastAudit: function() {
      return this.project.histories.slice(0, 1).pop();
    },
    breadcrumbs: function() {
      return [
        {
          text: 'Projects',
          href: '/projects'
        },
        {
          text: this.project.name,
          active: true
        }
      ]
    }
  },
  methods: {
    refreshProject: function() {
      axios.get(`/projects/${this.project.id}`)
        .then(response => {
          this.project = response.data;
        })
    }
  }
}
</script>

<style scoped>
</style>
