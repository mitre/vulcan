<script setup lang="ts">
/**
 * LockProgress - Visual indicator for field-level lock status
 *
 * Shows lock progress as: 🔒🔒🔓🔓 (2/4)
 * Currently supports single locked boolean, but designed for
 * future field-level locking (Title, Vuln, Check, Fix)
 *
 * States:
 * - Unlocked: 🔓🔓🔓🔓 (0/4)
 * - Partially: 🔒🔒🔓🔓 (2/4)
 * - Fully: 🔒🔒🔒🔒 ✓ (4/4)
 */

import { computed } from 'vue'

interface Props {
  /**
   * Current implementation: single boolean for entire rule
   * Future: will accept lock counts for individual fields
   */
  locked?: boolean

  /**
   * Future: Field-level lock status
   * When provided, these take precedence over `locked` boolean
   */
  titleLocked?: boolean
  vulnLocked?: boolean
  checkLocked?: boolean
  fixLocked?: boolean

  /**
   * Show text count (2/4) alongside icons
   */
  showCount?: boolean

  /**
   * Compact mode - icons only, no spacing
   */
  compact?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  locked: false,
  titleLocked: undefined,
  vulnLocked: undefined,
  checkLocked: undefined,
  fixLocked: undefined,
  showCount: true,
  compact: false,
})

// Determine if using field-level locks or single locked boolean
const hasFieldLocks = computed(() =>
  props.titleLocked !== undefined
  || props.vulnLocked !== undefined
  || props.checkLocked !== undefined
  || props.fixLocked !== undefined,
)

// Lock states for each field
const locks = computed(() => {
  if (hasFieldLocks.value) {
    return [
      props.titleLocked ?? false,
      props.vulnLocked ?? false,
      props.checkLocked ?? false,
      props.fixLocked ?? false,
    ]
  }
  // Fallback: all fields inherit from single locked state
  const state = props.locked
  return [state, state, state, state]
})

// Count of locked fields
const lockedCount = computed(() =>
  locks.value.filter(Boolean).length,
)

// Total fields
const totalFields = 4

// Is fully locked?
const isFullyLocked = computed(() => lockedCount.value === totalFields)

// Field labels for tooltips
const fieldLabels = ['Title', 'Vuln Discussion', 'Check', 'Fix']
</script>

<template>
  <span
    class="lock-progress d-inline-flex align-items-center"
    :class="{ compact, 'fully-locked': isFullyLocked }"
    :title="`${lockedCount}/${totalFields} fields locked`"
  >
    <span class="lock-icons">
      <i
        v-for="(isLocked, index) in locks"
        :key="index"
        class="bi"
        :class="isLocked ? 'bi-lock-fill text-success' : 'bi-unlock text-muted'"
        :title="`${fieldLabels[index]}: ${isLocked ? 'Locked' : 'Unlocked'}`"
      />
    </span>
    <span v-if="showCount" class="lock-count text-muted small ms-1">
      <template v-if="isFullyLocked">
        <i class="bi bi-check-circle-fill text-success" />
      </template>
      <template v-else>
        ({{ lockedCount }}/{{ totalFields }})
      </template>
    </span>
  </span>
</template>

<style scoped>
.lock-progress {
  font-size: 0.75rem;
  line-height: 1;
}

.lock-icons {
  display: inline-flex;
  gap: 1px;
}

.lock-icons .bi {
  font-size: 0.75rem;
}

.compact .lock-icons {
  gap: 0;
}

.compact .lock-count {
  display: none;
}

.fully-locked .lock-icons .bi {
  color: var(--bs-success) !important;
}
</style>
