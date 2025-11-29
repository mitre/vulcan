<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { getProject } from '@/apis/projects.api'
import Project from '@/components/project/Project.vue'
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

const project = ref<any>(null)
const loading = ref(true)
const error = ref<string | null>(null)

const availableRoles = ['viewer', 'author', 'reviewer', 'admin']

// Get current user from auth store
const currentUserId = computed(() => authStore.user?.id)
const isAdmin = computed(() => authStore.isAdmin)

// Compute effective permissions from memberships
const effectivePermissions = computed(() => {
  // Global admins have admin everywhere
  if (isAdmin.value) return 'admin'

  if (!project.value?.memberships || !currentUserId.value) return 'viewer'

  // Find current user's membership in this project
  const membership = project.value.memberships.find(
    (m: any) => m.user_id === currentUserId.value,
  )

  return membership?.role || 'viewer'
})

onMounted(async () => {
  try {
    const projectId = Number(route.params.id)
    const response = await getProject(projectId)
    project.value = response.data
  }
  catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load project'
    console.error('Failed to load project:', err)
  }
  finally {
    loading.value = false
  }
})
</script>

<template>
  <div>
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>

    <div v-else-if="error" class="alert alert-danger">
      {{ error }}
    </div>

    <Project
      v-else-if="project"
      :initial-project-state="project"
      :statuses="STATUSES"
      :severities="SEVERITIES"
      :available-roles="availableRoles"
      :current-user-id="currentUserId"
      :effective-permissions="effectivePermissions"
    />
  </div>
</template>
