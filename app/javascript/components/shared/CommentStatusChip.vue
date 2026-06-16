<template>
  <b-button
    v-if="chipKind"
    v-b-tooltip.hover
    title="Open comments panel"
    :variant="chipVariant"
    size="sm"
    data-testid="comment-status-chip"
    @click="$emit('open-comments-panel')"
  >
    <b-icon :icon="chipIcon" />
    {{ chipLabel }}
    <b-badge v-if="component.pending_comment_count > 0" variant="primary" pill class="ml-1">
      {{ component.pending_comment_count }}
    </b-badge>
  </b-button>
</template>

<script>
export default {
  name: "CommentStatusChip",
  props: {
    component: { type: Object, required: true },
  },
  computed: {
    chipKind() {
      if (!this.component) return null;
      const endsAt = this.component.comment_period_ends_at;
      if (!endsAt) return null;
      const inFuture = new Date(endsAt).getTime() > Date.now();
      if (this.component.comment_phase === "open" && inFuture) return "open";
      if (this.component.comment_phase === "closed" && !inFuture) return "closed";
      return null;
    },
    daysRemaining() {
      if (!this.component.comment_period_ends_at) return null;
      const ms = new Date(this.component.comment_period_ends_at).getTime() - Date.now();
      return Math.ceil(ms / 86400000);
    },
    chipLabel() {
      if (this.chipKind === "open") {
        const n = this.daysRemaining;
        return `${n} ${n === 1 ? "day" : "days"} left`;
      }
      return "Closed";
    },
    chipVariant() {
      return this.chipKind === "open" ? "outline-info" : "outline-secondary";
    },
    chipIcon() {
      return this.chipKind === "open" ? "chat-left-text" : "chat-left";
    },
  },
};
</script>
