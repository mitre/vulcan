<script setup lang="ts">
/**
 * Project Show Page
 *
 * Uses async setup with Suspense for loading state.
 */
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { getProject } from '@/apis/projects.api'
import Project from '@/components/project/Project.vue'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useAuthStore } from '@/stores'

// Rule constants (matching app/constants/rule_constants.rb)
const STATUSES = [
  'Not Yet Determined',
  'Applicable - Configurable',
  'Applicable - Inherently Meets',
  'Applicable - Does Not Meet',
  'Not Applicable',
]

const SEVERITIES = ['unknown', 'info', 'low', 'medium', 'high']

const route = useRoute()
const authStore = useAuthStore()

const availableRoles = ['viewer', 'author', 'reviewer', 'admin']

// Top-level await makes this component suspensible
const projectId = Number(route.params.id)
const response = await getProject(projectId)
const project = response.data

if (!project) {
  throw new Error('Project not found')
}

// Get current user from auth store
const currentUserId = computed(() => authStore.user?.id)
const isAdmin = computed(() => authStore.isAdmin)

// Compute effective permissions from memberships
const effectivePermissions = computed(() => {
  // Global admins have admin everywhere
  if (isAdmin.value) return 'admin'

  if (!project?.memberships || !currentUserId.value) return 'viewer'

  // Find current user's membership in this project
  const membership = project.memberships.find(
    (m: any) => m.user_id === currentUserId.value,
  )

  return membership?.role || 'viewer'
})
</script>

<template>
  <PageContainer>
    <Project
      :initial-project-state="project"
      :statuses="STATUSES"
      :severities="SEVERITIES"
      :available-roles="availableRoles"
      :current-user-id="currentUserId"
      :effective-permissions="effectivePermissions"
    />
  </PageContainer>
</template>
