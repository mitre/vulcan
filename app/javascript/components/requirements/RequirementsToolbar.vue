<script setup lang="ts">
/**
 * RequirementsToolbar - Shared toolbar for filtering/sorting requirements
 * Includes pagination controls when pagination is enabled
 */

import type { RuleStatus, RuleSeverity, IPagination } from '@/types'
import { RULE_STATUSES, RULE_SEVERITIES, SEVERITY_MAP } from '@/composables'

interface Props {
  totalCount: number
  filteredCount: number
  showNestedRules: boolean
  pagination?: IPagination | null
  loading?: boolean
}

const props = defineProps<Props>()

// v-model bindings
const searchQuery = defineModel<string>('search', { default: '' })
const filterStatus = defineModel<RuleStatus | 'all'>('filterStatus', { default: 'all' })
const filterSeverity = defineModel<RuleSeverity | 'all'>('filterSeverity', { default: 'all' })
const groupByStatus = defineModel<boolean>('groupByStatus', { default: false })

const emit = defineEmits<{
  (e: 'toggleNested'): void
  (e: 'pageChange', page: number): void
}>()
</script>

<template>
  <div class="requirements-toolbar d-flex flex-wrap gap-2 align-items-center p-3 bg-light border-bottom">
    <!-- Search -->
    <div class="input-group" style="max-width: 250px;">
      <span class="input-group-text">
        <i class="bi bi-search"></i>
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
      <option value="all">All Statuses</option>
      <option v-for="status in RULE_STATUSES" :key="status" :value="status">
        {{ status }}
      </option>
    </select>

    <!-- Severity filter -->
    <select v-model="filterSeverity" class="form-select form-select-sm" style="max-width: 130px;">
      <option value="all">All Severities</option>
      <option v-for="sev in RULE_SEVERITIES" :key="sev" :value="sev">
        {{ SEVERITY_MAP[sev] || sev }}
      </option>
    </select>

    <!-- Group toggle -->
    <div class="form-check form-check-inline mb-0">
      <input
        id="groupByStatus"
        v-model="groupByStatus"
        type="checkbox"
        class="form-check-input"
      >
      <label class="form-check-label small" for="groupByStatus">
        Group
      </label>
    </div>

    <!-- Show nested toggle -->
    <div class="form-check form-check-inline mb-0">
      <input
        id="showNested"
        :checked="showNestedRules"
        type="checkbox"
        class="form-check-input"
        @change="emit('toggleNested')"
      >
      <label class="form-check-label small" for="showNested">
        Merged
      </label>
    </div>

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
          <i class="bi bi-chevron-double-left"></i>
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_prev || loading"
          title="Previous page"
          @click="emit('pageChange', pagination.page - 1)"
        >
          <i class="bi bi-chevron-left"></i>
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_next || loading"
          title="Next page"
          @click="emit('pageChange', pagination.page + 1)"
        >
          <i class="bi bi-chevron-right"></i>
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary"
          :disabled="!pagination.has_next || loading"
          title="Last page"
          @click="emit('pageChange', pagination.total_pages)"
        >
          <i class="bi bi-chevron-double-right"></i>
        </button>
      </div>
    </div>
  </div>
</template>
