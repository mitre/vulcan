/**
 * useRequirementProgress Composable
 *
 * Tracks bucketing/adjudication progress for requirements.
 * Shows how many requirements have been moved from "Not Yet Determined"
 * to a final status.
 *
 * Usage:
 *   const {
 *     total, determined, remaining, percentComplete,
 *     byStatus, progressSummary
 *   } = useRequirementProgress()
 */

import { computed } from 'vue'
import { useRulesStore } from '@/stores'
import type { RuleStatusType } from '@/config'

export interface StatusCount {
  status: RuleStatusType
  count: number
  label: string
  color: string
}

export interface UseRequirementProgressReturn {
  // Counts
  total: ReturnType<typeof computed<number>>
  determined: ReturnType<typeof computed<number>>
  remaining: ReturnType<typeof computed<number>>
  percentComplete: ReturnType<typeof computed<number>>

  // Breakdown by status
  byStatus: ReturnType<typeof computed<StatusCount[]>>

  // Summary string for display
  progressSummary: ReturnType<typeof computed<string>>

  // Is all work complete?
  isComplete: ReturnType<typeof computed<boolean>>
}

// Status colors for UI
const STATUS_COLORS: Record<string, string> = {
  'Not Yet Determined': '#6c757d', // gray
  'Applicable - Configurable': '#198754', // green
  'Applicable - Inherently Meets': '#0dcaf0', // cyan
  'Applicable - Does Not Meet': '#dc3545', // red
  'Not Applicable': '#ffc107', // yellow
}

// Short labels for display
const STATUS_LABELS: Record<string, string> = {
  'Not Yet Determined': 'Undetermined',
  'Applicable - Configurable': 'Configurable',
  'Applicable - Inherently Meets': 'Inherently Meets',
  'Applicable - Does Not Meet': 'Does Not Meet',
  'Not Applicable': 'Not Applicable',
}

/**
 * Composable for tracking requirement progress
 */
export function useRequirementProgress(): UseRequirementProgressReturn {
  const rulesStore = useRulesStore()

  // Total requirements
  const total = computed(() => rulesStore.rules.length)

  // Count by status
  const byStatus = computed<StatusCount[]>(() => {
    const counts: Record<string, number> = {}

    for (const rule of rulesStore.rules) {
      const status = rule.status || 'Not Yet Determined'
      counts[status] = (counts[status] || 0) + 1
    }

    return Object.entries(counts).map(([status, count]) => ({
      status: status as RuleStatusType,
      count,
      label: STATUS_LABELS[status] || status,
      color: STATUS_COLORS[status] || '#6c757d',
    }))
  })

  // Determined = not "Not Yet Determined"
  const determined = computed(() => {
    return rulesStore.rules.filter(r => r.status !== 'Not Yet Determined').length
  })

  // Remaining to be bucketed
  const remaining = computed(() => {
    return rulesStore.rules.filter(r => r.status === 'Not Yet Determined').length
  })

  // Percentage complete
  const percentComplete = computed(() => {
    if (total.value === 0) return 0
    return Math.round((determined.value / total.value) * 100)
  })

  // Summary string
  const progressSummary = computed(() => {
    return `${determined.value} / ${total.value} Requirements Adjudicated`
  })

  // Is complete?
  const isComplete = computed(() => remaining.value === 0 && total.value > 0)

  return {
    total,
    determined,
    remaining,
    percentComplete,
    byStatus,
    progressSummary,
    isComplete,
  }
}
