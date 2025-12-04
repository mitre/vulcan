<script setup lang="ts">
/**
 * SeverityBadge - Displays requirement severity (CAT I/II/III)
 */

import type { RuleSeverity } from '@/types'
import { computed } from 'vue'
import { SEVERITY_MAP } from '@/composables'

interface Props {
  severity: RuleSeverity
}

const props = defineProps<Props>()

const severityColors: Record<RuleSeverity, string> = {
  low: 'info',
  medium: 'warning',
  high: 'danger',
}

// Must be computed to react to prop changes when table rows are reordered
const color = computed(() => severityColors[props.severity] || 'secondary')
const label = computed(() => SEVERITY_MAP[props.severity] || props.severity)
</script>

<template>
  <span :class="`badge bg-${color}`">{{ label }}</span>
</template>
