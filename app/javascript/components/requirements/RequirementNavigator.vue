<script setup lang="ts">
/**
 * RequirementNavigator - Left sidebar for Focus mode
 *
 * Compact list of requirements with:
 * - Filter input
 * - Status indicators
 * - Click to select
 * - Keyboard navigation (j/k)
 * - Find & Replace modal
 */

import type { ISlimRule } from '@/types'
import { computed, nextTick, ref, watch } from 'vue'
import { useRules } from '@/composables'
import FindReplaceModal from './FindReplaceModal.vue'

// Props
interface Props {
  componentId: number
  projectPrefix: string
  readOnly?: boolean
}

const _props = withDefaults(defineProps<Props>(), {
  readOnly: false,
})

// Emits - slim rule for list operations
const emit = defineEmits<{
  (e: 'select', rule: ISlimRule): void
  (e: 'replaced'): void
}>()

// Store
const {
  visibleRules,
  currentRule,
  currentRuleId,
  showNestedRules,
  toggleNestedRules,
  selectRule,
  refreshRule,
} = useRules()

// Local state
const searchQuery = ref('')
const collapsed = ref(false)
const showFindModal = ref(false)
const navListRef = ref<HTMLElement | null>(null)

// Scroll selected item into view when currentRuleId changes
watch(currentRuleId, async (newId) => {
  if (newId) {
    await nextTick()
    const selectedEl = navListRef.value?.querySelector('.bg-primary')
    selectedEl?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }
})

// Filtered list
const filteredRules = computed(() => {
  if (!searchQuery.value.trim()) return visibleRules.value
  const q = searchQuery.value.toLowerCase()
  return visibleRules.value.filter(r =>
    r.rule_id.toLowerCase().includes(q)
    || r.title.toLowerCase().includes(q),
  )
})

// Select and emit
function handleSelect(rule: ISlimRule) {
  selectRule(rule.id)
  emit('select', rule)
}

// Keyboard navigation
function handleKeydown(e: KeyboardEvent) {
  if (!filteredRules.value.length) return

  const currentIndex = currentRule.value
    ? filteredRules.value.findIndex(r => r.id === currentRule.value?.id)
    : -1

  if (e.key === 'j' || e.key === 'ArrowDown') {
    e.preventDefault()
    const next = Math.min(currentIndex + 1, filteredRules.value.length - 1)
    handleSelect(filteredRules.value[next])
  }
  else if (e.key === 'k' || e.key === 'ArrowUp') {
    e.preventDefault()
    const prev = Math.max(currentIndex - 1, 0)
    handleSelect(filteredRules.value[prev])
  }
}

// Is this rule selected?
function isSelected(rule: ISlimRule): boolean {
  return currentRuleId.value === rule.id
}

// Status dot color
function statusDot(rule: ISlimRule): string {
  const colors: Record<string, string> = {
    'Not Yet Determined': 'secondary',
    'Applicable - Configurable': 'success',
    'Applicable - Inherently Meets': 'info',
    'Applicable - Does Not Meet': 'danger',
    'Not Applicable': 'dark',
  }
  return colors[rule.status] || 'secondary'
}

// Handle replacement - refresh current rule if it was affected
async function handleReplaced() {
  if (currentRule.value) {
    await refreshRule(currentRule.value.id)
  }
  emit('replaced')
}
</script>

<template>
  <div
    class="requirement-navigator d-flex flex-column border-end"
    :class="{ collapsed }"
    tabindex="0"
    @keydown="handleKeydown"
  >
    <!-- Header -->
    <div class="nav-header p-2 border-bottom d-flex align-items-center gap-2">
      <button
        class="btn btn-sm btn-outline-secondary"
        title="Toggle navigator"
        @click="collapsed = !collapsed"
      >
        <i :class="collapsed ? 'bi bi-chevron-right' : 'bi bi-chevron-left'" />
      </button>
      <template v-if="!collapsed">
        <input
          v-model="searchQuery"
          type="text"
          class="form-control form-control-sm flex-grow-1"
          placeholder="Filter..."
        >
        <button
          class="btn btn-sm btn-outline-primary"
          title="Find & Replace"
          @click="showFindModal = true"
        >
          <i class="bi bi-search" />
        </button>
      </template>
    </div>

    <!-- Options -->
    <div v-if="!collapsed" class="nav-options px-2 py-1 border-bottom small">
      <div class="form-check form-check-inline mb-0">
        <input
          id="navShowMerged"
          :checked="showNestedRules"
          type="checkbox"
          class="form-check-input"
          @change="toggleNestedRules()"
        >
        <label class="form-check-label" for="navShowMerged">Show Satisfied</label>
      </div>
      <span class="text-muted ms-2">{{ filteredRules.length }}</span>
    </div>

    <!-- List - Bootstrap overflow-auto handles scrolling -->
    <div ref="navListRef" class="nav-list flex-grow-1 overflow-auto">
      <div
        v-for="rule in filteredRules"
        :key="rule.id"
        class="nav-item d-flex align-items-center gap-2 px-2 py-1 border-bottom"
        :class="{
          'bg-primary text-white': isSelected(rule),
          'opacity-50': rule.is_merged,
        }"
        role="button"
        @click="handleSelect(rule)"
      >
        <!-- Status dot -->
        <span
          class="status-dot rounded-circle"
          :class="`bg-${statusDot(rule)}`"
          style="width: 8px; height: 8px; flex-shrink: 0"
        />

        <!-- ID -->
        <span class="font-monospace small" style="min-width: 60px">
          {{ collapsed ? rule.rule_id.slice(-3) : rule.rule_id }}
        </span>

        <!-- Title (hidden when collapsed) -->
        <span v-if="!collapsed" class="text-truncate small flex-grow-1">
          {{ rule.title }}
        </span>

        <!-- Indicators -->
        <span v-if="!collapsed" class="indicators">
          <i v-if="rule.locked" class="bi bi-lock-fill text-muted" />
          <i v-if="rule.review_requestor_id" class="bi bi-eye text-warning" />
        </span>
      </div>

      <div v-if="!filteredRules.length" class="text-center text-muted py-3 small">
        No matches
      </div>
    </div>

    <!-- Find & Replace Modal -->
    <FindReplaceModal
      v-model="showFindModal"
      :component-id="componentId"
      :project-prefix="projectPrefix"
      :read-only="readOnly"
      @replaced="handleReplaced"
    />
  </div>
</template>

<style scoped>
.requirement-navigator {
  /* Sidebar in flex container - uses CSS variable for width */
  width: var(--app-sidebar-width);
  flex-shrink: 0;
  /* align-self: stretch is default in flexbox - fills parent height */
  transition: width 0.2s ease;
  background-color: var(--bs-body-bg);
  /* Enable container queries for child elements */
  container-type: inline-size;
  container-name: nav-sidebar;
  overflow: hidden; /* Parent clips, .nav-list child scrolls */
}
.requirement-navigator.collapsed {
  width: var(--app-sidebar-width-collapsed);
}
.requirement-navigator:focus {
  outline: none;
}
.nav-header {
  background-color: var(--bs-tertiary-bg);
  flex-shrink: 0;
}
.nav-options {
  flex-shrink: 0;
}
.nav-list {
  /* This is the scrollable area */
  overflow-y: auto;
  /* Fix: min-height: 0 allows flex item to shrink below content size */
  /* Without this, the scroll zone can be very small */
  min-height: 0;
}
.nav-item {
  cursor: pointer;
}
.nav-item:hover:not(.bg-primary) {
  background-color: var(--bs-secondary-bg);
}

/* When stacked vertically (narrow parent), limit height */
@container requirements-focus (max-width: 768px) {
  .requirement-navigator {
    width: 100%;
    max-height: 40vh;
    border-end: none;
    border-bottom: 1px solid var(--bs-border-color);
  }
}

/* Fallback for older browsers */
@supports not (container-type: inline-size) {
  @media (max-width: 768px) {
    .requirement-navigator {
      width: 100%;
      max-height: 40vh;
    }
  }
}
</style>
