<script setup lang="ts">
/**
 * SatisfactionPickerModal - Add/Edit satisfaction relationships for a parent rule
 *
 * Shows list of available rules with checkboxes. Pre-checks already satisfied rules.
 * User can add (check) or remove (uncheck) satisfaction relationships.
 *
 * Usage:
 *   <SatisfactionPickerModal
 *     v-model="showModal"
 *     :parent-rule-id="selectedRule.id"
 *     :parent-rule-display-id="selectedRule.rule_id"
 *     :rules="rules"
 *     :current-satisfied-rule-ids="satisfiedRuleIds"
 *     @add="handleAddSatisfactions"
 *     @remove="handleRemoveSatisfactions"
 *   />
 */

import type { ISlimRule } from '@/types'
import { BModal } from 'bootstrap-vue-next'
import { computed, ref, watch } from 'vue'

// Props
interface Props {
  modelValue: boolean
  parentRuleId: number
  parentRuleDisplayId: string
  rules: ISlimRule[]
  /** IDs of rules currently satisfied by the parent */
  currentSatisfiedRuleIds?: number[]
  loading?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  currentSatisfiedRuleIds: () => [],
  loading: false,
})

// Emits
const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  /** Called when user confirms additions */
  'add': [childRuleIds: number[]]
  /** Called when user confirms removals */
  'remove': [childRuleIds: number[]]
}>()

// Search filter
const searchQuery = ref('')

// Local selection state (rule ID → checked)
const selectedRuleIds = ref<Set<number>>(new Set())

// Initialize selection when modal opens
watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    // Pre-select currently satisfied rules
    selectedRuleIds.value = new Set(props.currentSatisfiedRuleIds)
    searchQuery.value = ''
  }
})

// Available rules: exclude parent rule (can't satisfy self) and already-merged rules
// (rules that are children of another parent shouldn't be re-parented here)
const availableRules = computed(() => {
  return props.rules.filter((rule) => {
    // Exclude self
    if (rule.id === props.parentRuleId) return false
    // Exclude rules that are already satisfied by ANOTHER rule (unless it's this parent)
    // But allow rules already satisfied by THIS parent (so we can show them checked and allow removal)
    if (rule.is_merged && !props.currentSatisfiedRuleIds.includes(rule.id)) return false
    return true
  })
})

// Filtered by search
const filteredRules = computed(() => {
  if (!searchQuery.value.trim()) {
    return availableRules.value
  }
  const q = searchQuery.value.toLowerCase()
  return availableRules.value.filter(r =>
    r.rule_id.toLowerCase().includes(q)
    || r.title.toLowerCase().includes(q),
  )
})

// Sort: Currently satisfied rules first, then by rule_id
const sortedFilteredRules = computed(() => {
  return [...filteredRules.value].sort((a, b) => {
    const aIsCurrent = props.currentSatisfiedRuleIds.includes(a.id)
    const bIsCurrent = props.currentSatisfiedRuleIds.includes(b.id)
    // Currently satisfied first
    if (aIsCurrent && !bIsCurrent) return -1
    if (!aIsCurrent && bIsCurrent) return 1
    // Then by rule_id
    return a.rule_id.localeCompare(b.rule_id)
  })
})

// Computed diff: what's added and what's removed
const toAdd = computed(() => {
  const current = new Set(props.currentSatisfiedRuleIds)
  return [...selectedRuleIds.value].filter(id => !current.has(id))
})

const toRemove = computed(() => {
  const selected = selectedRuleIds.value
  return props.currentSatisfiedRuleIds.filter(id => !selected.has(id))
})

const hasChanges = computed(() => toAdd.value.length > 0 || toRemove.value.length > 0)

const selectionCount = computed(() => selectedRuleIds.value.size)

// Toggle single rule selection
function toggleRule(ruleId: number) {
  const newSet = new Set(selectedRuleIds.value)
  if (newSet.has(ruleId)) {
    newSet.delete(ruleId)
  }
  else {
    newSet.add(ruleId)
  }
  selectedRuleIds.value = newSet
}

// Check if rule is selected
function isSelected(ruleId: number): boolean {
  return selectedRuleIds.value.has(ruleId)
}

// Check if rule is currently satisfied (for styling)
function isCurrentlySatisfied(ruleId: number): boolean {
  return props.currentSatisfiedRuleIds.includes(ruleId)
}

// Handlers
function handleClose() {
  emit('update:modelValue', false)
}

function handleSave() {
  // Emit add events for newly checked rules
  if (toAdd.value.length > 0) {
    emit('add', toAdd.value)
  }
  // Emit remove events for unchecked rules
  if (toRemove.value.length > 0) {
    emit('remove', toRemove.value)
  }
  emit('update:modelValue', false)
}

function handleCancel() {
  emit('update:modelValue', false)
}
</script>

<template>
  <BModal
    :model-value="modelValue"
    :title="`Edit Satisfactions for ${parentRuleDisplayId}`"
    size="lg"
    scrollable
    centered
    @update:model-value="emit('update:modelValue', $event)"
    @hidden="handleClose"
  >
    <!-- Search -->
    <div class="mb-3">
      <div class="input-group">
        <span class="input-group-text">
          <i class="bi bi-search" />
        </span>
        <input
          v-model="searchQuery"
          type="search"
          class="form-control"
          placeholder="Search by ID or title..."
          aria-label="Search rules"
        >
      </div>
    </div>

    <!-- Help text -->
    <div class="alert alert-info small py-2 mb-3">
      <i class="bi bi-info-circle me-1" />
      Check rules that should be satisfied by <strong>{{ parentRuleDisplayId }}</strong>.
      Checked rules will be marked as "satisfied by" this rule.
    </div>

    <!-- Rules list -->
    <div class="rules-list">
      <div v-if="sortedFilteredRules.length === 0" class="text-center text-muted py-4">
        <template v-if="searchQuery">
          No rules match "{{ searchQuery }}"
        </template>
        <template v-else>
          No available rules to satisfy
        </template>
      </div>

      <div
        v-for="rule in sortedFilteredRules"
        :key="rule.id"
        class="rule-item d-flex align-items-center gap-2 py-2 px-2"
        :class="{
          'currently-satisfied': isCurrentlySatisfied(rule.id),
          'bg-success-subtle': isSelected(rule.id) && !isCurrentlySatisfied(rule.id),
          'bg-warning-subtle': !isSelected(rule.id) && isCurrentlySatisfied(rule.id),
        }"
        role="button"
        tabindex="0"
        @click="toggleRule(rule.id)"
        @keydown.enter="toggleRule(rule.id)"
        @keydown.space.prevent="toggleRule(rule.id)"
      >
        <input
          type="checkbox"
          class="form-check-input m-0"
          :checked="isSelected(rule.id)"
          @click.stop
          @change="toggleRule(rule.id)"
        >
        <div class="flex-grow-1 min-w-0">
          <div class="d-flex align-items-center gap-2">
            <span class="font-monospace small text-nowrap">{{ rule.rule_id }}</span>
            <span v-if="isCurrentlySatisfied(rule.id)" class="badge bg-secondary-subtle text-secondary small">
              Currently satisfied
            </span>
          </div>
          <div class="small text-body-secondary text-truncate">
            {{ rule.title }}
          </div>
        </div>
      </div>
    </div>

    <!-- Summary of changes -->
    <div v-if="hasChanges" class="changes-summary mt-3 pt-3 border-top">
      <div v-if="toAdd.length > 0" class="small text-success">
        <i class="bi bi-plus-circle me-1" />
        {{ toAdd.length }} rule(s) will be added
      </div>
      <div v-if="toRemove.length > 0" class="small text-warning">
        <i class="bi bi-dash-circle me-1" />
        {{ toRemove.length }} rule(s) will be removed
      </div>
    </div>

    <!-- Footer -->
    <template #footer>
      <div class="d-flex justify-content-between w-100">
        <span class="text-muted small align-self-center">
          {{ selectionCount }} selected
        </span>
        <div class="d-flex gap-2">
          <button
            type="button"
            class="btn btn-secondary"
            @click="handleCancel"
          >
            Cancel
          </button>
          <button
            type="button"
            class="btn btn-primary"
            :disabled="loading || !hasChanges"
            @click="handleSave"
          >
            <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
            <i v-else class="bi bi-check-lg me-1" />
            Save Changes
          </button>
        </div>
      </div>
    </template>
  </BModal>
</template>

<style scoped>
.rules-list {
  max-height: 400px;
  overflow-y: auto;
}

.rule-item {
  cursor: pointer;
  border-radius: 4px;
  border: 1px solid transparent;
  transition: background-color 0.15s ease-in-out;
}

.rule-item:hover {
  background-color: rgba(var(--bs-primary-rgb), 0.1);
}

.rule-item:focus-visible {
  outline: 2px solid var(--bs-primary);
  outline-offset: 1px;
}

/* Currently satisfied (will be removed if unchecked) */
.rule-item.currently-satisfied {
  border-left: 3px solid var(--bs-secondary);
}

/* Visual feedback for pending changes */
.rule-item.bg-success-subtle {
  border-left: 3px solid var(--bs-success);
}

.rule-item.bg-warning-subtle {
  border-left: 3px solid var(--bs-warning);
}
</style>
