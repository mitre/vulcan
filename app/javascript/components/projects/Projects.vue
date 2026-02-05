<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <!-- New Project Button (admin only) -->
        <b-button
          v-if="is_vulcan_admin"
          variant="primary"
          size="sm"
          data-testid="new-project-btn"
          @click="openNewProjectModal"
        >
          <b-icon icon="plus" /> New Project
        </b-button>
      </template>
      <template #right>
        <!-- No panels needed for list page -->
      </template>
    </BaseCommandBar>

    <ProjectsTable
      :projects="projectlist"
      :is_vulcan_admin="is_vulcan_admin"
      @projectUpdated="refreshProjects"
    />

    <!-- New Project Modal -->
    <NewProjectModal
      v-if="is_vulcan_admin"
      v-model="showNewProjectModal"
      @project-created="onProjectCreated"
    />
  </div>
</template>

<script>
import ProjectsTable from "./ProjectsTable.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import NewProjectModal from "./NewProjectModal.vue";
import axios from "axios";

export default {
  name: "Projects",
  components: { ProjectsTable, BaseCommandBar, NewProjectModal },
  props: {
    projects: {
      type: Array,
      required: true,
    },
    is_vulcan_admin: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
  data: function () {
    return {
      projectlist: this.projects,
      showNewProjectModal: false,
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: 'Projects', active: true }];
    },
  },
  methods: {
    openNewProjectModal() {
      this.showNewProjectModal = true;
    },
    onProjectCreated() {
      this.showNewProjectModal = false;
      this.refreshProjects();
    },
    refreshProjects: function () {
      axios
        .get("/projects")
        .then((response) => {
          this.projectlist = response.data;
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped></style>
