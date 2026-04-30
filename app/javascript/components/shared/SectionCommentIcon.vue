<template>
  <b-button
    variant="link"
    size="sm"
    type="button"
    :disabled="isInactive"
    :aria-label="ariaLabel"
    :title="tooltipText"
    class="section-comment-icon p-1"
    :class="{ 'section-comment-icon--inactive': isInactive }"
    @click="$emit('open-composer', section)"
  >
    <b-icon data-test="icon-glyph" aria-hidden="true" icon="chat-left-text" />
    <b-badge v-if="pendingCount > 0" data-test="count-badge" variant="primary" class="ml-1">
      {{ pendingCount }}
    </b-badge>
    <span v-if="pendingCount > 0" class="sr-only">{{ pendingCount }} pending comments</span>
  </b-button>
</template>

<script>
import { sectionLabel } from "../../constants/triageVocabulary";

export default {
  name: "SectionCommentIcon",
  props: {
    section: { type: String, required: true },
    pendingCount: { type: Number, default: 0 },
    // locked HIDES the icon entirely — the rule is frozen, no commentary.
    locked: { type: Boolean, default: false },
    // disabled SHOWS the icon but inactive — typically used while a rule
    // is still in "Not Yet Determined" status (not ready for commenter
    // review). Discoverable for commenters via the explanatory tooltip.
    disabled: { type: Boolean, default: false },
  },
  computed: {
    sectionDisplay() {
      return sectionLabel(this.section);
    },
    isInactive() {
      return this.locked || this.disabled;
    },
    ariaLabel() {
      const base = `Add comment on ${this.sectionDisplay} section`;
      if (this.locked) return `${base} (rule is locked)`;
      if (this.disabled) return `${base} (set rule status before commenting)`;
      return this.pendingCount > 0 ? `${base} (${this.pendingCount} pending)` : base;
    },
    tooltipText() {
      // Locked is the more specific reason — show it first.
      if (this.locked) {
        return "Rule is locked — comments are closed for this rule";
      }
      if (this.disabled) {
        return "Set the rule status before commenting (rule is Not Yet Determined)";
      }
      return this.pendingCount > 0
        ? `${this.pendingCount} pending comments on ${this.sectionDisplay}`
        : `Comment on ${this.sectionDisplay}`;
    },
  },
};
</script>

<style scoped>
.section-comment-icon {
  text-decoration: none;
  /* Active state — Bootstrap link blue (default for variant="link") */
}
.section-comment-icon:focus-visible {
  outline: 2px solid var(--primary, #007bff);
  outline-offset: 2px;
}
/* Inactive state — locked OR rule status is Not Yet Determined.
   Visible for discoverability (don't hide features) but greyed
   so the available-for-action state is unambiguous. */
.section-comment-icon--inactive {
  color: var(--secondary, #6c757d) !important;
  opacity: 0.55;
  cursor: not-allowed;
}
.section-comment-icon--inactive .badge {
  opacity: 0.7;
}
</style>
