<script setup lang="ts">
/**
 * Controls Page (Requirements Editor)
 *
 * This is the primary STIG authoring interface with two modes:
 * - Table Mode: For triage - see all requirements, quick status updates
 * - Focus Mode: For authoring - deep editing with accordion sections
 *
 * Uses async setup with Suspense for initial loading.
 * Route: /components/:id/controls
 */

import type { ISlimRule } from '@/types'
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { getComponent } from '@/apis/components.api'
import { getProject } from '@/apis/projects.api'
import {
  LayoutSwitcher,
  RequirementsFocus,
  RequirementsTable,
} from '@/components/requirements'
import { useRules } from '@/composables'
import { useAuthStore } from '@/stores'

// Types
type LayoutMode = 'table' | 'focus'

const route = useRoute()
const authStore = useAuthStore()
const { fetchRules, initSelection, selectRule, rules } = useRules()

// Layout mode - persist to localStorage
const layoutMode = ref<LayoutMode>(
  (localStorage.getItem('requirementsLayoutMode') as LayoutMode) || 'table',
)

watch(layoutMode, (mode) => {
  localStorage.setItem('requirementsLayoutMode', mode)
})

// Top-level await makes this component suspensible
const componentId = Number(route.params.id)
const componentResponse = await getComponent(componentId)
const component = componentResponse.data

if (!component) {
  throw new Error('Component not found')
}

const projectResponse = await getProject(component.project_id)
const project = projectResponse.data

if (!project) {
  throw new Error('Project not found')
}

// Fetch rules with pagination (50 per page) for better performance
await fetchRules(componentId, 1, 50)
initSelection(componentId)

// Handle deep-link from search: ?rule=123
// Select the rule after rules are loaded
onMounted(() => {
  const ruleIdParam = route.query.rule
  if (ruleIdParam) {
    const ruleId = Number(ruleIdParam)
    if (ruleId && rules.value.some(r => r.id === ruleId)) {
      selectRule(ruleId)
      // Switch to focus mode for deep-linked rules
      layoutMode.value = 'focus'
    }
  }
})

// Get current user from auth store
const currentUserId = computed(() => authStore.user?.id ?? 0)
const isAdmin = computed(() => authStore.isAdmin)

// Compute effective permissions from memberships
const effectivePermissions = computed(() => {
  if (isAdmin.value) return 'admin'
  if (!component?.memberships || !currentUserId.value) return 'viewer'

  const membership = component.memberships.find(
    (m: any) => m.user_id === currentUserId.value,
  )
  if (membership?.role) return membership.role

  const inheritedMembership = component.inherited_memberships?.find(
    (m: any) => m.user_id === currentUserId.value,
  )
  return inheritedMembership?.role || 'viewer'
})

// Breadcrumbs
const breadcrumbs = computed(() => [
  { text: 'Projects', href: '/projects' },
  { text: project.name, href: `/projects/${project.id}` },
  { text: component.name, href: `/components/${component.id}` },
  { text: 'Requirements', active: true },
])

// Page title
const pageTitle = computed(() => {
  let title = component.name
  if (component.version) title += ` V${component.version}`
  if (component.release) title += `R${component.release}`
  return title
})

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
    <!-- Header - full-width background, content aligned -->
    <div class="border-bottom bg-body-secondary">
      <div class="container-fluid container-app py-2 d-flex align-items-center justify-content-between">
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
          <h1 class="h5 mb-0">
            {{ pageTitle }} - Requirements
          </h1>
        </div>

        <!-- Layout Switcher -->
        <LayoutSwitcher v-model="layoutMode" />
      </div>
    </div>

    <!-- Content area -->
    <div class="page-content flex-grow-1 overflow-hidden">
      <div class="container-fluid container-app h-100">
        <!-- Table Mode -->
        <RequirementsTable
          v-if="layoutMode === 'table'"
          :effective-permissions="effectivePermissions"
          :component-id="component.id"
          :project-prefix="component.prefix"
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
    </div>
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
