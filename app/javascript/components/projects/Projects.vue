<script setup lang="ts">
/**
 * Projects Component
 * Displays project list with create button
 * Vue 3 Composition API
 */
import ProjectsTable from './ProjectsTable.vue'

defineProps<{
  projects: any[]
  is_vulcan_admin: boolean
}>()

const emit = defineEmits<{
  refresh: []
}>()

function refreshProjects() {
  emit('refresh')
}
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-center mb-4">
      <h1 class="mb-0">
        Projects
      </h1>
      <router-link to="/projects/new" class="btn btn-primary">
        <i class="bi bi-plus-circle me-2" />
        New Project
      </router-link>
    </div>
    <ProjectsTable
      :projects="projects"
      :is_vulcan_admin="is_vulcan_admin"
      @project-updated="refreshProjects"
    />
  </div>
</template>
