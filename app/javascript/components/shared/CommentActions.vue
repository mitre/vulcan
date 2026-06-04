<template>
  <div class="comment-actions">
    <ReactionButtons
      v-if="reactions"
      :review-id="reviewId"
      :reactions="reactions"
      :disabled="reactionsDisabled"
      @toggle="(kind) => $emit('toggle-reaction', kind)"
    />
    <CommentThread
      :parent-review-id="reviewId"
      :responses-count="responsesCount"
      :can-reply="canReply"
      @reply="(id) => $emit('reply', id)"
    />
  </div>
</template>

<script>
import ReactionButtons from "./ReactionButtons.vue";
import CommentThread from "./CommentThread.vue";

export default {
  name: "CommentActions",
  components: { ReactionButtons, CommentThread },
  props: {
    reviewId: { type: [Number, String], required: true },
    reactions: { type: Object, default: null },
    responsesCount: { type: Number, default: 0 },
    canReply: { type: Boolean, default: true },
    reactionsDisabled: { type: Boolean, default: false },
  },
};
</script>
