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
  }>(),
  {
    title: 'Confirm Delete',
    loading: false,
    confirmButtonText: 'Delete',
    cancelButtonText: 'Cancel',
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  'confirm': []
  'cancel': []
}>()

function handleConfirm() {
  emit('confirm')
}

function handleCancel() {
  emit('update:modelValue', false)
  emit('cancel')
}
</script>

<template>
  <BModal
    :model-value="modelValue"
    :title="title"
    centered
    @update:model-value="emit('update:modelValue', $event)"
    @hidden="handleCancel"
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
    <p class="text-body-secondary small mb-0">
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
