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
import { useRoute, useRouter } from 'vue-router'
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
const router = useRouter()
const authStore = useAuthStore()
const { fetchRules, initSelection, selectRule, currentRuleId } = useRules()

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

// Fetch all rules (slim data is lightweight enough for full list)
// This enables proper navigation sidebar and deep-linking
await fetchRules(componentId)
initSelection(componentId)

/**
 * Update URL with rule query parameter
 * Always uses push to add history entries (browser back works for all navigation)
 */
function updateUrl(query: Record<string, string>) {
  router.push({ query })
}

// Handle deep-link from search: ?rule=123&mode=focus
// Select the rule and set mode after rules are loaded
onMounted(async () => {
  const mode = route.query.mode as LayoutMode | undefined
  const ruleId = route.query.rule ? Number(route.query.rule) : null

  if (mode) {
    layoutMode.value = mode
  }

  if (ruleId) {
    await selectRule(ruleId)
    // If rule is specified but mode isn't, default to focus
    if (!mode) {
      layoutMode.value = 'focus'
    }
  }
})

// Watch for route query changes (browser back/forward navigation)
watch(
  () => route.query,
  async (query) => {
    const mode = query.mode as LayoutMode | undefined
    const ruleId = query.rule ? Number(query.rule) : null

    // Update layout mode from URL
    if (mode && mode !== layoutMode.value) {
      layoutMode.value = mode
    }

    // Update selected rule from URL
    if (ruleId && ruleId !== currentRuleId.value) {
      await selectRule(ruleId)
    }
  },
)

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

// Breadcrumbs - Component name is active (current page)
const breadcrumbs = computed(() => [
  { text: 'Projects', href: '/projects' },
  { text: project.name, href: `/projects/${project.id}` },
  { text: component.name, active: true },
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
  // Don't update URL on table selection - only on focus mode
}

function handleOpenFocus(rule: ISlimRule) {
  selectRule(rule.id)
  layoutMode.value = 'focus'
  updateUrl({ rule: String(rule.id), mode: 'focus' })
}

// Watch for layout mode changes to sync URL
watch(layoutMode, (newMode) => {
  if (newMode === 'table') {
    updateUrl({ mode: 'table' })
  } else if (newMode === 'focus' && currentRuleId.value) {
    updateUrl({ rule: String(currentRuleId.value), mode: 'focus' })
  }
})
</script>

<template>
  <!-- Layout 2: Editor - Two-column with sidebar -->
  <!-- Height constrained to main content area via CSS variable -->
  <div class="controls-page d-flex flex-column" style="height: var(--app-main-height);">
    <!-- Header - full-width background, content aligned -->
    <div class="border-bottom bg-body-secondary flex-shrink-0">
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

    <!-- Content area - fills remaining space, prevents overflow -->
    <div class="page-content flex-grow-1 d-flex flex-column overflow-hidden">
      <div class="container-fluid container-app h-100 d-flex flex-column">
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
/* Fix: min-height: 0 allows flex items to shrink for proper scrolling */
.controls-page {
  min-height: 0;
}
.page-content {
  min-height: 0;
}
.container-app {
  min-height: 0;
}
</style>
