<script setup lang="ts">
/**
 * Projects Index Page
 *
 * Uses async setup with Suspense for loading state.
 */
import { storeToRefs } from 'pinia'
import Projects from '@/components/projects/Projects.vue'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useProjects } from '@/composables'
import { useAuthStore } from '@/stores'

// Use composables
const { projects, refresh } = useProjects()

// Auth state
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Top-level await makes this component suspensible
await refresh()
</script>

<template>
  <PageContainer>
    <Projects
      :projects="projects"
      :is_vulcan_admin="isAdmin"
      @refresh="refresh"
    />
  </PageContainer>
</template>
