<script setup lang="ts">
/**
 * RequirementsTable - Triage Mode
 *
 * Table view for quickly triaging requirements.
 * Uses shared components for badges, toolbar, progress bar.
 */

import type { ISlimRule, RuleSeverity, RuleStatus } from '@/types'
import { computed, ref } from 'vue'
import { RULE_SEVERITIES, RULE_STATUSES, useRules } from '@/composables'
import FindReplaceModal from './FindReplaceModal.vue'
import RequirementsToolbar from './RequirementsToolbar.vue'
import SeverityBadge from './SeverityBadge.vue'
import StatusBadge from './StatusBadge.vue'
import StatusProgressBar from './StatusProgressBar.vue'

// Props
interface Props {
  effectivePermissions: string
  componentId: number
  projectPrefix: string
}

const props = defineProps<Props>()

// Emits - slim rule for list operations
const emit = defineEmits<{
  (e: 'select', rule: ISlimRule): void
  (e: 'openFocus', rule: ISlimRule): void
  (e: 'replaced'): void
}>()

// Store
const {
  visibleRules,
  showNestedRules,
  toggleNestedRules,
  updateRule,
  loading,
  pagination,
  goToPage,
} = useRules()

// Filter state
const searchQuery = ref('')
const filterStatus = ref<RuleStatus | 'all'>('all')
const filterSeverity = ref<RuleSeverity | 'all'>('all')
const groupByStatus = ref(false)

// Find/Replace modal state
const showFindModal = ref(false)

// Sort state
const sortField = ref<'rule_id' | 'status' | 'rule_severity' | 'title'>('rule_id')
const sortDir = ref<'asc' | 'desc'>('asc')

// Permissions
const canEdit = computed(() => ['admin', 'author', 'reviewer'].includes(props.effectivePermissions))

// Filtered rules
const filteredRules = computed(() => {
  let result = [...visibleRules.value]

  if (filterStatus.value !== 'all') {
    result = result.filter(r => r.status === filterStatus.value)
  }
  if (filterSeverity.value !== 'all') {
    result = result.filter(r => r.rule_severity === filterSeverity.value)
  }
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(r =>
      r.rule_id.toLowerCase().includes(q)
      || r.title.toLowerCase().includes(q),
    )
  }

  return result
})

// Sorted rules
const sortedRules = computed(() => {
  return [...filteredRules.value].sort((a, b) => {
    let cmp = 0
    if (sortField.value === 'rule_id') cmp = a.rule_id.localeCompare(b.rule_id)
    else if (sortField.value === 'title') cmp = a.title.localeCompare(b.title)
    else if (sortField.value === 'status') cmp = RULE_STATUSES.indexOf(a.status as any) - RULE_STATUSES.indexOf(b.status as any)
    else if (sortField.value === 'rule_severity') cmp = RULE_SEVERITIES.indexOf(a.rule_severity) - RULE_SEVERITIES.indexOf(b.rule_severity)
    return sortDir.value === 'asc' ? cmp : -cmp
  })
})

// Grouped by status
const groupedRules = computed(() => {
  if (!groupByStatus.value) return null
  const groups: Record<string, ISlimRule[]> = {}
  for (const status of RULE_STATUSES) {
    const items = sortedRules.value.filter(r => r.status === status)
    if (items.length) groups[status] = items
  }
  return groups
})

// Handlers
function toggleSort(field: typeof sortField.value) {
  if (sortField.value === field) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  }
  else {
    sortField.value = field
    sortDir.value = 'asc'
  }
}

function sortIndicator(field: typeof sortField.value): string {
  if (sortField.value !== field) return ''
  return sortDir.value === 'asc' ? ' ▲' : ' ▼'
}

async function onStatusChange(rule: ISlimRule, newStatus: RuleStatus) {
  if (!rule.locked) {
    await updateRule(rule.id, { status: newStatus })
  }
}
</script>

<template>
  <div class="requirements-table d-flex flex-column h-100">
    <!-- Toolbar -->
    <RequirementsToolbar
      v-model:search="searchQuery"
      v-model:filter-status="filterStatus"
      v-model:filter-severity="filterSeverity"
      v-model:group-by-status="groupByStatus"
      :total-count="visibleRules.length"
      :filtered-count="filteredRules.length"
      :show-nested-rules="showNestedRules"
      :pagination="pagination"
      :loading="loading"
      :show-find-replace="canEdit"
      @toggle-nested="toggleNestedRules()"
      @page-change="goToPage"
      @open-find-replace="showFindModal = true"
    />

    <!-- Progress bar -->
    <StatusProgressBar :rules="visibleRules" />

    <!-- Table -->
    <div class="table-container flex-grow-1 overflow-auto">
      <!-- Ungrouped -->
      <table v-if="!groupByStatus" class="table table-hover table-sm mb-0">
        <thead class="table-light sticky-top">
          <tr>
            <th class="sortable" style="width: 120px" @click="toggleSort('status')">
              Status{{ sortIndicator('status') }}
            </th>
            <th class="sortable" style="width: 90px" @click="toggleSort('rule_id')">
              ID{{ sortIndicator('rule_id') }}
            </th>
            <th class="sortable" @click="toggleSort('title')">
              Title{{ sortIndicator('title') }}
            </th>
            <th class="sortable" style="width: 90px" @click="toggleSort('rule_severity')">
              Severity{{ sortIndicator('rule_severity') }}
            </th>
            <th style="width: 70px">
              Review
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="rule in sortedRules"
            :key="rule.id"
            class="clickable"
            :class="{ 'table-secondary': rule.locked, 'opacity-50': rule.is_merged }"
            @click="emit('select', rule)"
            @dblclick="emit('openFocus', rule)"
          >
            <td>
              <select
                v-if="canEdit && !rule.locked"
                :value="rule.status"
                class="form-select form-select-sm py-0"
                style="font-size: 0.75rem"
                @click.stop
                @change="onStatusChange(rule, ($event.target as HTMLSelectElement).value as RuleStatus)"
              >
                <option v-for="s in RULE_STATUSES" :key="s" :value="s">
                  {{ s.replace('Applicable - ', '') }}
                </option>
              </select>
              <StatusBadge v-else :status="rule.status" short />
            </td>
            <td class="font-monospace small">
              {{ rule.rule_id }}
              <i v-if="rule.locked" class="bi bi-lock-fill text-muted" />
            </td>
            <td class="text-truncate" style="max-width: 400px">
              {{ rule.title }}
              <span v-if="rule.is_merged" class="badge bg-secondary ms-1">merged</span>
            </td>
            <td><SeverityBadge :severity="rule.rule_severity" /></td>
            <td>
              <span v-if="rule.review_requestor_id" class="badge bg-warning">Pending</span>
              <span v-else-if="rule.locked" class="badge bg-success">Approved</span>
            </td>
          </tr>
          <tr v-if="!sortedRules.length">
            <td colspan="5" class="text-center text-muted py-4">
              No requirements match filters
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Grouped -->
      <template v-else-if="groupedRules">
        <div v-for="(rules, status) in groupedRules" :key="status" class="group">
          <div class="group-header d-flex align-items-center gap-2 p-2 bg-body-secondary border-bottom sticky-top">
            <StatusBadge :status="status as RuleStatus" />
            <span class="fw-semibold">{{ rules.length }}</span>
          </div>
          <table class="table table-hover table-sm mb-0">
            <tbody>
              <tr
                v-for="rule in rules"
                :key="rule.id"
                class="clickable"
                @click="emit('select', rule)"
                @dblclick="emit('openFocus', rule)"
              >
                <td class="font-monospace small" style="width: 90px">
                  {{ rule.rule_id }}
                </td>
                <td class="text-truncate">
                  {{ rule.title }}
                </td>
                <td style="width: 90px">
                  <SeverityBadge :severity="rule.rule_severity" />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="loading-overlay">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>

    <!-- Find & Replace Modal -->
    <FindReplaceModal
      v-model="showFindModal"
      :component-id="componentId"
      :project-prefix="projectPrefix"
      :read-only="!canEdit"
      @replaced="emit('replaced')"
    />
  </div>
</template>

<style scoped>
.sortable {
  cursor: pointer;
  user-select: none;
}
.sortable:hover {
  background-color: var(--bs-tertiary-bg);
}
.clickable {
  cursor: pointer;
}
.sticky-top {
  position: sticky;
  top: 0;
  z-index: 1;
}
.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
