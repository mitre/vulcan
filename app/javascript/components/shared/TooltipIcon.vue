<script setup lang="ts">
/**
 * TooltipIcon - Reusable info icon with Bootstrap-Vue-Next tooltip
 *
 * Usage:
 *   <TooltipIcon :content="tooltips.status" />
 *   <TooltipIcon content="Some help text" html />
 */
interface Props {
  content: string | null | undefined
  html?: boolean
  placement?: 'top' | 'bottom' | 'left' | 'right'
  icon?: string
}

const props = withDefaults(defineProps<Props>(), {
  html: true,
  placement: 'top',
  icon: 'bi-info-circle',
})
</script>

<template>
  <i
    v-if="content"
    v-b-tooltip:[placement].hover="{ html, title: content }"
    class="bi" :class="[icon]"
    aria-hidden="true"
  />
</template>
