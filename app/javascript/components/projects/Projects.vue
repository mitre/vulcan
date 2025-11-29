<script>
import ProjectsTable from './ProjectsTable.vue'

export default {
  name: 'Projects',
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
  emits: ['refresh'],
  methods: {
    refreshProjects() {
      // Emit event to parent to trigger store refresh
      this.$emit('refresh')
    },
  },
}
</script>

<template>
  <div>
    <h1>Projects</h1>
    <ProjectsTable
      :projects="projects"
      :is_vulcan_admin="is_vulcan_admin"
      @project-updated="refreshProjects"
    />
  </div>
</template>

<style scoped></style>
