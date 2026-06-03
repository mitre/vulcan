<template>
  <div class="bulk-triage-bar" role="region" aria-label="Bulk triage">
    <span class="bulk-triage-bar__count" data-testid="bulk-count">
      <b-icon icon="check2-square" class="mr-1" />
      {{ count }} selected
    </span>

    <FilterDropdown
      :value="triageStatus"
      :options="statusOptions"
      size="sm"
      variant="outline-secondary"
      placeholder="Triage status…"
      aria-label="Triage status"
      data-testid="bulk-status"
      @input="triageStatus = $event"
    />

    <b-form-textarea
      v-model="response"
      :placeholder="responseRequired ? 'Response required…' : 'Optional response'"
      :state="responseRequired && !response.trim() ? false : null"
      rows="1"
      max-rows="3"
      size="sm"
      class="bulk-triage-bar__response"
      data-testid="bulk-response"
      aria-label="Bulk response"
    />

    <b-button
      variant="outline-primary"
      size="sm"
      class="ml-auto"
      :disabled="!canApply"
      data-testid="bulk-apply"
      @click="onApply"
    >
      Apply
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
      Merge
    </b-button>

    <b-button variant="outline-primary" size="sm" data-testid="bulk-clear" @click="onClear">
      Clear
    </b-button>
  </div>
</template>

<script>
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";
import FilterDropdown from "../shared/FilterDropdown.vue";

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
  components: { FilterDropdown },
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
      return BULK_TRIAGE_STATUSES.map((value) => ({ value, text: TRIAGE_LABELS[value] }));
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
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 1rem;
  background: var(--vulcan-component-bg);
  border-top: 1px solid var(--vulcan-border-color);
  box-shadow: var(--vulcan-shadow-lifted);
}

.bulk-triage-bar__count {
  font-weight: 600;
  white-space: nowrap;
}

.bulk-triage-bar__response {
  flex: 1 1 0;
  min-width: 8rem;
  background-color: var(--vulcan-tertiary-bg) !important;
}
</style>
