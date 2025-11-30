<script setup lang="ts">
/**
 * Component Show Page
 *
 * Uses async setup with Suspense for loading state.
 */
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { getComponent } from '@/apis/components.api'
import { getProject } from '@/apis/projects.api'
import ProjectComponent from '@/components/components/ProjectComponent.vue'
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

const SEVERITIES_MAP = {
  unknown: 'unknown',
  info: 'CAT IV',
  low: 'CAT III',
  medium: 'CAT II',
  high: 'CAT I',
}

const route = useRoute()
const authStore = useAuthStore()

const availableRoles = ['viewer', 'author', 'reviewer', 'admin']

// Top-level await makes this component suspensible
const componentId = Number(route.params.id)
const componentResponse = await getComponent(componentId)
const component = componentResponse.data

if (!component) {
  throw new Error('Component not found')
}

// Fetch project data
const projectResponse = await getProject(component.project_id)
const project = projectResponse.data

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

  if (!component?.memberships || !currentUserId.value) return 'viewer'

  // Find current user's membership in this component
  const membership = component.memberships.find(
    (m: any) => m.user_id === currentUserId.value,
  )

  if (membership?.role) return membership.role

  // Check inherited memberships from project
  const inheritedMembership = component.inherited_memberships?.find(
    (m: any) => m.user_id === currentUserId.value,
  )

  return inheritedMembership?.role || 'viewer'
})
</script>

<template>
  <PageContainer>
    <ProjectComponent
      :initial-component-state="component"
      :project="project"
      :statuses="STATUSES"
      :severities="SEVERITIES"
      :severities_map="SEVERITIES_MAP"
      :available_roles="availableRoles"
      :current_user_id="currentUserId"
      :effective_permissions="effectivePermissions"
    />
  </PageContainer>
</template>
