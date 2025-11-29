<script setup lang="ts">
/**
 * Controls Page (Requirements Editor)
 *
 * This is the primary STIG authoring interface with two modes:
 * - Table Mode: For triage - see all requirements, quick status updates
 * - Focus Mode: For authoring - deep editing with accordion sections
 *
 * Route: /components/:id/controls
 */

import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getComponent } from '@/apis/components.api'
import { getProject } from '@/apis/projects.api'
import { useAuthStore } from '@/stores'
import { useRules } from '@/composables'
import {
  LayoutSwitcher,
  RequirementsTable,
  RequirementsFocus,
} from '@/components/requirements'
import type { ISlimRule } from '@/types'

// Types
type LayoutMode = 'table' | 'focus'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { fetchRules, initSelection, selectRule, loading: rulesLoading } = useRules()

// Component and project state
const component = ref<any>(null)
const project = ref<any>(null)
const loading = ref(true)
const error = ref<string | null>(null)

// Layout mode - persist to localStorage
const layoutMode = ref<LayoutMode>(
  (localStorage.getItem('requirementsLayoutMode') as LayoutMode) || 'table'
)

watch(layoutMode, (mode) => {
  localStorage.setItem('requirementsLayoutMode', mode)
})

// Get current user from auth store
const currentUserId = computed(() => authStore.user?.id ?? 0)
const isAdmin = computed(() => authStore.isAdmin)

// Compute effective permissions from memberships
const effectivePermissions = computed(() => {
  if (isAdmin.value) return 'admin'
  if (!component.value?.memberships || !currentUserId.value) return 'viewer'

  const membership = component.value.memberships.find(
    (m: any) => m.user_id === currentUserId.value,
  )
  if (membership?.role) return membership.role

  const inheritedMembership = component.value.inherited_memberships?.find(
    (m: any) => m.user_id === currentUserId.value,
  )
  return inheritedMembership?.role || 'viewer'
})

// Breadcrumbs
const breadcrumbs = computed(() => {
  if (!component.value || !project.value) return []
  return [
    { text: 'Projects', href: '/projects' },
    { text: project.value.name, href: `/projects/${project.value.id}` },
    { text: component.value.name, href: `/components/${component.value.id}` },
    { text: 'Requirements', active: true },
  ]
})

// Page title
const pageTitle = computed(() => {
  if (!component.value) return 'Requirements'
  let title = component.value.name
  if (component.value.version) title += ` V${component.value.version}`
  if (component.value.release) title += `R${component.value.release}`
  return title
})

// Load data
onMounted(async () => {
  await loadData(Number(route.params.id))
})

// Watch for route changes
watch(
  () => route.params.id,
  async (newId, oldId) => {
    if (newId && newId !== oldId) {
      await loadData(Number(newId))
    }
  },
)

async function loadData(componentId: number) {
  loading.value = true
  error.value = null

  try {
    const componentResponse = await getComponent(componentId)
    component.value = componentResponse.data

    if (component.value?.project_id) {
      const projectResponse = await getProject(component.value.project_id)
      project.value = projectResponse.data
    }

    // Fetch rules with pagination (50 per page) for better performance
    // For components with many rules, this dramatically improves load times
    await fetchRules(componentId, 1, 50)
    initSelection(componentId)
  }
  catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load component'
    console.error('Failed to load controls page:', err)
  }
  finally {
    loading.value = false
  }
}

// Event handlers - receive slim rule from table
function handleSelectRule(rule: ISlimRule) {
  selectRule(rule.id)
}

function handleOpenFocus(rule: ISlimRule) {
  selectRule(rule.id)
  layoutMode.value = 'focus'
}
</script>

<template>
  <div class="controls-page d-flex flex-column h-100">
    <!-- Loading -->
    <div v-if="loading" class="flex-grow-1 d-flex align-items-center justify-content-center">
      <div class="text-center">
        <div class="spinner-border" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
        <p class="mt-2 text-muted">Loading requirements...</p>
      </div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="m-3">
      <div class="alert alert-danger">
        <h5 class="alert-heading">Error Loading Requirements</h5>
        <p class="mb-0">{{ error }}</p>
        <hr>
        <button class="btn btn-outline-danger btn-sm" @click="router.back()">
          Go Back
        </button>
      </div>
    </div>

    <!-- Main content -->
    <template v-else-if="component && project">
      <!-- Header -->
      <div class="page-header px-3 py-2 border-bottom bg-light">
        <div class="d-flex align-items-center justify-content-between">
          <!-- Breadcrumb + Title -->
          <div>
            <nav aria-label="breadcrumb">
              <ol class="breadcrumb mb-1 small">
                <li
                  v-for="(crumb, index) in breadcrumbs"
                  :key="index"
                  class="breadcrumb-item"
                  :class="{ active: crumb.active }"
                >
                  <router-link v-if="!crumb.active" :to="crumb.href">
                    {{ crumb.text }}
                  </router-link>
                  <span v-else>{{ crumb.text }}</span>
                </li>
              </ol>
            </nav>
            <h1 class="h5 mb-0">{{ pageTitle }} - Requirements</h1>
          </div>

          <!-- Layout Switcher -->
          <LayoutSwitcher v-model="layoutMode" />
        </div>
      </div>

      <!-- Content area -->
      <div class="page-content flex-grow-1 overflow-hidden">
        <!-- Table Mode -->
        <RequirementsTable
          v-if="layoutMode === 'table'"
          :effective-permissions="effectivePermissions"
          @select="handleSelectRule"
          @open-focus="handleOpenFocus"
        />

        <!-- Focus Mode -->
        <RequirementsFocus
          v-else
          :effective-permissions="effectivePermissions"
          :component-id="component.id"
          :project-prefix="component.prefix"
        />
      </div>
    </template>
  </div>
</template>

<style scoped>
.controls-page {
  min-height: 0; /* Allow flex children to shrink */
}
.page-content {
  min-height: 0;
}
</style>
