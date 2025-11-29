<script setup lang="ts">
/**
 * StatusProgressBar - Visual progress indicator by status
 */

import type { ISlimRule, RuleStatus } from '@/types'
import { RULE_STATUSES } from '@/composables'

interface Props {
  rules: ISlimRule[]
}

const props = defineProps<Props>()

const statusColors: Record<RuleStatus, string> = {
  'Not Yet Determined': 'secondary',
  'Applicable - Configurable': 'success',
  'Applicable - Inherently Meets': 'info',
  'Applicable - Does Not Meet': 'danger',
  'Not Applicable': 'dark',
}

function getCount(status: RuleStatus): number {
  return props.rules.filter(r => r.status === status).length
}

function getWidth(status: RuleStatus): string {
  if (props.rules.length === 0) return '0%'
  return `${(getCount(status) / props.rules.length) * 100}%`
}
</script>

<template>
  <div class="status-progress d-flex border-bottom" style="height: 6px;">
    <div
      v-for="status in RULE_STATUSES"
      :key="status"
      class="progress-segment"
      :class="`bg-${statusColors[status]}`"
      :style="{ width: getWidth(status) }"
      :title="`${status}: ${getCount(status)}`"
    />
  </div>
</template>

<style scoped>
.progress-segment {
  transition: width 0.3s ease;
}
</style>
