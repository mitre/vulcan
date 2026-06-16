<template>
  <span class="section-comment-icon">
    <b-button
      data-test="add-comment-btn"
      variant="outline-primary"
      size="sm"
      class="section-comment-icon__btn"
      :disabled="isInactive"
      :title="isInactive ? closedTooltip : 'Add comment on ' + sectionDisplay"
      @click.stop="onAdd"
    >
      <b-icon icon="pencil-square" class="mr-1" />Add Comment
    </b-button>
    <b-button
      v-if="openCount > 0"
      data-test="view-comments-link"
      variant="outline-secondary"
      size="sm"
      class="section-comment-icon__btn"
      :title="'View ' + openCount + ' comments on ' + sectionDisplay"
      @click.stop="$emit('view-comments', section)"
    >
      <b-icon icon="eye" class="mr-1" />View {{ openCount }}
      {{ openCount === 1 ? "Comment" : "Comments" }}
    </b-button>
  </span>
</template>

<script>
import { sectionLabel, commentsClosedTooltip } from "../../constants/triageVocabulary";

export default {
  name: "SectionCommentIcon",
  props: {
    section: { type: String, required: true },
    openCount: { type: Number, default: 0 },
    locked: { type: Boolean, default: false },
    commentsClosed: { type: Boolean, default: false },
    closedReason: { type: String, default: null },
  },
  computed: {
    sectionDisplay() {
      return sectionLabel(this.section);
    },
    isInactive() {
      return this.commentsClosed;
    },
    closedTooltip() {
      if (this.locked) return "Rule is locked — editing disabled, comments still accepted";
      if (this.commentsClosed) return commentsClosedTooltip(this.closedReason);
      return null;
    },
  },
  methods: {
    onAdd() {
      if (this.isInactive) return;
      this.$emit("open-composer", this.section);
    },
  },
};
</script>

<style scoped>
.section-comment-icon {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
}
.section-comment-icon__btn {
  font-size: var(--vulcan-action-btn-font-size, 0.75rem);
  padding: 0.2rem 0.5rem;
  line-height: 1.5;
  white-space: nowrap;
}
</style>
