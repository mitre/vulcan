<template>
  <div>
    <h1>Projects</h1>
    <ProjectsTable :projects="projects" />
  </div>
</template>

<script>
export default {
  name: 'Projects',
  props: {
    projects: {
      type: Array,
      required: true,
    }
  }
}
</script>

<style scoped>
</style>
