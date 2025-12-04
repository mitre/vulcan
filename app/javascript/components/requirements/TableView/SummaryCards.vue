<script setup lang="ts">
/**
 * SummaryCards - Quick stats for requirements triage
 *
 * Displays clickable cards showing:
 * - Pending Review: Rules awaiting reviewer action
 * - Changes Requested: Rules needing author attention
 * - Locked: Rules that are locked/approved
 * - Satisfies Others: Rules that satisfy other requirements
 *
 * Click a card to apply filter to the table.
 */

import type { ISlimRule } from '@/types'
import { computed } from 'vue'

interface Props {
  rules: ISlimRule[]
}

interface Emits {
  (e: 'filter', filter: SummaryFilter): void
}

export type SummaryFilter
  = | 'pending_review'
    | 'changes_requested'
    | 'locked'
    | 'satisfies_others'
    | 'satisfied_by'
    | 'recently_changed'
    | null

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

// Computed counts
const pendingReviewCount = computed(() =>
  props.rules.filter(r => r.review_requestor_id != null && !r.locked).length,
)

const changesRequestedCount = computed(() =>
  props.rules.filter(r => r.changes_requested).length,
)

const lockedCount = computed(() =>
  props.rules.filter(r => r.locked).length,
)

const satisfiesOthersCount = computed(() =>
  props.rules.filter(r => (r.satisfies_count ?? 0) > 0).length,
)

const satisfiedByCount = computed(() =>
  props.rules.filter(r => r.is_merged).length,
)

// Card definitions
interface CardDef {
  id: SummaryFilter
  label: string
  count: number
  icon: string
  variant: string
}

const cards = computed<CardDef[]>(() => [
  {
    id: 'pending_review',
    label: 'Pending Review',
    count: pendingReviewCount.value,
    icon: 'bi-clock-history',
    variant: 'warning',
  },
  {
    id: 'changes_requested',
    label: 'Changes Requested',
    count: changesRequestedCount.value,
    icon: 'bi-exclamation-circle',
    variant: 'danger',
  },
  {
    id: 'locked',
    label: 'Locked',
    count: lockedCount.value,
    icon: 'bi-lock-fill',
    variant: 'success',
  },
  {
    id: 'satisfies_others',
    label: 'Satisfies Others',
    count: satisfiesOthersCount.value,
    icon: 'bi-link-45deg',
    variant: 'info',
  },
])

// Filter cards to only show those with counts > 0
const visibleCards = computed(() =>
  cards.value.filter(c => c.count > 0),
)

function handleCardClick(card: CardDef) {
  emit('filter', card.id)
}
</script>

<template>
  <div
    v-if="visibleCards.length > 0"
    class="summary-cards d-flex flex-wrap gap-2 py-2 border-bottom bg-body-tertiary"
  >
    <button
      v-for="card in visibleCards"
      :key="card.id"
      type="button"
      class="summary-card btn btn-sm d-flex align-items-center gap-1"
      :class="`btn-outline-${card.variant}`"
      @click="handleCardClick(card)"
    >
      <i :class="`bi ${card.icon}`" />
      <span class="card-label">{{ card.label }}:</span>
      <span class="fw-bold">{{ card.count }}</span>
    </button>
  </div>
</template>

<style scoped>
/* Full-bleed background: extends edge-to-edge while content stays in container */
.summary-cards {
  container-type: inline-size;
  margin-left: calc(-50vw + 50%);
  margin-right: calc(-50vw + 50%);
  padding-left: calc(50vw - 50%);
  padding-right: calc(50vw - 50%);
}

.summary-card {
  font-size: 0.8125rem;
  padding: 0.25rem 0.5rem;
  transition: transform 0.1s ease;
}

.summary-card:hover {
  transform: translateY(-1px);
}

.summary-card:active {
  transform: translateY(0);
}

/* Container query for narrow containers */
@container (max-width: 400px) {
  .card-label {
    display: none;
  }
}

/* Fallback for older browsers */
@supports not (container-type: inline-size) {
  @media (max-width: 576px) {
    .card-label {
      display: none;
    }
  }
}
</style>
