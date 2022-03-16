<template>
  <div>
    <h1>Projects</h1>
    <ProjectsTable
      :projects="projectlist"
      :is_vulcan_admin="is_vulcan_admin"
      @projectRenamed="refreshProjects"
    />
  </div>
</template>

<script>
import ProjectsTable from "./ProjectsTable.vue";
import axios from "axios";

export default {
  name: "Projects",
  components: { ProjectsTable },
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
    };
  },
  methods: {
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
