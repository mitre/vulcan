<script setup lang="ts">
/**
 * RequirementsToolbar - Shared toolbar for filtering/sorting requirements
 * Includes pagination controls when pagination is enabled
 */

import type { IPagination, RuleSeverity, RuleStatus } from '@/types'
import { RULE_SEVERITIES, RULE_STATUSES, SEVERITY_MAP } from '@/composables'

/**
 * Lock status filter options
 */
export type LockFilter = 'all' | 'locked' | 'unlocked'

/**
 * Review status filter options
 */
export type ReviewFilter = 'all' | 'pending' | 'changes_requested' | 'approved' | 'none'

/**
 * Satisfies status filter options
 */
export type SatisfiesFilter = 'all' | 'satisfies_others' | 'satisfied_by' | 'no_satisfaction'

interface Props {
  totalCount: number
  filteredCount: number
  showNestedRules: boolean
  componentId: number
  hasSatisfiesRelationships?: boolean
  pagination?: IPagination | null
  loading?: boolean
  showFindReplace?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  hasSatisfiesRelationships: false,
  showFindReplace: false,
})

const emit = defineEmits<{
  (e: 'toggleNested'): void
  (e: 'pageChange', page: number): void
  (e: 'openFindReplace'): void
}>()
// v-model bindings
const searchQuery = defineModel<string>('search', { default: '' })
const filterStatus = defineModel<RuleStatus | 'all'>('filterStatus', { default: 'all' })
const filterSeverity = defineModel<RuleSeverity | 'all'>('filterSeverity', { default: 'all' })
const filterLock = defineModel<LockFilter>('filterLock', { default: 'all' })
const filterReview = defineModel<ReviewFilter>('filterReview', { default: 'all' })
const filterSatisfies = defineModel<SatisfiesFilter>('filterSatisfies', { default: 'all' })
const groupByStatus = defineModel<boolean>('groupByStatus', { default: false })
</script>

<template>
  <div class="requirements-toolbar d-flex flex-wrap gap-2 align-items-center py-3 bg-body-secondary border-bottom">
    <!-- Search -->
    <div class="input-group" style="max-width: 250px;">
      <span class="input-group-text">
        <i class="bi bi-search" />
      </span>
      <input
        v-model="searchQuery"
        type="text"
        class="form-control form-control-sm"
        placeholder="Search..."
      >
    </div>

    <!-- Status filter -->
    <select v-model="filterStatus" class="form-select form-select-sm" style="max-width: 180px;">
      <option value="all">
        All Statuses
      </option>
      <option v-for="status in RULE_STATUSES" :key="status" :value="status">
        {{ status }}
      </option>
    </select>

    <!-- Severity filter -->
    <select v-model="filterSeverity" class="form-select form-select-sm" style="max-width: 130px;">
      <option value="all">
        All Severities
      </option>
      <option v-for="sev in RULE_SEVERITIES" :key="sev" :value="sev">
        {{ SEVERITY_MAP[sev] || sev }}
      </option>
    </select>

    <!-- Lock filter -->
    <select v-model="filterLock" class="form-select form-select-sm" style="max-width: 120px;">
      <option value="all">
        All Locks
      </option>
      <option value="locked">
        Locked
      </option>
      <option value="unlocked">
        Unlocked
      </option>
    </select>

    <!-- Review filter -->
    <select v-model="filterReview" class="form-select form-select-sm" style="max-width: 150px;">
      <option value="all">
        All Reviews
      </option>
      <option value="pending">
        Pending Review
      </option>
      <option value="changes_requested">
        Changes Requested
      </option>
      <option value="approved">
        Approved
      </option>
      <option value="none">
        No Review
      </option>
    </select>

    <!-- Satisfies filter -->
    <select v-model="filterSatisfies" class="form-select form-select-sm" style="max-width: 150px;">
      <option value="all">
        All Satisfies
      </option>
      <option value="satisfies_others">
        Satisfies Others
      </option>
      <option value="satisfied_by">
        Satisfied By
      </option>
      <option value="no_satisfaction">
        No Satisfaction
      </option>
    </select>

    <!-- Group toggle (switch style) -->
    <div class="form-check form-switch form-check-inline mb-0">
      <input
        id="groupByStatus"
        v-model="groupByStatus"
        type="checkbox"
        class="form-check-input"
        role="switch"
      >
      <label class="form-check-label small" for="groupByStatus">
        Group
      </label>
    </div>

    <!-- Show nested toggle (switch style, disabled when no relationships) -->
    <div class="form-check form-switch form-check-inline mb-0">
      <input
        id="showNested"
        :checked="showNestedRules"
        :disabled="!hasSatisfiesRelationships"
        type="checkbox"
        class="form-check-input"
        role="switch"
        :title="hasSatisfiesRelationships ? 'Toggle visibility of satisfied rules' : 'No satisfaction relationships in this component'"
        @change="emit('toggleNested')"
      >
      <label
        class="form-check-label small"
        for="showNested"
        :class="{ 'text-muted': !hasSatisfiesRelationships }"
      >
        Show Satisfied
      </label>
    </div>

    <!-- Find & Replace button -->
    <button
      v-if="showFindReplace"
      type="button"
      class="btn btn-sm btn-outline-primary"
      title="Find & Replace"
      @click="emit('openFindReplace')"
    >
      <i class="bi bi-search me-1" />
      Find
    </button>

    <!-- Legacy Editor link -->
    <a
      :href="`/components/${props.componentId}`"
      class="btn btn-sm btn-outline-secondary"
      title="Open Classic Editor (legacy view)"
    >
      <i class="bi bi-clock-history me-1" />
      Classic
    </a>

    <!-- Stats & Pagination -->
    <div class="ms-auto d-flex align-items-center gap-3">
      <!-- Page info -->
      <span class="text-muted small">
        <template v-if="pagination">
          Page {{ pagination.page }} of {{ pagination.total_pages }}
          ({{ pagination.total_count }} total)
        </template>
        <template v-else>
          {{ filteredCount }} of {{ totalCount }}
        </template>
      </span>

      <!-- Pagination controls -->
      <div v-if="pagination" class="btn-group btn-group-sm">
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_prev || loading"
          title="First page"
          @click="emit('pageChange', 1)"
        >
          <i class="bi bi-chevron-double-left" />
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_prev || loading"
          title="Previous page"
          @click="emit('pageChange', pagination.page - 1)"
        >
          <i class="bi bi-chevron-left" />
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_next || loading"
          title="Next page"
          @click="emit('pageChange', pagination.page + 1)"
        >
          <i class="bi bi-chevron-right" />
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_next || loading"
          title="Last page"
          @click="emit('pageChange', pagination.total_pages)"
        >
          <i class="bi bi-chevron-double-right" />
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Full-bleed background: extends edge-to-edge while content stays in container */
.requirements-toolbar {
  margin-left: calc(-50vw + 50%);
  margin-right: calc(-50vw + 50%);
  padding-left: calc(50vw - 50%);
  padding-right: calc(50vw - 50%);
}
</style>
