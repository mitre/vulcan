<template>
  <b-modal
    id="bulk-triage-target-modal"
    :title="title"
    centered
    size="lg"
    no-close-on-backdrop
    @ok="confirm"
    @hidden="onHidden"
  >
    <p class="mb-3 small text-muted" data-testid="bulk-target-explainer">
      {{ explainer }}
    </p>
    <CanonicalCommentPicker
      v-if="targetType === 'duplicate' && componentId"
      :component-id="componentId"
      :exclude-review-ids="excludeReviewIds"
      :selected-review-id="targetId"
      @selected="targetId = $event"
    />
    <RulePicker
      v-else-if="targetType === 'addressed_by' && componentId"
      :component-id="componentId"
      :exclude-rule-ids="excludeRuleIds"
      :selected-rule-id="targetId"
      @selected="targetId = $event"
    />
    <template #modal-footer="{ cancel, ok }">
      <b-button @click="cancel()">Cancel</b-button>
      <b-button
        variant="primary"
        :disabled="!canConfirm"
        data-testid="bulk-target-confirm"
        @click="ok()"
      >
        Apply to {{ count }} comment{{ count === 1 ? "" : "s" }}
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import CanonicalCommentPicker from "../components/CanonicalCommentPicker.vue";
import RulePicker from "../components/RulePicker.vue";
import { ruleTerm } from "../../constants/terminology";

// Target modal for bulk duplicate/addressed_by (the Merge-modal sibling
// shape): the bar's Apply opens it, ONE shared target applies to every
// selected comment. The canonical picker excludes the whole selection —
// the server rejects a canonical among the selected comments (the
// pick-from-within flow is Merge). The rule picker excludes the selected
// comments' own rules, matching the per-comment picker's posture.
export default {
  name: "BulkTriageTargetModal",
  components: { CanonicalCommentPicker, RulePicker },
  // Component kind from the triage root; default keeps tests and isolated
  // mounts green.
  inject: {
    injectedDocumentType: { default: "stig" },
  },
  props: {
    targetType: {
      type: String,
      default: null,
      validator: (v) => v === null || ["duplicate", "addressed_by"].includes(v),
    },
    componentId: { type: [Number, String], default: null },
    excludeReviewIds: { type: Array, default: () => [] },
    excludeRuleIds: { type: Array, default: () => [] },
    count: { type: Number, default: 0 },
  },
  data() {
    return { targetId: null };
  },
  computed: {
    targetNoun() {
      return ruleTerm(this.injectedDocumentType).singular.toLowerCase();
    },
    title() {
      return this.targetType === "duplicate"
        ? "Mark as duplicate — pick the canonical comment"
        : `Addressed by — pick the target ${this.targetNoun}`;
    },
    explainer() {
      const noun = `comment${this.count === 1 ? "" : "s"}`;
      return this.targetType === "duplicate"
        ? `The ${this.count} selected ${noun} will be marked as duplicates of the canonical comment you pick. The canonical itself is not changed.`
        : `The ${this.count} selected ${noun} will be marked as addressed by the ${this.targetNoun} you pick.`;
    },
    canConfirm() {
      return this.targetId != null;
    },
  },
  methods: {
    confirm() {
      if (!this.canConfirm) return;
      this.$emit("confirm", this.targetId);
    },
    onHidden() {
      this.targetId = null;
      this.$emit("hidden");
    },
  },
};
</script>
