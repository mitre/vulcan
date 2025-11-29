<script setup lang="ts">
import { storeToRefs } from 'pinia'
import { onMounted } from 'vue'
import Projects from '@/components/projects/Projects.vue'
import { useProjects } from '@/composables'
import { useAuthStore } from '@/stores'

// Use composables
const { projects, loading, error, refresh } = useProjects()

// Auth state
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Fetch on mount
onMounted(async () => {
  await refresh()
})
</script>

<template>
  <div>
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p class="mt-2">
        Loading projects...
      </p>
    </div>
    <div v-else-if="error" class="alert alert-danger">
      {{ error }}
    </div>
    <Projects
      v-else
      :projects="projects"
      :is_vulcan_admin="isAdmin"
      @refresh="refresh"
    />
  </div>
</template>
