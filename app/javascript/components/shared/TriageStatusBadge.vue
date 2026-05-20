<template>
  <span data-test="badge" :class="['triage-status', cssClass]" :title="tooltip">
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

.triage-status--pending {
  color: #6c757d;
  background-color: rgba(108, 117, 125, 0.1);
}

.triage-status--concur {
  color: #fff;
  background-color: #28a745;
}

.triage-status--concur_with_comment {
  color: #2e7d32;
  background-color: rgba(76, 175, 80, 0.12);
}

.triage-status--non_concur {
  color: #721c24;
  background-color: rgba(220, 53, 69, 0.12);
}

.triage-status--informational {
  color: #856404;
  background-color: rgba(255, 193, 7, 0.15);
}

.triage-status--needs_clarification {
  color: #856404;
  background-color: rgba(255, 193, 7, 0.12);
}

.triage-status--withdrawn,
.triage-status--duplicate {
  color: #6c757d;
  background-color: rgba(108, 117, 125, 0.1);
  text-decoration: line-through;
}

.triage-status--adjudicated {
  font-style: italic;
}
</style>
