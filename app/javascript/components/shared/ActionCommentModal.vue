<script setup lang="ts">
/**
 * ActionCommentModal - Reusable modal for actions requiring comments
 *
 * Used for: Lock, Unlock, Request Review, etc.
 * Features:
 * - v-model controlled visibility
 * - Configurable title, message, button text/variant
 * - Optional/required comment validation
 * - Slot for additional content
 */

import { BModal } from 'bootstrap-vue-next'
import { computed, ref, watch } from 'vue'

// Props
interface Props {
  modelValue: boolean
  title: string
  message?: string
  confirmText?: string
  confirmVariant?: string
  cancelText?: string
  requireComment?: boolean
  commentLabel?: string
  commentPlaceholder?: string
  loading?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  message: '',
  confirmText: 'Confirm',
  confirmVariant: 'primary',
  cancelText: 'Cancel',
  requireComment: false,
  commentLabel: 'Comment',
  commentPlaceholder: 'Enter a comment...',
  loading: false,
})

// Emits
const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'confirm', comment: string): void
  (e: 'cancel'): void
}>()

// Local state
const comment = ref('')

// Reset on open
watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      comment.value = ''
    }
  },
)

// Can confirm?
const canConfirm = computed(() => {
  if (props.requireComment) {
    return comment.value.trim().length > 0
  }
  return true
})

// Handlers
function handleConfirm() {
  if (!canConfirm.value || props.loading) return
  emit('confirm', comment.value.trim())
}

function handleCancel() {
  emit('cancel')
  emit('update:modelValue', false)
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
    <!-- Message -->
    <p v-if="message" class="mb-3">
      {{ message }}
    </p>

    <!-- Slot for additional content -->
    <slot />

    <!-- Comment input -->
    <div class="mb-3">
      <label class="form-label">
        {{ commentLabel }}
        <span v-if="requireComment" class="text-danger">*</span>
      </label>
      <textarea
        v-model="comment"
        class="form-control"
        rows="3"
        :placeholder="commentPlaceholder"
      />
      <div v-if="requireComment && comment.trim().length === 0" class="form-text text-danger">
        Comment is required
      </div>
    </div>

    <template #footer>
      <button class="btn btn-secondary" :disabled="loading" @click="handleCancel">
        {{ cancelText }}
      </button>
      <button
        class="btn"
        :class="`btn-${confirmVariant}`"
        :disabled="!canConfirm || loading"
        @click="handleConfirm"
      >
        <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
        {{ confirmText }}
      </button>
    </template>
  </BModal>
</template>
