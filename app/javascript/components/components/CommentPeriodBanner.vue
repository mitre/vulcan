<template>
  <b-alert
    v-if="component && component.comment_phase !== 'draft'"
    show
    :variant="bannerVariant"
    role="status"
    class="mb-3"
  >
    <strong>{{ phaseLabel }}</strong>
    <template v-if="daysRemaining !== null">
      · {{ daysRemaining }} days remaining
      <span class="text-muted">(closes {{ friendlyDate(component.comment_period_ends_at) }})</span>
    </template>
    <template v-if="component.pending_comment_count != null">
      <br />
      {{ component.pending_comment_count }} pending comments awaiting triage
      <b-button
        variant="outline-primary"
        size="sm"
        class="ml-2"
        data-testid="banner-open-comments-panel"
        @click="$emit('open-comments-panel')"
      >
        Open Comments panel <b-icon icon="arrow-right-short" />
      </b-button>
    </template>
  </b-alert>
</template>

<script>
import { COMMENT_PHASE_LABELS } from "../../constants/triageVocabulary";

export default {
  name: "CommentPeriodBanner",
  props: {
    component: { type: Object, required: true },
  },
  computed: {
    phaseLabel() {
      return COMMENT_PHASE_LABELS[this.component.comment_phase] || this.component.comment_phase;
    },
    daysRemaining() {
      if (this.component.comment_phase !== "open" || !this.component.comment_period_ends_at) {
        return null;
      }
      const ms = new Date(this.component.comment_period_ends_at).getTime() - Date.now();
      return Math.ceil(ms / 86400000);
    },
    bannerVariant() {
      if (this.component.comment_phase === "open") return "info";
      if (this.component.comment_phase === "adjudication") return "warning";
      return "secondary";
    },
  },
  methods: {
    friendlyDate(iso) {
      return iso ? new Date(iso).toLocaleDateString() : "";
    },
  },
};
</script>
