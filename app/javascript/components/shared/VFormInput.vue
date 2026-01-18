<script setup lang="ts">
import { computed, ref } from 'vue'

// Fixed version of BFormInput without the forceUpdateKey that causes focus loss
// Based on bootstrap-vue-next BFormInput but removes the re-render trigger
// Issue: https://github.com/bootstrap-vue-next/bootstrap-vue-next/issues/1704

interface Props {
  id?: string
  modelValue?: string | number
  name?: string
  type?: string
  disabled?: boolean
  placeholder?: string
  required?: boolean
  autocomplete?: string
  readonly?: boolean
  size?: 'sm' | 'lg'
  state?: boolean | null
}

const props = withDefaults(defineProps<Props>(), {
  type: 'text',
  modelValue: '',
  state: null,
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const inputRef = ref<HTMLInputElement | null>(null)

const computedClasses = computed(() => [
  'form-control',
  {
    [`form-control-${props.size}`]: !!props.size,
    'is-valid': props.state === true,
    'is-invalid': props.state === false,
  },
])

function onInput(event: Event) {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.value)
}

defineExpose({
  focus: () => inputRef.value?.focus(),
  blur: () => inputRef.value?.blur(),
})
</script>

<template>
  <input
    :id="id"
    ref="inputRef"
    :value="modelValue"
    :class="computedClasses"
    :name="name"
    :type="type"
    :disabled="disabled"
    :placeholder="placeholder"
    :required="required"
    :autocomplete="autocomplete"
    :readonly="readonly"
    @input="onInput"
  >
</template>
