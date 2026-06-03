<template>
  <div class="bulk-triage-bar" role="region" aria-label="Bulk triage">
    <span class="bulk-triage-bar__count" data-testid="bulk-count"> {{ count }} selected </span>

    <b-form-select
      v-model="triageStatus"
      :options="statusOptions"
      size="sm"
      class="bulk-triage-bar__status"
      data-testid="bulk-status"
      aria-label="Triage status"
    />

    <b-form-textarea
      v-model="response"
      :placeholder="
        responseRequired
          ? 'Response required for Declined…'
          : 'Optional response (copied to each comment)'
      "
      :state="responseRequired && !response.trim() ? false : null"
      rows="1"
      max-rows="4"
      size="sm"
      class="bulk-triage-bar__response"
      data-testid="bulk-response"
      aria-label="Bulk response"
    />

    <b-button
      variant="primary"
      size="sm"
      :disabled="!canApply"
      data-testid="bulk-apply"
      @click="onApply"
    >
      Apply to {{ count }}
    </b-button>

    <b-button
      v-if="canMerge"
      variant="outline-primary"
      size="sm"
      :disabled="count < 2"
      data-testid="bulk-merge"
      title="Merge selected duplicates into one survivor (admin)"
      @click="$emit('merge')"
    >
      Merge…
    </b-button>

    <b-button variant="outline-secondary" size="sm" data-testid="bulk-clear" @click="onClear">
      Clear
    </b-button>
  </div>
</template>

<script>
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";

// Statuses that make sense applied uniformly to many comments. Excludes
// `pending` (the initial state), `withdrawn` (commenter-only), and
// `duplicate`/`addressed_by` (each needs a per-comment target, so they can't
// share one bulk decision).
const BULK_TRIAGE_STATUSES = [
  "concur",
  "concur_with_comment",
  "non_concur",
  "informational",
  "needs_clarification",
];

export default {
  name: "BulkTriageBar",
  props: {
    count: {
      type: Number,
      default: 0,
    },
    canMerge: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      triageStatus: null,
      response: "",
    };
  },
  computed: {
    statusOptions() {
      return [
        { value: null, text: "Triage status…", disabled: true },
        ...BULK_TRIAGE_STATUSES.map((value) => ({ value, text: TRIAGE_LABELS[value] })),
      ];
    },
    responseRequired() {
      return this.triageStatus === "non_concur";
    },
    canApply() {
      if (this.count < 1 || !this.triageStatus) return false;
      return !(this.responseRequired && !this.response.trim());
    },
  },
  methods: {
    onApply() {
      if (!this.canApply) return;
      this.$emit("apply", {
        triage_status: this.triageStatus,
        response_comment: this.response.trim() || null,
      });
    },
    onClear() {
      this.triageStatus = null;
      this.response = "";
      this.$emit("clear");
    },
  },
};
</script>

<style scoped>
.bulk-triage-bar {
  position: sticky;
  bottom: 0;
  z-index: 1020;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: var(--vulcan-component-bg, #fff);
  border-top: 1px solid var(--vulcan-border, #dee2e6);
  box-shadow: var(--vulcan-shadow-lifted);
}

.bulk-triage-bar__count {
  font-weight: 600;
  white-space: nowrap;
}

.bulk-triage-bar__status {
  width: auto;
  min-width: 12rem;
}

.bulk-triage-bar__response {
  flex: 1 1 auto;
}
</style>
