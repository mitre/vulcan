<script setup lang="ts">
/**
 * SatisfiesIndicator - Shows satisfaction count for parent rules
 *
 * Display patterns:
 * - →3 = This rule satisfies 3 other rules (parent) - click opens modal
 * - — = No satisfaction relationships (or is a child rule)
 *
 * Note: The ← indicator for child rules has been moved to the ID column
 * in RequirementsTable for better visibility and click targeting.
 */

import type { ISatisfiedRuleRef } from '@/types'
import { computed } from 'vue'

interface Props {
  /**
   * The rule ID this indicator belongs to
   */
  ruleId?: number

  /**
   * Number of rules this rule satisfies (parent of relationship)
   */
  satisfiesCount?: number

  /**
   * Array of rules this rule satisfies (passed to modal)
   */
  satisfiesRules?: ISatisfiedRuleRef[]

  /**
   * Whether this rule is satisfied by another rule (child of relationship)
   * Note: Child indicator now rendered in ID column, not here
   */
  isMerged?: boolean

  /**
   * Whether actions are enabled (false for read-only mode)
   */
  actionsEnabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  ruleId: undefined,
  satisfiesCount: 0,
  satisfiesRules: () => [],
  isMerged: false,
  actionsEnabled: true,
})

const emit = defineEmits<{
  /** Open satisfaction management modal for this parent rule */
  manageSatisfactions: [parentRuleId: number]
}>()

const hasSatisfies = computed(() => (props.satisfiesCount ?? 0) > 0)

const satisfiesTooltip = computed(() => {
  if (hasSatisfies.value) {
    return `Satisfies ${props.satisfiesCount} requirement${props.satisfiesCount !== 1 ? 's' : ''} - click to manage`
  }
  return ''
})

// Event handler - opens satisfaction picker modal
function handleSatisfiesClick() {
  if (props.ruleId && props.actionsEnabled) {
    emit('manageSatisfactions', props.ruleId)
  }
}
</script>

<template>
  <!-- Only show for parent rules (satisfies others) -->
  <span v-if="hasSatisfies" class="satisfies-indicator d-inline-flex align-items-center">
    <span
      class="satisfies-badge text-info"
      :class="{ clickable: actionsEnabled }"
      :title="satisfiesTooltip"
      :role="actionsEnabled ? 'button' : undefined"
      :tabindex="actionsEnabled ? 0 : undefined"
      @click.stop="handleSatisfiesClick"
      @keydown.enter.stop="handleSatisfiesClick"
      @keydown.space.stop="handleSatisfiesClick"
    >
      <i class="bi bi-arrow-right" />{{ satisfiesCount }}
    </span>
  </span>
  <span v-else class="text-body-tertiary">—</span>
</template>

<style scoped>
.satisfies-indicator {
  font-size: 0.8rem;
  font-weight: 500;
}

.satisfies-badge {
  display: inline-flex;
  align-items: center;
  gap: 1px;
  color: var(--bs-info) !important;
}

.satisfies-badge .bi {
  font-size: 0.7rem;
}

/* Clickable indicator */
.clickable {
  cursor: pointer;
  padding: 2px 4px;
  border-radius: 4px;
  transition: background-color 0.15s ease-in-out;
}

.clickable:hover {
  background-color: rgba(var(--bs-info-rgb), 0.1);
}

.clickable:focus-visible {
  outline: 2px solid var(--bs-info);
  outline-offset: 1px;
}
</style>
