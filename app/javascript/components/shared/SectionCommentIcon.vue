<template>
  <b-button
    v-if="!locked"
    variant="link"
    size="sm"
    type="button"
    :aria-label="ariaLabel"
    :title="tooltipText"
    class="section-comment-icon p-1"
    @click="$emit('open-composer', section)"
  >
    <span data-test="icon-emoji" aria-hidden="true">💬</span>
    <b-badge v-if="pendingCount > 0" data-test="count-badge" variant="primary" class="ml-1">
      {{ pendingCount }}
    </b-badge>
    <span v-if="pendingCount > 0" class="sr-only">{{ pendingCount }} pending comments</span>
  </b-button>
</template>

<script>
import { sectionLabel } from "@/constants/triageVocabulary";

export default {
  name: "SectionCommentIcon",
  props: {
    section: { type: String, required: true },
    pendingCount: { type: Number, default: 0 },
    locked: { type: Boolean, default: false },
  },
  computed: {
    sectionDisplay() {
      return sectionLabel(this.section);
    },
    ariaLabel() {
      const base = `Add comment on ${this.sectionDisplay} section`;
      return this.pendingCount > 0 ? `${base} (${this.pendingCount} pending)` : base;
    },
    tooltipText() {
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
}
.section-comment-icon:focus-visible {
  outline: 2px solid var(--primary, #007bff);
  outline-offset: 2px;
}
</style>
