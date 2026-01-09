<script setup lang="ts">
/**
 * LayoutSwitcher - Toggle between Table and Focus modes
 */

type LayoutMode = 'table' | 'focus'

interface Props {
  modelValue: LayoutMode
}

const _props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'update:modelValue', value: LayoutMode): void
}>()

function setMode(mode: LayoutMode) {
  emit('update:modelValue', mode)
}
</script>

<template>
  <div class="layout-switcher btn-group btn-group-sm" role="group">
    <button
      type="button"
      class="btn"
      :class="modelValue === 'table' ? 'btn-primary' : 'btn-outline-primary'"
      title="Table view - for triage"
      @click="setMode('table')"
    >
      <i class="bi bi-table" />
      <span class="ms-1 d-none d-md-inline">Table</span>
    </button>
    <button
      type="button"
      class="btn"
      :class="modelValue === 'focus' ? 'btn-primary' : 'btn-outline-primary'"
      title="Focus view - for authoring"
      @click="setMode('focus')"
    >
      <i class="bi bi-pencil-square" />
      <span class="ms-1 d-none d-md-inline">Focus</span>
    </button>
  </div>
</template>
