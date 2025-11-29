<script setup lang="ts">
/**
 * FieldEditModal - Large modal for focused editing of long text fields
 *
 * Used for: Vulnerability Discussion, Check Text, Fix Text
 * Future: Can add markdown preview toggle
 */

import { ref, watch, computed } from 'vue'
import { BModal } from 'bootstrap-vue-next'

// Props
interface Props {
  modelValue: boolean
  title: string
  fieldName: string
  value: string
  placeholder?: string
  helpText?: string
  disabled?: boolean
  rows?: number
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '',
  helpText: '',
  disabled: false,
  rows: 15,
})

// Emits
const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', value: string): void
}>()

// Local edit state
const localValue = ref(props.value)

// Sync local value when prop changes (new rule selected)
watch(() => props.value, (newVal) => {
  localValue.value = newVal
})

// Reset local value when modal opens
watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    localValue.value = props.value
  }
})

// Track if dirty
const isDirty = computed(() => localValue.value !== props.value)

// Character count
const charCount = computed(() => localValue.value?.length || 0)

// Handlers
function handleClose() {
  emit('update:modelValue', false)
}

function handleSave() {
  emit('save', localValue.value)
  emit('update:modelValue', false)
}

function handleCancel() {
  localValue.value = props.value
  emit('update:modelValue', false)
}
</script>

<template>
  <BModal
    :model-value="modelValue"
    :title="title"
    size="xl"
    scrollable
    centered
    @update:model-value="emit('update:modelValue', $event)"
    @hidden="handleClose"
  >
    <!-- Help text -->
    <div v-if="helpText" class="alert alert-info small mb-3">
      <i class="bi bi-info-circle me-1"></i>
      {{ helpText }}
    </div>

    <!-- Editor -->
    <div class="field-editor">
      <textarea
        v-model="localValue"
        class="form-control font-monospace"
        :rows="rows"
        :placeholder="placeholder"
        :disabled="disabled"
      ></textarea>
      <div class="d-flex justify-content-between mt-2 text-muted small">
        <span>{{ charCount }} characters</span>
        <span v-if="isDirty" class="text-warning">
          <i class="bi bi-exclamation-circle me-1"></i>
          Modified
        </span>
      </div>
    </div>

    <!-- Footer -->
    <template #footer>
      <div class="d-flex justify-content-between w-100">
        <div>
          <!-- Future: Markdown preview toggle -->
          <!-- <button class="btn btn-sm btn-outline-secondary">
            <i class="bi bi-eye me-1"></i>
            Preview
          </button> -->
        </div>
        <div class="d-flex gap-2">
          <button
            class="btn btn-secondary"
            @click="handleCancel"
          >
            Cancel
          </button>
          <button
            class="btn btn-primary"
            :disabled="disabled || !isDirty"
            @click="handleSave"
          >
            <i class="bi bi-check-lg me-1"></i>
            Save & Close
          </button>
        </div>
      </div>
    </template>
  </BModal>
</template>

<style scoped>
.field-editor textarea {
  min-height: 300px;
  resize: vertical;
}
</style>
