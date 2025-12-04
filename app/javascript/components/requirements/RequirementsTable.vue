<script setup lang="ts">
/**
 * RequirementsTable - Triage Mode
 *
 * Table view for quickly triaging requirements.
 * Uses BTable from Bootstrap-Vue-Next with row-details for satisfaction relationships.
 *
 * TWO MUTUALLY EXCLUSIVE VIEWS (XOR):
 *
 * 1. FLAT VIEW (showNestedRules=true, "Show Satisfied" checked):
 *    - Shows ALL rules in a flat list: 000010, 000020, ... 001002, 001003, 001004
 *    - No expand buttons, no nesting
 *    - Every rule appears as a row, satisfied children show "← Satisfied" badge
 *
 * 2. HIERARCHICAL VIEW (showNestedRules=false, "Show Satisfied" unchecked):
 *    - Shows ONLY primary/parent rules (hides is_merged=true rules)
 *    - Parent rules with satisfies_count > 0 get expand buttons
 *    - Clicking expand shows satisfied children in row-details section
 *
 * Terminology:
 * - "Parent" rule: A rule that satisfies other rules (satisfies_count > 0)
 * - "Child" rule: A rule that is satisfied by another rule (is_merged = true)
 */

import type { TableFieldRaw } from 'bootstrap-vue-next'
import type { LockFilter, ReviewFilter, SatisfiesFilter } from './RequirementsToolbar.vue'
import type { SummaryFilter } from './TableView'
import type { ISlimRule, RuleSeverity, RuleStatus } from '@/types'
import { BTable } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'
import { RULE_STATUSES, useRules } from '@/composables'
import DeleteModal from '../shared/DeleteModal.vue'
import FindReplaceModal from './FindReplaceModal.vue'
import RequirementsToolbar from './RequirementsToolbar.vue'
import SatisfactionPickerModal from './SatisfactionPickerModal.vue'
import SeverityBadge from './SeverityBadge.vue'
import StatusBadge from './StatusBadge.vue'
import StatusProgressBar from './StatusProgressBar.vue'
import {
  BulkActions,
  LockProgress,
  ReviewStatus,
  SummaryCards,
} from './TableView'

// Extended rule type with BTable's _showDetails
interface ITableRule extends ISlimRule {
  _showDetails?: boolean
}

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
  rules, // All rules (unfiltered)
  visibleRules,
  showNestedRules,
  toggleNestedRules,
  updateRule,
  loading,
  pagination,
  goToPage,
  addSatisfaction,
  removeSatisfaction,
} = useRules()

// Filter state
const searchQuery = ref('')
const filterStatus = ref<RuleStatus | 'all'>('all')
const filterSeverity = ref<RuleSeverity | 'all'>('all')
const filterLock = ref<LockFilter>('all')
const filterReview = ref<ReviewFilter>('all')
const filterSatisfies = ref<SatisfiesFilter>('all')
const groupByStatus = ref(false)
const summaryFilter = ref<SummaryFilter>(null)

// Collapsed status groups - persisted to localStorage
const COLLAPSED_GROUPS_KEY = 'vulcan-collapsed-status-groups'
const collapsedGroups = ref<Set<string>>(new Set())

// Load collapsed state from localStorage on mount
function loadCollapsedGroups() {
  try {
    const saved = localStorage.getItem(COLLAPSED_GROUPS_KEY)
    if (saved) {
      collapsedGroups.value = new Set(JSON.parse(saved))
    }
  }
  catch {
    // Ignore parse errors
  }
}

// Save collapsed state to localStorage
function saveCollapsedGroups() {
  localStorage.setItem(COLLAPSED_GROUPS_KEY, JSON.stringify([...collapsedGroups.value]))
}

// Toggle a status group collapsed state
function toggleGroupCollapsed(status: string) {
  if (collapsedGroups.value.has(status)) {
    collapsedGroups.value.delete(status)
  }
  else {
    collapsedGroups.value.add(status)
  }
  // Trigger reactivity
  collapsedGroups.value = new Set(collapsedGroups.value)
  saveCollapsedGroups()
}

// Check if a group is collapsed
function isGroupCollapsed(status: string): boolean {
  return collapsedGroups.value.has(status)
}

// Load on component setup
loadCollapsedGroups()

// Find/Replace modal state
const showFindModal = ref(false)

// Remove satisfaction confirmation modal state
const showRemoveSatisfactionModal = ref(false)
const satisfactionToRemove = ref<{
  childId: number
  parentId: number
  childRuleId: string
} | null>(null)
const removingSatisfaction = ref(false)

// Satisfaction picker modal state
const showSatisfactionPickerModal = ref(false)
const satisfactionPickerParentId = ref<number>(0)
const satisfactionPickerParentDisplayId = ref<string>('')
const satisfactionPickerCurrentSatisfiedIds = ref<number[]>([])
const addingSatisfactions = ref(false)

// Sort state - BTable uses array of { key, order } objects
const sortBy = ref([{ key: 'rule_id', order: 'asc' as const }])

/**
 * Custom sort compare function for BTable
 * Handles special cases like severity sorting (CAT I > CAT II > CAT III)
 * BTable calls this and applies asc/desc direction internally
 */
function sortCompare(a: ITableRule, b: ITableRule, key: string): number {
  let aVal: string | number | null = null
  let bVal: string | number | null = null

  // Get values based on sort key
  switch (key) {
    case 'rule_id':
      aVal = a.rule_id
      bVal = b.rule_id
      break
    case 'status':
      aVal = a.status
      bVal = b.status
      break
    case 'title':
      aVal = a.title
      bVal = b.title
      break
    case 'rule_severity':
      // Sort by severity priority: CAT I (high) = 1, CAT II (medium) = 2, CAT III (low) = 3, unknown = 4
      // Lower number = higher priority, so ascending sort shows CAT I first
      const severityOrder: Record<string, number> = { high: 1, medium: 2, low: 3, unknown: 4 }
      aVal = severityOrder[a.rule_severity] ?? 5
      bVal = severityOrder[b.rule_severity] ?? 5
      break
    default:
      aVal = String(a[key as keyof ITableRule] ?? '')
      bVal = String(b[key as keyof ITableRule] ?? '')
  }

  // Compare values
  if (aVal === bVal) return 0
  if (aVal == null) return 1
  if (bVal == null) return -1
  if (typeof aVal === 'number' && typeof bVal === 'number') {
    return aVal - bVal
  }
  return String(aVal).localeCompare(String(bVal))
}

// Selection state for bulk actions
const selectedRuleIds = ref<Set<number>>(new Set())
const selectedRules = computed(() =>
  tableItems.value.filter(r => selectedRuleIds.value.has(r.id)),
)

// Check if any rule in the FULL dataset has satisfaction relationships (for enabling the toggle)
// This checks ALL rules, not filtered/visible ones
const componentHasSatisfiesRelationships = computed(() => {
  // Check both: rules that satisfy others (satisfies_count > 0) AND rules that are satisfied (is_merged)
  return rules.value.some(r => (r.satisfies_count ?? 0) > 0 || r.is_merged)
})

// BTable fields definition - unified actions column replaces select/expand/sat columns
const tableFields = computed<TableFieldRaw<ITableRule>[]>(() => {
  return [
    {
      key: 'actions',
      label: '',
      thClass: 'actions-col',
      tdClass: 'actions-col',
      sortable: false,
    },
    {
      key: 'status',
      label: 'Status',
      sortable: true,
      thClass: 'status-col',
      tdClass: 'status-col',
    },
    {
      key: 'rule_id',
      label: 'ID',
      sortable: true,
      thClass: 'id-col',
      tdClass: 'id-col font-monospace small',
    },
    {
      key: 'title',
      label: 'Title',
      sortable: true,
      tdClass: 'title-col',
    },
    {
      key: 'rule_severity',
      label: 'Severity',
      sortable: true,
      thClass: 'severity-col',
      tdClass: 'severity-col',
    },
    {
      key: 'review',
      label: 'Review',
      sortable: false,
      thClass: 'review-col',
      tdClass: 'review-col',
    },
    {
      key: 'lock',
      label: 'Lock',
      sortable: false,
      thClass: 'lock-col',
      tdClass: 'lock-col text-center',
    },
  ]
})

// Selection handlers
function toggleRuleSelection(rule: ISlimRule) {
  const newSet = new Set(selectedRuleIds.value)
  if (newSet.has(rule.id)) {
    newSet.delete(rule.id)
  }
  else {
    newSet.add(rule.id)
  }
  selectedRuleIds.value = newSet
}

function toggleAllSelection() {
  if (selectedRuleIds.value.size === tableItems.value.length) {
    selectedRuleIds.value = new Set()
  }
  else {
    selectedRuleIds.value = new Set(tableItems.value.map(r => r.id))
  }
}

function clearSelection() {
  selectedRuleIds.value = new Set()
}

function selectAll() {
  selectedRuleIds.value = new Set(tableItems.value.map(r => r.id))
}

function handleMarkSatisfiedBy() {
  // TODO: Implement satisfaction modal in Phase 3.8
  console.log('Mark satisfied by:', selectedRules.value)
}

function handleRemoveSatisfaction() {
  // TODO: Implement remove satisfaction in Phase 3.8
  console.log('Remove satisfaction:', selectedRules.value)
}

// SatisfiesIndicator event handlers
function handleNavigateToRule(ruleId: number) {
  // Find the rule in ALL rules (not filtered tableItems) and open focus view
  // This handles navigation to parent rules that may be hidden in hierarchical view
  const rule = rules.value.find(r => r.id === ruleId)
  if (rule) {
    emit('openFocus', rule)
  }
}

function handleRemoveSatisfactionFromIndicator(childRuleId: number, parentRuleId: number) {
  // Show confirmation dialog before removing
  // Find the child rule to get its display ID
  const childRule = rules.value.find(r => r.id === childRuleId)
  satisfactionToRemove.value = {
    childId: childRuleId,
    parentId: parentRuleId,
    childRuleId: childRule?.rule_id || String(childRuleId),
  }
  showRemoveSatisfactionModal.value = true
}

async function confirmRemoveSatisfaction() {
  if (!satisfactionToRemove.value) return

  removingSatisfaction.value = true
  try {
    const { childId, parentId } = satisfactionToRemove.value
    await removeSatisfaction(childId, parentId)
    showRemoveSatisfactionModal.value = false
    satisfactionToRemove.value = null
  }
  finally {
    removingSatisfaction.value = false
  }
}

function handleAddSatisfactionFromIndicator(parentRuleId: number) {
  // Find the parent rule to get display ID and current satisfies_rules
  const parentRule = rules.value.find(r => r.id === parentRuleId)
  if (!parentRule) return

  // Open the satisfaction picker modal
  satisfactionPickerParentId.value = parentRuleId
  satisfactionPickerParentDisplayId.value = parentRule.rule_id
  satisfactionPickerCurrentSatisfiedIds.value = parentRule.satisfies_rules?.map(r => r.id) ?? []
  showSatisfactionPickerModal.value = true
}

/**
 * Handle adding satisfaction relationships from picker modal
 */
async function handleSatisfactionPickerAdd(childRuleIds: number[]) {
  if (childRuleIds.length === 0) return

  addingSatisfactions.value = true
  try {
    // Add each satisfaction sequentially to avoid race conditions
    for (const childId of childRuleIds) {
      await addSatisfaction(childId, satisfactionPickerParentId.value)
    }
  }
  finally {
    addingSatisfactions.value = false
  }
}

/**
 * Handle removing satisfaction relationships from picker modal
 */
async function handleSatisfactionPickerRemove(childRuleIds: number[]) {
  if (childRuleIds.length === 0) return

  // Remove each satisfaction - removeSatisfaction already has undo toast
  for (const childId of childRuleIds) {
    await removeSatisfaction(childId, satisfactionPickerParentId.value)
  }
}

// Permissions
const canEdit = computed(() => ['admin', 'author', 'reviewer'].includes(props.effectivePermissions))

// Filtered rules
const filteredRules = computed(() => {
  let result = [...visibleRules.value]

  // Status filter
  if (filterStatus.value !== 'all') {
    result = result.filter(r => r.status === filterStatus.value)
  }
  // Severity filter
  if (filterSeverity.value !== 'all') {
    result = result.filter(r => r.rule_severity === filterSeverity.value)
  }
  // Search filter
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(r =>
      r.rule_id.toLowerCase().includes(q)
      || r.title.toLowerCase().includes(q),
    )
  }
  // Lock filter
  if (filterLock.value !== 'all') {
    if (filterLock.value === 'locked') {
      result = result.filter(r => r.locked)
    }
    else {
      result = result.filter(r => !r.locked)
    }
  }
  // Review filter
  if (filterReview.value !== 'all') {
    switch (filterReview.value) {
      case 'pending':
        result = result.filter(r => r.review_requestor_id != null && !r.locked && !r.changes_requested)
        break
      case 'changes_requested':
        result = result.filter(r => r.changes_requested)
        break
      case 'approved':
        result = result.filter(r => r.locked)
        break
      case 'none':
        result = result.filter(r => r.review_requestor_id == null && !r.locked && !r.changes_requested)
        break
    }
  }
  // Satisfies filter
  if (filterSatisfies.value !== 'all') {
    switch (filterSatisfies.value) {
      case 'satisfies_others':
        result = result.filter(r => (r.satisfies_count ?? 0) > 0)
        break
      case 'satisfied_by':
        result = result.filter(r => r.is_merged)
        break
      case 'no_satisfaction':
        result = result.filter(r => (r.satisfies_count ?? 0) === 0 && !r.is_merged)
        break
    }
  }
  // Summary card filter
  if (summaryFilter.value) {
    switch (summaryFilter.value) {
      case 'pending_review':
        result = result.filter(r => r.review_requestor_id != null && !r.locked)
        break
      case 'changes_requested':
        result = result.filter(r => r.changes_requested)
        break
      case 'locked':
        result = result.filter(r => r.locked)
        break
      case 'satisfies_others':
        result = result.filter(r => (r.satisfies_count ?? 0) > 0)
        break
      case 'satisfied_by':
        result = result.filter(r => r.is_merged)
        break
    }
  }

  return result
})

// Handle summary card filter
function handleSummaryFilter(filter: SummaryFilter) {
  // Toggle: if same filter clicked again, clear it
  if (summaryFilter.value === filter) {
    summaryFilter.value = null
  }
  else {
    summaryFilter.value = filter
  }
}

// Table items with _showDetails for BTable row-details
// We handle sorting ourselves since BTable's sortCompare doesn't seem to work reliably
const tableItems = computed<ITableRule[]>(() => {
  const items = filteredRules.value.map(rule => ({
    ...rule,
    _showDetails: false, // Will be toggled by BTable
  }))

  // Apply sorting based on sortBy state
  if (sortBy.value.length > 0) {
    const { key, order } = sortBy.value[0]
    items.sort((a, b) => {
      const result = sortCompare(a, b, key)
      return order === 'desc' ? -result : result
    })
  }

  return items
})

// Row class function for BTable
function rowClass(item: ITableRule | null): string {
  if (!item) return ''
  const classes: string[] = ['clickable']
  if (item.locked) classes.push('table-secondary')
  // Satisfied-by rows get subtle styling (left border, slight tint)
  if (item.is_merged) classes.push('satisfied-by-row')
  if (selectedRuleIds.value.has(item.id)) classes.push('table-info')
  return classes.join(' ')
}

// Handlers
function handleRowClick(item: ITableRule) {
  emit('select', item)
}

function handleRowDblClick(item: ITableRule) {
  emit('openFocus', item)
}

async function onStatusChange(rule: ISlimRule, newStatus: RuleStatus) {
  if (!rule.locked) {
    await updateRule(rule.id, { status: newStatus })
  }
}

// Check if rule satisfies other rules (parent of satisfaction relationship)
function satisfiesOtherRules(rule: ISlimRule): boolean {
  return (rule.satisfies_count ?? 0) > 0
}

// Grouped by status
const groupedRules = computed(() => {
  if (!groupByStatus.value) return null
  const groups: Record<string, ISlimRule[]> = {}
  for (const status of RULE_STATUSES) {
    const items = filteredRules.value.filter(r => r.status === status)
    if (items.length) groups[status] = items
  }
  return groups
})

// Indeterminate state for header checkbox
const isIndeterminate = computed(() =>
  selectedRuleIds.value.size > 0 && selectedRuleIds.value.size < tableItems.value.length,
)
const isAllSelected = computed(() =>
  tableItems.value.length > 0 && selectedRuleIds.value.size === tableItems.value.length,
)
</script>

<template>
  <div class="requirements-table d-flex flex-column h-100">
    <!-- Toolbar -->
    <RequirementsToolbar
      v-model:search="searchQuery"
      v-model:filter-status="filterStatus"
      v-model:filter-severity="filterSeverity"
      v-model:filter-lock="filterLock"
      v-model:filter-review="filterReview"
      v-model:filter-satisfies="filterSatisfies"
      v-model:group-by-status="groupByStatus"
      :component-id="props.componentId"
      :total-count="visibleRules.length"
      :filtered-count="filteredRules.length"
      :show-nested-rules="showNestedRules"
      :has-satisfies-relationships="componentHasSatisfiesRelationships"
      :pagination="pagination"
      :loading="loading"
      :show-find-replace="canEdit"
      @toggle-nested="toggleNestedRules()"
      @page-change="goToPage"
      @open-find-replace="showFindModal = true"
    />

    <!-- Progress bar -->
    <StatusProgressBar :rules="visibleRules" />

    <!-- Summary Cards -->
    <SummaryCards :rules="visibleRules" @filter="handleSummaryFilter" />

    <!-- Active summary filter indicator -->
    <div
      v-if="summaryFilter"
      class="active-filter d-flex align-items-center gap-2 px-3 py-1 bg-primary-subtle border-bottom"
    >
      <span class="small">Filtered by: <strong>{{ summaryFilter.replace('_', ' ') }}</strong></span>
      <button
        type="button"
        class="btn btn-sm btn-link p-0 text-primary"
        @click="summaryFilter = null"
      >
        <i class="bi bi-x-circle" /> Clear
      </button>
    </div>

    <!-- Bulk Actions Bar -->
    <BulkActions
      :selected-rules="selectedRules"
      :visible-rules="tableItems"
      :can-edit="canEdit"
      @clear-selection="clearSelection"
      @select-all="selectAll"
      @mark-satisfied-by="handleMarkSatisfiedBy"
      @remove-satisfaction="handleRemoveSatisfaction"
    />

    <!-- Table -->
    <div class="table-container flex-grow-1 overflow-auto">
      <!-- Ungrouped - BTable -->
      <!-- Note: We handle sorting ourselves in tableItems computed, BTable just tracks sortBy state for header UI -->
      <BTable
        v-if="!groupByStatus"
        v-model:sort-by="sortBy"
        :items="tableItems"
        :fields="tableFields"
        no-local-sorting
        must-sort
        hover
        small
        class="requirements-btable mb-0"
        thead-class="table-light sticky-top"
        :tbody-tr-class="rowClass"
        @row-clicked="handleRowClick"
        @row-dblclicked="handleRowDblClick"
      >
        <!-- Actions column header -->
        <template #head(actions)>
          <input
            type="checkbox"
            class="form-check-input"
            :checked="isAllSelected"
            :indeterminate="isIndeterminate"
            title="Select all"
            @change="toggleAllSelection()"
          >
        </template>

        <!-- Actions cell - unified checkbox + expand/navigate + satisfaction indicator -->
        <template #cell(actions)="{ item, toggleDetails }">
          <div class="actions-cell d-flex align-items-center gap-1">
            <!-- Checkbox -->
            <input
              type="checkbox"
              class="form-check-input flex-shrink-0"
              :checked="selectedRuleIds.has(item.id)"
              @click.stop
              @change="toggleRuleSelection(item)"
            >
            <!-- Parent rule: expand chevron with count (only in hierarchical view) -->
            <button
              v-if="!showNestedRules && satisfiesOtherRules(item)"
              type="button"
              class="btn btn-sm btn-link p-0 d-inline-flex align-items-center expand-btn"
              title="Show satisfied rules - click to expand"
              @click.stop="toggleDetails"
            >
              <i :class="item._showDetails ? 'bi-chevron-down' : 'bi-chevron-right'" class="text-secondary" />
              <span class="satisfies-count text-info">{{ item.satisfies_count }}</span>
            </button>
            <!-- Parent rule in flat view: just show →N indicator (clickable to manage) -->
            <span
              v-else-if="showNestedRules && satisfiesOtherRules(item)"
              class="satisfies-badge text-info"
              :class="{ clickable: canEdit }"
              :title="`Satisfies ${item.satisfies_count} requirement${item.satisfies_count !== 1 ? 's' : ''} - click to manage`"
              :role="canEdit ? 'button' : undefined"
              :tabindex="canEdit ? 0 : undefined"
              @click.stop="canEdit && handleAddSatisfactionFromIndicator(item.id)"
              @keydown.enter.stop="canEdit && handleAddSatisfactionFromIndicator(item.id)"
              @keydown.space.stop="canEdit && handleAddSatisfactionFromIndicator(item.id)"
            >
              <i class="bi bi-arrow-right" />{{ item.satisfies_count }}
            </span>
            <!-- Child rule: clickable ← arrow to navigate to parent -->
            <span
              v-else-if="item.is_merged && item.satisfied_by?.length"
              class="satisfied-link"
              role="button"
              tabindex="0"
              :title="`Satisfied by ${item.satisfied_by[0].rule_id} - click to view parent`"
              @click.stop="handleNavigateToRule(item.satisfied_by[0].id)"
              @keydown.enter.stop="handleNavigateToRule(item.satisfied_by[0].id)"
            >
              <i class="bi bi-arrow-left text-info" />
            </span>
          </div>
        </template>

        <!-- Status cell -->
        <template #cell(status)="{ item }">
          <select
            v-if="canEdit && !item.locked"
            :value="item.status"
            class="form-select form-select-sm py-0"
            style="font-size: 0.75rem"
            @click.stop
            @change="onStatusChange(item, ($event.target as HTMLSelectElement).value as RuleStatus)"
          >
            <option v-for="s in RULE_STATUSES" :key="s" :value="s">
              {{ s.replace('Applicable - ', '') }}
            </option>
          </select>
          <StatusBadge v-else :status="item.status" short />
        </template>

        <!-- Rule ID cell -->
        <template #cell(rule_id)="{ item }">
          {{ item.rule_id }}
          <i v-if="item.locked" class="bi bi-lock-fill text-muted ms-1" />
        </template>

        <!-- Title cell -->
        <template #cell(title)="{ item }">
          {{ item.title }}
        </template>

        <!-- Severity cell -->
        <template #cell(rule_severity)="{ item }">
          <SeverityBadge :severity="item.rule_severity" />
        </template>

        <!-- Review cell -->
        <template #cell(review)="{ item }">
          <ReviewStatus
            :review-requestor-id="item.review_requestor_id"
            :changes-requested="item.changes_requested"
            :locked="item.locked"
          />
        </template>

        <!-- Lock cell -->
        <template #cell(lock)="{ item }">
          <LockProgress :locked="item.locked" :show-count="false" compact />
        </template>

        <!-- Row details - shows rules this rule satisfies -->
        <template #row-details="{ item }">
          <div class="row-details-content ps-5 py-2 bg-body-secondary border-bottom">
            <!-- Action bar header -->
            <div class="satisfies-header d-flex align-items-center justify-content-between mb-2">
              <div class="small text-body-secondary">
                <i class="bi bi-diagram-2 me-1" />
                This rule satisfies {{ item.satisfies_count }} other requirement(s)
              </div>
              <button
                v-if="canEdit"
                type="button"
                class="btn btn-sm btn-outline-primary"
                title="Manage satisfactions"
                @click.stop="handleAddSatisfactionFromIndicator(item.id)"
              >
                <i class="bi bi-pencil me-1" />Manage
              </button>
            </div>
            <!-- Satisfied rules list with left-side actions -->
            <div v-if="item.satisfies_rules?.length" class="satisfied-rules-list">
              <div
                v-for="satisfiedRule in item.satisfies_rules"
                :key="satisfiedRule.id"
                class="satisfied-rule d-flex align-items-center gap-2 py-1"
              >
                <!-- Left-side remove button -->
                <button
                  v-if="canEdit"
                  type="button"
                  class="btn btn-sm btn-link text-danger p-0 satisfaction-remove-btn"
                  title="Remove satisfaction"
                  @click.stop="handleRemoveSatisfactionFromIndicator(satisfiedRule.id, item.id)"
                >
                  <i class="bi bi-dash-circle" />
                </button>
                <span v-else class="satisfaction-spacer" />
                <span class="font-monospace small text-nowrap text-body">{{ satisfiedRule.rule_id }}</span>
                <span class="small text-body-secondary text-truncate flex-grow-1">{{ satisfiedRule.title }}</span>
                <!-- Right-side navigate button -->
                <button
                  type="button"
                  class="btn btn-sm btn-link text-primary p-0"
                  title="Go to rule"
                  @click.stop="handleNavigateToRule(satisfiedRule.id)"
                >
                  <i class="bi bi-arrow-right-circle" />
                </button>
              </div>
            </div>
            <div v-else class="text-body-secondary small fst-italic">
              Loading satisfied rules...
            </div>
          </div>
        </template>

        <!-- Empty state -->
        <template #empty>
          <div class="text-center text-muted py-4">
            No requirements match filters
          </div>
        </template>
      </BTable>

      <!-- Grouped -->
      <template v-else-if="groupedRules">
        <div v-for="(rules, status) in groupedRules" :key="status" class="group">
          <button
            type="button"
            class="group-header d-flex align-items-center gap-2 p-2 bg-body-secondary border-bottom sticky-top w-100 text-start"
            @click="toggleGroupCollapsed(status as string)"
          >
            <i :class="isGroupCollapsed(status as string) ? 'bi-chevron-right' : 'bi-chevron-down'" />
            <StatusBadge :status="status as RuleStatus" />
            <span class="fw-semibold">{{ rules.length }}</span>
          </button>
          <BTable
            v-if="!isGroupCollapsed(status as string)"
            :items="rules"
            :fields="[
              { key: 'rule_id', label: 'ID', tdClass: 'font-monospace small', thStyle: { width: '90px' } },
              { key: 'title', label: 'Title', tdClass: 'text-truncate' },
              { key: 'rule_severity', label: 'Severity', thStyle: { width: '90px' } },
            ]"
            hover
            small
            thead-class="d-none"
            @row-clicked="handleRowClick"
            @row-dblclicked="handleRowDblClick"
          >
            <template #cell(rule_severity)="{ item }">
              <SeverityBadge :severity="item.rule_severity" />
            </template>
          </BTable>
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

    <!-- Remove Satisfaction Confirmation Modal -->
    <DeleteModal
      v-model="showRemoveSatisfactionModal"
      title="Remove Satisfaction"
      :item-name="satisfactionToRemove?.childRuleId"
      message="Are you sure you want to remove this satisfaction relationship?"
      confirm-button-text="Remove"
      :loading="removingSatisfaction"
      hide-undo-warning
      @confirm="confirmRemoveSatisfaction"
    />

    <!-- Satisfaction Picker Modal -->
    <SatisfactionPickerModal
      v-model="showSatisfactionPickerModal"
      :parent-rule-id="satisfactionPickerParentId"
      :parent-rule-display-id="satisfactionPickerParentDisplayId"
      :rules="rules"
      :current-satisfied-rule-ids="satisfactionPickerCurrentSatisfiedIds"
      :loading="addingSatisfactions"
      @add="handleSatisfactionPickerAdd"
      @remove="handleSatisfactionPickerRemove"
    />
  </div>
</template>

<style scoped>
/* Ensure table respects parent flexbox bounds */
.requirements-table {
  min-height: 0;
}
.table-container {
  min-height: 0;
}
.clickable {
  cursor: pointer;
}
.sticky-top {
  position: sticky;
  top: 0;
  z-index: 1;
}

/* Group header button styling */
button.group-header {
  border: none;
  cursor: pointer;
  font-size: inherit;
}
button.group-header:hover {
  background-color: var(--bs-tertiary-bg) !important;
}
button.group-header:focus {
  outline: none;
  box-shadow: inset 0 0 0 2px var(--bs-primary);
}

.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
}

/* BTable - match original native table styling */
:deep(.requirements-btable) {
  /* Column widths - matching original design */
  .actions-col { width: 70px; text-align: left; vertical-align: middle; }
  .status-col { width: 130px; vertical-align: middle; }
  .id-col { width: 100px; vertical-align: middle; }
  .title-col { max-width: 400px; vertical-align: middle; }
  .severity-col { width: 90px; vertical-align: middle; }
  .review-col { width: 70px; vertical-align: middle; }
  .lock-col { width: 50px; vertical-align: middle; }

  /* Actions cell layout */
  .actions-cell {
    min-width: 60px;
  }

  .expand-btn {
    font-size: 0.85rem;
  }

  .satisfies-count {
    font-size: 0.75rem;
    font-weight: 500;
  }

  .satisfies-badge {
    display: inline-flex;
    align-items: center;
    gap: 1px;
    font-size: 0.8rem;
    font-weight: 500;
  }

  .satisfies-badge .bi {
    font-size: 0.7rem;
  }

  .satisfies-badge.clickable {
    cursor: pointer;
    padding: 2px 4px;
    border-radius: 4px;
    transition: background-color 0.15s ease-in-out;
  }

  .satisfies-badge.clickable:hover {
    background-color: rgba(var(--bs-info-rgb), 0.1);
  }

  .satisfies-badge.clickable:focus-visible {
    outline: 2px solid var(--bs-info);
    outline-offset: 1px;
  }

  /* Header styling */
  thead th {
    font-weight: 600;
    white-space: nowrap;
    vertical-align: middle;
  }

  /* Sortable column headers */
  th[aria-sort] {
    cursor: pointer;
    user-select: none;
  }
  th[aria-sort]:hover {
    background-color: var(--bs-tertiary-bg);
  }

  /* Row styling */
  tbody td {
    vertical-align: middle;
  }

  tr.clickable:hover {
    background-color: var(--bs-tertiary-bg);
  }

  /* Status dropdown compact styling */
  .form-select-sm {
    padding: 0.15rem 1.5rem 0.15rem 0.5rem;
    font-size: 0.75rem;
  }

  /* Row details (expanded satisfaction relationships) */
  .b-table-details td {
    padding: 0 !important;
    background-color: var(--bs-body-secondary);
  }

  /* Satisfied-by rows - subtle left border + background tint */
  tr.satisfied-by-row {
    border-left: 3px solid var(--bs-info);
    background-color: rgba(var(--bs-info-rgb), 0.03);
  }

  tr.satisfied-by-row td:first-child {
    padding-left: calc(0.75rem - 3px); /* Account for border */
  }

  /* Ensure hover still works on satisfied-by rows */
  tr.satisfied-by-row.clickable:hover {
    background-color: rgba(var(--bs-info-rgb), 0.08);
  }

  /* Satisfaction row-details styling */
  .satisfies-header {
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--bs-border-color-translucent);
  }

  .satisfied-rules-list {
    max-height: 300px;
    overflow-y: auto;
  }

  /* Satisfied-link in ID column - clickable arrow to parent */
  .satisfied-link {
    cursor: pointer;
    padding: 2px 4px;
    border-radius: 4px;
    transition: background-color 0.15s ease-in-out;
  }

  .satisfied-link:hover {
    background-color: rgba(var(--bs-info-rgb), 0.15);
  }

  .satisfied-link:focus-visible {
    outline: 2px solid var(--bs-info);
    outline-offset: 1px;
  }

  .satisfied-rule {
    border-bottom: 1px solid var(--bs-border-color-translucent);
  }

  .satisfied-rule:last-child {
    border-bottom: none;
  }

  .satisfied-rule:hover {
    background-color: rgba(var(--bs-body-color-rgb), 0.03);
  }

  .satisfaction-remove-btn {
    width: 1.25rem;
    flex-shrink: 0;
    opacity: 0.6;
    transition: opacity 0.15s ease-in-out;
  }

  .satisfaction-remove-btn:hover {
    opacity: 1;
  }

  .satisfaction-spacer {
    width: 1.25rem;
    flex-shrink: 0;
  }
}
</style>
