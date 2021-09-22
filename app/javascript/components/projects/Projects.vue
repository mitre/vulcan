<template>
  <div>
    <h1>Projects</h1>
    <ProjectsTable :projects="projects" />
  </div>
</template>

<script>
import ProjectsTable from './ProjectsTable.vue';

export default {
  name: "Projects",
  components: { ProjectsTable },
  props: {
    projects: {
      type: Array,
      required: true,
    },
  },
};
</script>

<style scoped></style>
