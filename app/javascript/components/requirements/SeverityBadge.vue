<script setup lang="ts">
/**
 * SeverityBadge - Displays requirement severity (CAT I/II/III)
 */

import type { RuleSeverity } from '@/types'
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

const color = severityColors[props.severity] || 'secondary'
const label = SEVERITY_MAP[props.severity] || props.severity
</script>

<template>
  <span :class="`badge bg-${color}`">{{ label }}</span>
</template>
