<script setup lang="ts">
import { ref } from 'vue'

// Fixed checkbox without forceUpdateKey re-render issue

interface Props {
  id?: string
  modelValue?: boolean
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: false,
  disabled: false,
})

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const checkboxRef = ref<HTMLInputElement | null>(null)

function onChange(event: Event) {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.checked)
}
</script>

<template>
  <div class="form-check">
    <input
      :id="id"
      ref="checkboxRef"
      type="checkbox"
      :checked="modelValue"
      class="form-check-input"
      :disabled="disabled"
      @change="onChange"
    >
    <label v-if="$slots.default" :for="id" class="form-check-label">
      <slot />
    </label>
  </div>
</template>
