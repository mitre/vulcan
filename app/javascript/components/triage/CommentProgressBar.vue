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
    <div data-testid="progress-bar" class="progress-rows mb-1">
      <div
        v-for="entry in barSegments"
        :key="entry.status"
        data-testid="progress-row"
        class="progress-row"
        :data-triage="entry.status"
      >
        <span class="progress-row-label">{{ entry.label }}</span>
        <b-progress class="progress-row-track" :max="100" height="12px">
          <b-progress-bar
            data-testid="progress-segment"
            class="progress-segment"
            :class="'progress-segment--' + entry.status"
            :data-triage="entry.status"
            :value="entry.displayPercent"
            striped
            :title="entry.label + ': ' + entry.count"
          />
        </b-progress>
        <span class="progress-row-count">{{ entry.count }}</span>
      </div>
    </div>
    <small data-testid="progress-summary" class="text-muted d-block mb-3">
      {{ resolvedCount }} of {{ total }} resolved ({{ resolvedPercent }}%)
    </small>
  </div>
</template>

<script>
import { TRIAGE_LABELS, triageLabel } from "../../constants/triageVocabulary";

const RESOLVED_STATUSES = Object.keys(TRIAGE_LABELS).filter((s) => s !== "pending");

export default {
  name: "CommentProgressBar",
  // Component kind from the page/panel root; default keeps tests and
  // isolated mounts green.
  inject: {
    injectedDocumentType: { default: "stig" },
  },
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
          label: triageLabel(status, this.injectedDocumentType),
          count: this.statusCounts[status],
          rawPercent: (this.statusCounts[status] / this.total) * 100,
        }));
    },
    resolvedPills() {
      return this.allPills.filter((e) => e.status !== "pending");
    },
    barSegments() {
      if (this.total === 0) return [];

      // Pending first, matching how the pills read left to right.
      return ["pending", ...RESOLVED_STATUSES]
        .filter((s) => (this.statusCounts[s] || 0) > 0)
        .map((status) => {
          const count = this.statusCounts[status];
          return {
            status,
            label: triageLabel(status, this.injectedDocumentType),
            count,
            displayPercent: (count / this.total) * 100,
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

/* ── Per-status bar rows: label | thin stock striped bar | count ── */
.progress-rows {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.progress-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.progress-row-label {
  flex: 0 0 auto;
  min-width: 11rem;
  font-size: 0.85rem;
}

/* Theme-aware track — Bootstrap's stock light-gray track glares in dark
 * mode. Fills read the same status palette as the pills (one color system;
 * bg-* variant utilities are !important and would fight it, so the bars
 * carry no variant). */
.progress-row-track {
  flex: 1 1 auto;
  background-color: var(--vulcan-bg-light);
}

.progress-segment[data-triage] {
  background-color: var(--status-color);
}

.progress-row-count {
  flex: 0 0 auto;
  min-width: 2.5rem;
  text-align: right;
  font-variant-numeric: tabular-nums;
  font-size: 0.85rem;
}

.progress-separator {
  width: 1px;
  align-self: stretch;
  background-color: var(--vulcan-border-light);
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
</style>
