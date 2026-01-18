<script setup lang="ts">
/**
 * StatusBadge - Displays requirement status with color coding
 */

import type { RuleStatus } from '@/types'

interface Props {
  status: RuleStatus
  short?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  short: false,
})

const statusColors: Record<RuleStatus, string> = {
  'Not Yet Determined': 'secondary',
  'Applicable - Configurable': 'success',
  'Applicable - Inherently Meets': 'info',
  'Applicable - Does Not Meet': 'danger',
  'Not Applicable': 'dark',
}

const shortLabels: Record<RuleStatus, string> = {
  'Not Yet Determined': 'Not Yet',
  'Applicable - Configurable': 'Configurable',
  'Applicable - Inherently Meets': 'Inherently',
  'Applicable - Does Not Meet': 'Does Not Meet',
  'Not Applicable': 'N/A',
}

const color = statusColors[props.status] || 'secondary'
const label = props.short ? shortLabels[props.status] : props.status
</script>

<template>
  <span :class="`badge bg-${color}`">{{ label }}</span>
</template>
