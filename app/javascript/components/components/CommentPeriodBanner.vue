<template>
  <b-alert v-if="bannerKind" show :variant="bannerVariant" role="status" class="mb-3">
    <template v-if="bannerKind === 'open-with-deadline'">
      <strong>Open for comment</strong>
      · {{ daysRemaining }} days remaining
      <span class="text-muted">(closes {{ friendlyDate(component.comment_period_ends_at) }})</span>
    </template>
    <template v-else-if="bannerKind === 'closed-with-past-deadline'">
      <strong>Comments closed on {{ friendlyDate(component.comment_period_ends_at) }}</strong>
    </template>
    <template v-if="bannerKind && component.pending_comment_count != null">
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
export default {
  name: "CommentPeriodBanner",
  props: {
    component: { type: Object, required: true },
  },
  computed: {
    // Banner only renders when the end date is actionable. Two cases
    // qualify: an open component with a future end date (countdown), or
    // a closed component whose recorded end date has already passed
    // (post-deadline notice). Open-without-end-date and open-with-past-
    // end-date are both silent — the inline ComponentCommandBar badge
    // already conveys "Comments: Open" without consuming banner space.
    bannerKind() {
      if (!this.component) return null;
      const endsAt = this.component.comment_period_ends_at;
      if (!endsAt) return null;
      const inFuture = new Date(endsAt).getTime() > Date.now();
      if (this.component.comment_phase === "open" && inFuture) {
        return "open-with-deadline";
      }
      if (this.component.comment_phase === "closed" && !inFuture) {
        return "closed-with-past-deadline";
      }
      return null;
    },
    daysRemaining() {
      if (!this.component.comment_period_ends_at) return null;
      const ms = new Date(this.component.comment_period_ends_at).getTime() - Date.now();
      return Math.ceil(ms / 86400000);
    },
    bannerVariant() {
      return this.bannerKind === "open-with-deadline" ? "info" : "secondary";
    },
  },
  methods: {
    friendlyDate(iso) {
      return iso ? new Date(iso).toLocaleDateString() : "";
    },
  },
};
</script>
