<template>
  <div v-if="total > 0" class="comment-progress-bar">
    <div class="progress-pills mb-4">
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
        data-triage="pending"
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
        :data-triage="entry.status"
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
        :data-triage="entry.status"
        :style="{ width: entry.displayWidth }"
        :title="entry.label + ': ' + entry.count"
      />
    </div>
    <small data-testid="progress-summary" class="text-muted d-block mb-3">
      {{ resolvedCount }} of {{ total }} resolved ({{ resolvedPercent }}%)
    </small>
  </div>
</template>

<script>
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";

const RESOLVED_STATUSES = Object.keys(TRIAGE_LABELS).filter((s) => s !== "pending");

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
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.progress-separator {
  width: 1px;
  align-self: stretch;
  background-color: var(--vulcan-border-light);
}

.progress-bar-track {
  height: 10px;
  background-color: var(--vulcan-bg-light);
  border-radius: 2px;
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
    0 0 0 2px var(--vulcan-body-bg, white),
    0 0 0 4px currentColor;
}

/* "All" pill is the only one without a triage status */
.progress-pill--all {
  background-color: var(--vulcan-component-bg-alt, var(--vulcan-dark));
  color: var(--vulcan-emphasis-color, white);
  border: 1px solid var(--vulcan-border-color, transparent);
}

/* Color from data-triage → intermediate CSS vars (Layer 3) */
.progress-pill[data-triage] {
  background-color: var(--status-color);
  color: var(--status-pill-fg, #fff);
}

/* ── Bar segment colors — ONE rule via intermediate variable ── */
.progress-segment[data-triage] {
  background-color: var(--status-color);
}
</style>
