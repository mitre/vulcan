<script setup lang="ts">
/**
 * DeleteModal.vue
 *
 * Reusable delete confirmation modal.
 *
 * Usage:
 *   <DeleteModal
 *     v-model="showDeleteModal"
 *     :item-name="itemToDelete?.name"
 *     :loading="deleting"
 *     @confirm="executeDelete"
 *   />
 */
import { BModal } from 'bootstrap-vue-next'

const props = withDefaults(
  defineProps<{
    modelValue: boolean
    title?: string
    itemName?: string
    loading?: boolean
    /** Custom message (overrides default) */
    message?: string
    /** Danger text for extra emphasis */
    dangerText?: string
    confirmButtonText?: string
    cancelButtonText?: string
    /** Hide the "cannot be undone" warning (use when undo is available) */
    hideUndoWarning?: boolean
  }>(),
  {
    title: 'Confirm Delete',
    loading: false,
    confirmButtonText: 'Delete',
    cancelButtonText: 'Cancel',
    hideUndoWarning: false,
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  'confirm': []
  'cancel': []
}>()

// Track if confirm was clicked to prevent cancel on hidden
let confirmClicked = false

function handleConfirm() {
  confirmClicked = true
  emit('confirm')
}

function handleCancel() {
  emit('update:modelValue', false)
  emit('cancel')
}

function handleHidden() {
  // Only emit cancel if the modal was closed without confirming
  // (e.g., clicking backdrop, pressing Escape, or Cancel button)
  if (!confirmClicked) {
    emit('cancel')
  }
  // Reset for next open
  confirmClicked = false
}
</script>

<template>
  <BModal
    :model-value="modelValue"
    :title="title"
    centered
    @update:model-value="emit('update:modelValue', $event)"
    @hidden="handleHidden"
  >
    <p v-if="message">
      {{ message }}
    </p>
    <p v-else>
      Are you sure you want to delete
      <strong v-if="itemName">{{ itemName }}</strong>
      <span v-else>this item</span>?
    </p>
    <p v-if="dangerText" class="text-danger small">
      <i class="bi bi-exclamation-triangle me-1" aria-hidden="true" />
      {{ dangerText }}
    </p>
    <p v-if="!hideUndoWarning" class="text-body-secondary small mb-0">
      This action cannot be undone.
    </p>

    <template #footer>
      <button
        type="button"
        class="btn btn-secondary"
        @click="handleCancel"
      >
        {{ cancelButtonText }}
      </button>
      <button
        type="button"
        class="btn btn-danger"
        :disabled="loading"
        @click="handleConfirm"
      >
        <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
        {{ confirmButtonText }}
      </button>
    </template>
  </BModal>
</template>
