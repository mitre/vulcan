<script setup lang="ts">
/**
 * SearchInput.vue
 *
 * Reusable search input with icon, optional debounce, and clear button.
 *
 * Usage:
 *   <SearchInput v-model="search" placeholder="Search users..." :debounce="300" />
 */
import { onUnmounted, ref } from 'vue'

const props = withDefaults(
  defineProps<{
    modelValue: string
    placeholder?: string
    debounce?: number
    size?: 'sm' | 'md' | 'lg'
  }>(),
  {
    placeholder: 'Search...',
    debounce: 0,
    size: 'md',
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

// Track timeout for cleanup
const timeoutId = ref<ReturnType<typeof setTimeout> | null>(null)

// Clean up timeout on unmount to prevent memory leaks
onUnmounted(() => {
  if (timeoutId.value) {
    clearTimeout(timeoutId.value)
  }
})

function handleInput(event: Event) {
  const value = (event.target as HTMLInputElement).value

  if (props.debounce > 0) {
    if (timeoutId.value) {
      clearTimeout(timeoutId.value)
    }
    timeoutId.value = setTimeout(() => emit('update:modelValue', value), props.debounce)
  }
  else {
    emit('update:modelValue', value)
  }
}

function clear() {
  if (timeoutId.value) {
    clearTimeout(timeoutId.value)
    timeoutId.value = null
  }
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="input-group" :class="{ [`input-group-${size}`]: size !== 'md' }">
    <span class="input-group-text">
      <i class="bi bi-search" aria-hidden="true" />
    </span>
    <input
      type="text"
      class="form-control"
      :placeholder="placeholder"
      :value="modelValue"
      @input="handleInput"
    >
    <button
      v-if="modelValue"
      type="button"
      class="btn btn-outline-secondary"
      aria-label="Clear search"
      @click="clear"
    >
      <i class="bi bi-x" aria-hidden="true" />
    </button>
  </div>
</template>
