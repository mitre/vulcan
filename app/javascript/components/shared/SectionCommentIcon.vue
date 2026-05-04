<template>
  <span class="section-comment-icon ml-1" @click.stop="onClick">
    <b-icon
      v-b-tooltip.hover="tooltipText"
      :icon="glyphIcon"
      :class="iconClass"
      :title="tooltipText"
      :data-testid="'section-comment-' + section"
      :aria-label="ariaLabel"
      :tabindex="isInactive ? -1 : 0"
      role="button"
      data-test="icon-glyph"
      @keydown.enter.prevent="onClick"
      @keydown.space.prevent="onClick"
    />
    <b-badge
      v-if="pendingCount > 0"
      data-test="count-badge"
      variant="primary"
      pill
      class="section-comment-icon__badge"
    >
      {{ pendingCount }}
    </b-badge>
    <span v-if="pendingCount > 0" class="sr-only">{{ pendingCount }} pending comments</span>
  </span>
</template>

<script>
import { sectionLabel, commentsClosedTooltip } from "../../constants/triageVocabulary";

export default {
  name: "SectionCommentIcon",
  props: {
    section: { type: String, required: true },
    pendingCount: { type: Number, default: 0 },
    // Never-hide-features: locked + commentsClosed both render a visibly
    // disabled icon with an explanatory tooltip rather than disappearing.
    locked: { type: Boolean, default: false },
    // Component's comment_phase is anything other than 'open'.
    commentsClosed: { type: Boolean, default: false },
    // closed_reason value when commentsClosed is true; drives the
    // tooltip wording so the user knows WHY commenting is unavailable.
    closedReason: { type: String, default: null },
  },
  computed: {
    sectionDisplay() {
      return sectionLabel(this.section);
    },
    isInactive() {
      return this.locked || this.commentsClosed;
    },
    glyphIcon() {
      // Filled glyph when there's prior conversation — quick visual
      // signal without forcing the eye to read the count badge.
      return this.pendingCount > 0 ? "chat-left-text-fill" : "chat-left-text";
    },
    iconClass() {
      if (this.isInactive) return "text-muted opacity-50";
      return this.pendingCount > 0 ? "text-primary clickable" : "text-info clickable";
    },
    ariaLabel() {
      const base = `Add comment on ${this.sectionDisplay} section`;
      // Order matters — narrowest scope first wins.
      if (this.locked) return `${base} (rule is locked)`;
      if (this.commentsClosed) return `${base} (comments are closed for this component)`;
      return this.pendingCount > 0 ? `${base} (${this.pendingCount} pending)` : base;
    },
    tooltipText() {
      // Rule-scope (locked) before component-scope (commentsClosed).
      if (this.locked) return "Rule is locked — comments are closed for this rule";
      if (this.commentsClosed) return commentsClosedTooltip(this.closedReason);
      return this.pendingCount > 0
        ? `${this.pendingCount} pending comments on ${this.sectionDisplay}`
        : `Comment on ${this.sectionDisplay}`;
    },
  },
  methods: {
    onClick() {
      if (this.isInactive) return;
      this.$emit("open-composer", this.section);
    },
  },
};
</script>

<style scoped>
.section-comment-icon {
  position: relative;
  display: inline-flex;
  align-items: center;
}
.section-comment-icon .clickable {
  cursor: pointer;
}
.section-comment-icon .clickable:focus-visible,
.section-comment-icon .clickable:hover {
  outline: 2px solid var(--primary, #007bff);
  outline-offset: 2px;
  border-radius: 2px;
}
/* Tighter pill so the count doesn't dominate next to the lock/info icons. */
.section-comment-icon__badge {
  font-size: 0.65em;
  padding: 0.15em 0.4em;
  margin-left: 0.15em;
}
</style>
