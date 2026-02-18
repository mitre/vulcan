<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <!-- New Project Button with optional "From Backup" dropdown -->
        <b-dropdown
          v-if="can_create_project"
          split
          variant="primary"
          size="sm"
          data-testid="new-project-dropdown"
          @click="openNewProjectModal"
        >
          <template #button-content> <b-icon icon="plus" /> New Project </template>
          <b-dropdown-item data-testid="from-backup-item" @click="openRestoreProjectModal">
            <b-icon icon="archive" /> From Backup
          </b-dropdown-item>
        </b-dropdown>
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
      v-if="can_create_project"
      v-model="showNewProjectModal"
      @project-created="onProjectCreated"
    />

    <!-- Restore Project from Backup Modal -->
    <RestoreProjectModal
      v-if="can_create_project"
      ref="restoreProjectModal"
      @projectCreated="onProjectCreated"
    />
  </div>
</template>

<script>
import ProjectsTable from "./ProjectsTable.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import NewProjectModal from "./NewProjectModal.vue";
import RestoreProjectModal from "./RestoreProjectModal.vue";
import axios from "axios";

export default {
  name: "Projects",
  components: { ProjectsTable, BaseCommandBar, NewProjectModal, RestoreProjectModal },
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
    can_create_project: {
      type: Boolean,
      required: false,
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
      return [{ text: "Projects", active: true }];
    },
  },
  methods: {
    openNewProjectModal() {
      this.showNewProjectModal = true;
    },
    openRestoreProjectModal() {
      this.$refs.restoreProjectModal.showModal();
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
