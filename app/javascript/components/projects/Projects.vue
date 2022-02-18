<template>
  <div>
    <h1>Projects</h1>
    <ProjectsTable :projects="projects" :is_vulcan_admin="is_vulcan_admin"/>
  </div>
</template>

<script>
import ProjectsTable from "./ProjectsTable.vue";

export default {
  name: "Projects",
  components: { ProjectsTable },
  props: {
    projects: {
      type: Array,
      required: true,
    },
    is_vulcan_admin: {
      type: String,
      required: true,
    },
  },
};
</script>

<style scoped></style>
