<script setup lang="ts">
/**
 * ReviewStatus - Displays rule review status as a badge
 *
 * States:
 * - Pending Review: Yellow badge with requestor name
 * - Changes Requested: Red badge
 * - Approved/Locked: Green badge
 * - None: Empty/dash
 */

import { computed } from 'vue'

interface Props {
  reviewRequestorId?: number | null
  changesRequested?: boolean
  locked?: boolean
  reviewRequestorName?: string
}

const props = withDefaults(defineProps<Props>(), {
  reviewRequestorId: null,
  changesRequested: false,
  locked: false,
  reviewRequestorName: undefined,
})

type ReviewState = 'pending' | 'changes_requested' | 'approved' | 'none'

const reviewState = computed<ReviewState>(() => {
  if (props.locked) return 'approved'
  if (props.changesRequested) return 'changes_requested'
  if (props.reviewRequestorId != null) return 'pending'
  return 'none'
})

const badgeConfig = computed(() => {
  switch (reviewState.value) {
    case 'pending':
      return {
        class: 'bg-warning text-dark',
        icon: 'bi-clock-history',
        label: 'Pending',
        title: props.reviewRequestorName
          ? `Pending review (requested by ${props.reviewRequestorName})`
          : 'Pending review',
      }
    case 'changes_requested':
      return {
        class: 'bg-danger',
        icon: 'bi-exclamation-circle',
        label: 'Changes',
        title: 'Changes requested - needs author attention',
      }
    case 'approved':
      return {
        class: 'bg-success',
        icon: 'bi-check-circle',
        label: 'Approved',
        title: 'Approved and locked',
      }
    default:
      return null
  }
})
</script>

<template>
  <span v-if="badgeConfig" class="review-status">
    <span
      class="badge d-inline-flex align-items-center gap-1"
      :class="badgeConfig.class"
      :title="badgeConfig.title"
    >
      <i class="bi" :class="badgeConfig.icon" />
      <span class="badge-label">{{ badgeConfig.label }}</span>
    </span>
  </span>
  <span v-else class="text-muted">—</span>
</template>

<style scoped>
.review-status .badge {
  font-size: 0.7rem;
  padding: 0.2em 0.4em;
}

.review-status .bi {
  font-size: 0.75rem;
}

/* Container query for narrow columns */
.review-status {
  container-type: inline-size;
}

@container (max-width: 80px) {
  .badge-label {
    display: none;
  }
}

/* Fallback for older browsers */
@supports not (container-type: inline-size) {
  @media (max-width: 768px) {
    .badge-label {
      display: none;
    }
  }
}
</style>
