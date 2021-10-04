<template>
  <div>
    <h1>Components</h1>
    <ProjectsTable :projects="projects" :components="true" />
  </div>
</template>

<script>
import ProjectsTable from "../projects/ProjectsTable.vue";

export default {
  name: "Components",
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
