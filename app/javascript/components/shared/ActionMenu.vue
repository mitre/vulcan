<script setup lang="ts">
/**
 * ActionMenu.vue
 *
 * Reusable kebab menu (three-dot) dropdown for table row actions.
 * Provides a consistent, accessible action menu pattern across all tables.
 *
 * Uses Bootstrap-Vue-Next's BDropdown with strategy="fixed" to properly
 * handle overflow in scrollable containers like responsive tables.
 *
 * Usage:
 *   <ActionMenu :actions="[
 *     { id: 'view', label: 'View', icon: 'bi-eye' },
 *     { id: 'edit', label: 'Edit', icon: 'bi-pencil' },
 *     { id: 'delete', label: 'Delete', icon: 'bi-trash', variant: 'danger', dividerBefore: true },
 *   ]" @action="handleAction" />
 */
import type { ActionItem } from '@/types'
import { BDropdown, BDropdownDivider, BDropdownItemButton } from 'bootstrap-vue-next'
import { computed } from 'vue'

// Re-export for convenience
export type { ActionItem } from '@/types'

const props = withDefaults(
  defineProps<{
    actions: ActionItem[]
    size?: 'sm' | 'md' | 'lg'
    buttonVariant?: 'link' | 'outline-secondary' | 'secondary'
    dropdownAlign?: 'start' | 'end'
    ariaLabel?: string
  }>(),
  {
    size: 'sm',
    buttonVariant: 'outline-secondary',
    dropdownAlign: 'end',
    ariaLabel: 'Actions',
  },
)

const emit = defineEmits<{
  action: [actionId: string]
}>()

// Filter out hidden actions
const visibleActions = computed(() =>
  props.actions.filter(action => !action.hidden),
)

function handleAction(action: ActionItem) {
  if (action.disabled) return
  emit('action', action.id)
}

function getItemClass(action: ActionItem) {
  if (action.variant === 'danger') return 'action-danger'
  if (action.variant === 'success') return 'action-success'
  if (action.variant === 'warning') return 'action-warning'
  return ''
}
</script>

<template>
  <!-- Single action: render as button -->
  <button
    v-if="visibleActions.length === 1"
    :class="`btn btn-${size} btn-${visibleActions[0].variant || 'primary'}`"
    :disabled="visibleActions[0].disabled"
    @click="handleAction(visibleActions[0])"
  >
    <i v-if="visibleActions[0].icon" :class="visibleActions[0].icon" aria-hidden="true" />
    {{ visibleActions[0].label }}
  </button>

  <!-- Multiple actions: render as dropdown -->
  <BDropdown
    v-else-if="visibleActions.length > 1"
    :size="size"
    :variant="buttonVariant"
    :end="dropdownAlign === 'end'"
    no-caret
    strategy="fixed"
    :aria-label="ariaLabel"
  >
    <template #button-content>
      <i class="bi bi-three-dots-vertical" aria-hidden="true" />
    </template>

    <template v-for="action in visibleActions" :key="action.id">
      <!-- Divider before this item -->
      <BDropdownDivider v-if="action.dividerBefore" />

      <!-- Action item -->
      <BDropdownItemButton
        :disabled="action.disabled"
        :class="getItemClass(action)"
        @click="handleAction(action)"
      >
        <span class="d-flex align-items-center gap-2">
          <i v-if="action.icon" :class="action.icon" aria-hidden="true" />
          {{ action.label }}
        </span>
      </BDropdownItemButton>
    </template>
  </BDropdown>
</template>

<style scoped>
/* Hide default caret since we use no-caret prop */
:deep(.dropdown-toggle::after) {
  display: none;
}

/* Ensure minimum width for menu items */
:deep(.dropdown-menu) {
  min-width: 160px;
}

/* Variant colors - using !important to override Bootstrap's .dropdown-item color */
:deep(.action-danger .dropdown-item),
:deep(.action-danger.dropdown-item) {
  color: var(--bs-danger) !important;
}

:deep(.action-success .dropdown-item),
:deep(.action-success.dropdown-item) {
  color: var(--bs-success) !important;
}

:deep(.action-warning .dropdown-item),
:deep(.action-warning.dropdown-item) {
  color: var(--bs-warning) !important;
}
</style>
