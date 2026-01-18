<script setup lang="ts">
/**
 * BulkActions - Toolbar for bulk operations on selected requirements
 *
 * Shows when one or more rules are selected in the table.
 * Provides actions: Clear Selection, Mark Satisfied By..., Remove Satisfaction
 */

import type { ISlimRule } from '@/types'
import { computed } from 'vue'

interface Props {
  /**
   * Currently selected rules
   */
  selectedRules: ISlimRule[]

  /**
   * All visible rules (for select all)
   */
  visibleRules: ISlimRule[]

  /**
   * Whether the user can edit
   */
  canEdit?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  canEdit: false,
})

const emit = defineEmits<{
  (e: 'clearSelection'): void
  (e: 'selectAll'): void
  (e: 'markSatisfiedBy'): void
  (e: 'removeSatisfaction'): void
}>()

// Computed
const selectionCount = computed(() => props.selectedRules.length)
const allSelected = computed(() =>
  props.visibleRules.length > 0
  && props.selectedRules.length === props.visibleRules.length,
)

// Can remove satisfaction only if all selected rules have a satisfaction relationship
const canRemoveSatisfaction = computed(() => {
  if (!props.canEdit || props.selectedRules.length === 0) return false
  return props.selectedRules.some(r => r.is_merged || (r.satisfies_count ?? 0) > 0)
})

// Can mark satisfied by only if all selected are not merged and have configurable status
const canMarkSatisfiedBy = computed(() => {
  if (!props.canEdit || props.selectedRules.length === 0) return false
  // Can only mark rules that aren't already satisfied by another
  return props.selectedRules.some(r => !r.is_merged)
})
</script>

<template>
  <div
    v-if="selectionCount > 0"
    class="bulk-actions d-flex align-items-center gap-3 px-3 py-2 bg-info-subtle border-bottom"
  >
    <!-- Selection count -->
    <span class="fw-semibold">
      {{ selectionCount }} selected
    </span>

    <!-- Select all / Clear all -->
    <div class="btn-group btn-group-sm">
      <button
        v-if="!allSelected"
        type="button"
        class="btn btn-outline-secondary"
        title="Select all visible"
        @click="emit('selectAll')"
      >
        <i class="bi bi-check-all me-1" /> Select All
      </button>
      <button
        type="button"
        class="btn btn-outline-secondary"
        title="Clear selection"
        @click="emit('clearSelection')"
      >
        <i class="bi bi-x me-1" /> Clear
      </button>
    </div>

    <!-- Satisfaction actions -->
    <template v-if="canEdit">
      <div class="vr" />

      <button
        type="button"
        class="btn btn-sm btn-outline-primary"
        :disabled="!canMarkSatisfiedBy"
        title="Mark selected rules as satisfied by another rule"
        @click="emit('markSatisfiedBy')"
      >
        <i class="bi bi-arrow-left me-1" /> Mark Satisfied By...
      </button>

      <button
        type="button"
        class="btn btn-sm btn-outline-danger"
        :disabled="!canRemoveSatisfaction"
        title="Remove satisfaction relationship from selected rules"
        @click="emit('removeSatisfaction')"
      >
        <i class="bi bi-x-circle me-1" /> Remove Satisfaction
      </button>
    </template>
  </div>
</template>

<style scoped>
.bulk-actions {
  container-type: inline-size;
}

@container (max-width: 500px) {
  .bulk-actions {
    flex-wrap: wrap;
    gap: 0.5rem !important;
  }

  .bulk-actions .btn {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
  }
}
</style>
