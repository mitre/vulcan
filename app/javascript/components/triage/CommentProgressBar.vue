<template>
  <div v-if="total > 0" class="comment-progress-bar">
    <div class="progress-pills mb-1">
      <span
        data-testid="status-pill"
        class="badge progress-pill progress-pill--all"
        :class="{ 'progress-pill--active': activeFilter === 'all' }"
        role="button"
        tabindex="0"
        @click="onPillClick('all')"
        @keydown.enter="onPillClick('all')"
        @keydown.space.prevent="onPillClick('all')"
      >
        All: {{ total }}
      </span>
      <span
        v-if="pendingCount > 0"
        data-testid="status-pill"
        class="badge progress-pill progress-pill--pending"
        :class="{ 'progress-pill--active': activeFilter === 'pending' }"
        role="button"
        tabindex="0"
        @click="onPillClick('pending')"
        @keydown.enter="onPillClick('pending')"
        @keydown.space.prevent="onPillClick('pending')"
      >
        Pending: {{ pendingCount }}
      </span>
      <span v-if="resolvedPills.length" class="progress-separator" aria-hidden="true" />
      <span
        v-for="entry in resolvedPills"
        :key="entry.status"
        data-testid="status-pill"
        class="badge progress-pill"
        :class="[
          'progress-pill--' + entry.status,
          { 'progress-pill--active': activeFilter === entry.status },
        ]"
        role="button"
        tabindex="0"
        @click="onPillClick(entry.status)"
        @keydown.enter="onPillClick(entry.status)"
        @keydown.space.prevent="onPillClick(entry.status)"
      >
        {{ entry.label }}: {{ entry.count }}
      </span>
    </div>
    <div data-testid="progress-bar" class="progress-bar-track d-flex rounded overflow-hidden mb-1">
      <div
        v-for="entry in barSegments"
        :key="entry.status"
        data-testid="progress-segment"
        class="progress-segment"
        :class="'progress-segment--' + entry.status"
        :style="{ width: entry.displayWidth }"
        :title="entry.label + ': ' + entry.count"
      />
    </div>
    <small data-testid="progress-summary" class="text-muted">
      {{ resolvedCount }} of {{ total }} resolved ({{ resolvedPercent }}%)
    </small>
  </div>
</template>

<script>
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";

const RESOLVED_STATUSES = [
  "concur",
  "concur_with_comment",
  "non_concur",
  "informational",
  "needs_clarification",
  "duplicate",
  "withdrawn",
];

const MIN_SEGMENT_PERCENT = 2;

export default {
  name: "CommentProgressBar",
  props: {
    statusCounts: { type: Object, required: true },
    activeFilter: { type: String, default: null },
  },
  computed: {
    total() {
      return Object.values(this.statusCounts).reduce((sum, n) => sum + n, 0);
    },
    pendingCount() {
      return this.statusCounts.pending || 0;
    },
    resolvedCount() {
      return this.total - this.pendingCount;
    },
    resolvedPercent() {
      if (this.total === 0) return 0;
      return Math.round((this.resolvedCount / this.total) * 100);
    },
    allPills() {
      if (this.total === 0) return [];
      const statuses = ["pending", ...RESOLVED_STATUSES];
      return statuses
        .filter((s) => (this.statusCounts[s] || 0) > 0)
        .map((status) => ({
          status,
          label: TRIAGE_LABELS[status] || status,
          count: this.statusCounts[status],
          rawPercent: (this.statusCounts[status] / this.total) * 100,
        }));
    },
    resolvedPills() {
      return this.allPills.filter((e) => e.status !== "pending");
    },
    barSegments() {
      if (this.total === 0) return [];

      const entries = RESOLVED_STATUSES.concat(["pending"])
        .filter((s) => (this.statusCounts[s] || 0) > 0)
        .map((status) => {
          const count = this.statusCounts[status];
          const rawPercent = (count / this.total) * 100;
          return {
            status,
            label: TRIAGE_LABELS[status] || status,
            count,
            rawPercent,
          };
        });

      const boosted = entries.filter((e) => e.rawPercent < MIN_SEGMENT_PERCENT);
      const boostTotal = boosted.reduce((sum, e) => sum + (MIN_SEGMENT_PERCENT - e.rawPercent), 0);
      const unboosted = entries.filter((e) => e.rawPercent >= MIN_SEGMENT_PERCENT);
      const unboostedTotal = unboosted.reduce((sum, e) => sum + e.rawPercent, 0);

      return entries.map((e) => {
        let displayPercent;
        if (e.rawPercent < MIN_SEGMENT_PERCENT) {
          displayPercent = MIN_SEGMENT_PERCENT;
        } else if (unboostedTotal > 0 && boostTotal > 0) {
          displayPercent = e.rawPercent - (e.rawPercent / unboostedTotal) * boostTotal;
        } else {
          displayPercent = e.rawPercent;
        }
        return {
          ...e,
          displayWidth: displayPercent.toFixed(1) + "%",
        };
      });
    },
  },
  methods: {
    onPillClick(status) {
      this.$emit("filter", this.activeFilter === status ? "all" : status);
    },
  },
};
</script>

<style scoped>
.progress-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.progress-separator {
  width: 1px;
  align-self: stretch;
  background-color: #ced4da;
}

.progress-bar-track {
  height: 8px;
  background-color: #e9ecef;
}

.progress-segment {
  min-width: 4px;
}

/* ── Pill colors (text on colored background) ── */
.progress-pill {
  font-size: 0.8rem;
  font-weight: 500;
  padding: 0.4em 0.65em;
  border-radius: 0.25rem;
  line-height: 1.4;
  cursor: pointer;
  transition: box-shadow 0.15s ease;
}

.progress-pill:hover {
  opacity: 0.85;
}

.progress-pill--active {
  box-shadow:
    0 0 0 2px white,
    0 0 0 4px currentColor;
}

.progress-pill--all {
  background-color: #343a40;
  color: white;
}

.progress-pill--pending {
  background-color: var(--triage-pending);
  color: white;
}
.progress-pill--concur {
  background-color: var(--triage-concur);
  color: white;
}
.progress-pill--concur_with_comment {
  background-color: var(--triage-concur-with-comment);
  color: white;
}
.progress-pill--non_concur {
  background-color: var(--triage-non-concur);
  color: white;
}
.progress-pill--informational,
.progress-pill--needs_clarification {
  background-color: var(--triage-informational);
  color: #212529;
}
.progress-pill--duplicate {
  background-color: var(--triage-duplicate);
  color: white;
}
.progress-pill--withdrawn {
  background-color: var(--triage-withdrawn);
  color: white;
}

/* ── Bar segment colors (match pills via same CSS vars) ── */
.progress-segment--pending {
  background-color: var(--triage-pending);
}
.progress-segment--concur {
  background-color: var(--triage-concur);
}
.progress-segment--concur_with_comment {
  background-color: var(--triage-concur-with-comment);
}
.progress-segment--non_concur {
  background-color: var(--triage-non-concur);
}
.progress-segment--informational,
.progress-segment--needs_clarification {
  background-color: var(--triage-informational);
}
.progress-segment--duplicate {
  background-color: var(--triage-duplicate);
}
.progress-segment--withdrawn {
  background-color: var(--triage-withdrawn);
}
</style>
