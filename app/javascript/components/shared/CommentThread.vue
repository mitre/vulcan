<template>
  <div class="comment-thread">
    <div class="d-flex flex-wrap align-items-center" style="gap: 0.5rem">
      <button
        v-if="responsesCount > 0"
        type="button"
        :aria-expanded="String(expanded)"
        :aria-controls="listId"
        class="btn btn-link btn-sm p-0"
        @click="toggle"
      >
        <b-icon :icon="expanded ? 'chevron-down' : 'chevron-right'" aria-hidden="true" />
        {{ replyCountLabel }}
      </button>
      <span v-else-if="showZeroReplies" class="text-muted small">No replies yet</span>
      <b-button
        v-if="canReply"
        size="sm"
        variant="link"
        class="p-0 ml-auto"
        :aria-label="`Reply to comment ${parentReviewId}`"
        @click="$emit('reply', parentReviewId)"
      >
        <b-icon icon="reply" /> Reply
      </b-button>
    </div>

    <div v-if="expanded" :id="listId" class="thread-replies">
      <div v-if="loading" class="text-muted small ml-3"><b-spinner small /> Loading replies…</div>
      <div v-else-if="loadError" class="text-danger small ml-3" role="alert">
        Failed to load replies.
        <b-button size="sm" variant="link" class="p-0" @click="fetch">Retry</b-button>
      </div>
      <div v-else-if="replies.length === 0" class="text-muted small ml-3">No replies yet.</div>
      <div
        v-for="reply in replies"
        v-else
        :key="reply.id"
        class="ml-3 mt-2 pl-3 border-left border-info"
      >
        <p class="mb-0 d-flex flex-wrap align-items-center">
          <strong>{{ reply.commenter_display_name || "—" }}</strong>
          <b-badge v-if="reply.commenter_imported" variant="warning" class="ml-1">
            imported
          </b-badge>
          <small class="text-muted ml-2">{{ relativeTime(reply.created_at) }}</small>
          <b-button
            v-if="canReply"
            size="sm"
            variant="link"
            class="p-0 ml-auto"
            :aria-label="`Reply to comment ${parentReviewId} (in response to reply ${reply.id})`"
            @click="$emit('reply', parentReviewId)"
          >
            <b-icon icon="reply" /> Reply
          </b-button>
        </p>
        <p class="mb-1 white-space-pre-wrap">{{ reply.comment }}</p>
        <ReactionButtons
          v-if="reply.reactions"
          :review-id="reply.id"
          :reactions="reply.reactions"
          :disabled="reactionsDisabled"
          :closed-message="closedMessage"
          @toggle="(kind) => toggleReaction(reply, kind)"
        />
      </div>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import ReactionButtons from "./ReactionButtons.vue";
import AlertMixin from "../../mixins/AlertMixin.vue";
import ReactionToggleMixin from "../../mixins/ReactionToggleMixin.vue";

export default {
  name: "CommentThread",
  components: { ReactionButtons },
  mixins: [AlertMixin, ReactionToggleMixin],
  props: {
    parentReviewId: { type: [Number, String], required: true },
    responsesCount: { type: Number, default: 0 },
    canReply: { type: Boolean, default: true },
    initiallyExpanded: { type: Boolean, default: false },
    showZeroReplies: { type: Boolean, default: false },
    reactionsDisabled: { type: Boolean, default: false },
    closedMessage: {
      type: String,
      default: "Reactions are closed for this component.",
    },
  },
  data() {
    return {
      expanded: this.initiallyExpanded,
      replies: [],
      loaded: false,
      loading: false,
      loadError: false,
      fetchToken: 0,
    };
  },
  computed: {
    listId() {
      return `comment-thread-${this.parentReviewId}`;
    },
    replyCountLabel() {
      const n = this.responsesCount;
      if (this.expanded) return `Hide ${n} ${n === 1 ? "reply" : "replies"}`;
      return `${n} ${n === 1 ? "reply" : "replies"}`;
    },
  },
  watch: {
    parentReviewId() {
      this.replies = [];
      this.loaded = false;
      this.expanded = this.initiallyExpanded;
    },
    initiallyExpanded(val) {
      if (val && !this.loaded && !this.loading) {
        this.expanded = true;
        this.fetch();
      }
    },
    // When the host re-fetches and the count changes (e.g. a reply was
    // posted server-side), our cache is stale — invalidate. If currently
    // expanded, refetch immediately so the visible thread updates.
    responsesCount(newVal, oldVal) {
      if (newVal === oldVal) return;
      this.loaded = false;
      if (this.expanded) this.fetch();
    },
  },
  mounted() {
    if (this.initiallyExpanded && this.responsesCount > 0) {
      this.fetch();
    }
  },
  methods: {
    toggle() {
      this.expanded = !this.expanded;
      if (this.expanded && !this.loaded && !this.loading) {
        this.fetch();
      }
    },
    relativeTime(iso) {
      if (!iso) return "";
      return new Date(iso).toLocaleString();
    },
    async fetch() {
      this.loading = true;
      this.loadError = false;
      const token = ++this.fetchToken;
      try {
        const { data } = await axios.get(`/reviews/${this.parentReviewId}/responses`, {
          headers: { Accept: "application/json" },
        });
        if (token !== this.fetchToken) return;
        this.replies = data.rows || [];
        this.loaded = true;
      } catch {
        if (token !== this.fetchToken) return;
        this.loadError = true;
      } finally {
        if (token === this.fetchToken) this.loading = false;
      }
    },
    refresh() {
      this.loaded = false;
      this.replies = [];
      if (this.expanded) this.fetch();
    },
    toggleReaction(reply, kind) {
      const idx = this.replies.findIndex((r) => r.id === reply.id);
      if (idx < 0) return;
      const prev = { ...reply.reactions };
      const apply = (reactions) => {
        this.$set(this.replies, idx, { ...this.replies[idx], reactions });
      };
      this.submitReactionToggle({ reviewId: reply.id, prev, kind, apply });
    },
  },
};
</script>

<style scoped>
.white-space-pre-wrap {
  white-space: pre-wrap;
}
</style>
