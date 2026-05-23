<template>
  <span
    data-test="badge"
    :class="['triage-status', cssClass]"
    :data-triage="status"
    :title="tooltip"
  >
    <span data-test="glyph" aria-hidden="true">{{ glyph }}</span>
    <span data-test="label">{{ displayLabel }}</span>
  </span>
</template>

<script>
import {
  triageDisplay,
  TRIAGE_LABELS,
  TRIAGE_DISA_LABELS,
  ADJUDICATED_LABEL,
  ADJUDICATED_GLYPH,
} from "../../constants/triageVocabulary";

export default {
  name: "TriageStatusBadge",
  props: {
    status: { type: String, required: true },
    adjudicatedAt: { type: [String, Date], default: null },
    duplicateOfId: { type: [Number, String], default: null },
    addressedByRuleId: { type: [Number, String], default: null },
    addressedByRuleName: { type: String, default: null },
  },
  computed: {
    isAdjudicated() {
      return Boolean(this.adjudicatedAt);
    },
    glyph() {
      if (this.isAdjudicated) return ADJUDICATED_GLYPH;
      return triageDisplay(this.status).glyph;
    },
    displayLabel() {
      if (this.status === "duplicate" && this.duplicateOfId) {
        return `Duplicate of #${this.duplicateOfId}`;
      }
      if (this.status === "addressed_by" && (this.addressedByRuleName || this.addressedByRuleId)) {
        return `Addressed by ${this.addressedByRuleName || `#${this.addressedByRuleId}`}`;
      }
      if (this.isAdjudicated) {
        return `${ADJUDICATED_LABEL} (${TRIAGE_LABELS[this.status] || this.status})`;
      }
      return TRIAGE_LABELS[this.status] || this.status;
    },
    tooltip() {
      const disa = TRIAGE_DISA_LABELS[this.status];
      return this.isAdjudicated ? `Adjudicated — ${disa}` : disa;
    },
    cssClass() {
      // Stable DISA-key class hook — never use friendly label as a CSS selector
      const base = `triage-status--${this.status}`;
      return this.isAdjudicated ? `${base} triage-status--adjudicated` : base;
    },
  },
};
</script>

<style scoped>
.triage-status {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.75rem;
  white-space: nowrap;
  padding: 0.2em 0.5em;
  border-radius: 0.25rem;
  font-weight: 600;
}

.triage-status > [data-test="glyph"] {
  font-size: 1em;
  line-height: 1;
}

/* Color comes from data-triage attribute → intermediate CSS vars (Layer 3) */
.triage-status[data-triage] {
  color: var(--status-pill-fg, #fff);
  background-color: var(--status-color);
}

/* Semantic decorations — unique per-status, NOT color */
.triage-status--withdrawn,
.triage-status--duplicate {
  text-decoration: line-through;
}

.triage-status--adjudicated {
  font-style: italic;
}
</style>
