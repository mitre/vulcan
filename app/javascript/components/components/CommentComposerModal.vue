<template>
  <b-modal
    id="comment-composer-modal"
    :title="modalTitle"
    size="lg"
    centered
    no-close-on-backdrop
    @hidden="onHidden"
  >
    <p class="mb-2">
      <strong>{{ ruleDisplayedName }}</strong>
      <template v-if="!currentReplyToId">
        ·
        <FilterDropdown
          v-model="section"
          :options="sectionOptions"
          aria-label="Section to comment on"
          class="ml-1 d-inline-block"
        />
      </template>
      <template v-else>
        · Replying to comment #{{ currentReplyToId }}
        <b-button variant="link" size="sm" class="p-0 ml-1" @click="cancelReply">
          (cancel)
        </b-button>
      </template>
    </p>

    <CommentDedupBanner
      v-if="!currentReplyToId"
      :component-id="componentId"
      :rule-id="ruleId"
      :section="section"
      @reply="onReplyClicked"
    />

    <b-form-group :description="charCount" class="mb-0">
      <b-form-textarea
        v-model="commentText"
        rows="4"
        :placeholder="placeholder"
        :state="textState"
        aria-label="Comment text"
      />
      <b-form-invalid-feedback v-if="textState === false" role="alert">
        Comment cannot be empty.
      </b-form-invalid-feedback>
    </b-form-group>

    <template #modal-footer="{ cancel }">
      <b-button variant="secondary" @click="cancel()">Cancel</b-button>
      <b-button variant="primary" :disabled="!canSubmit" @click="submit"> Submit </b-button>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import AlertMixin from "../../mixins/AlertMixin.vue";
import FormMixin from "../../mixins/FormMixin.vue";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import CommentDedupBanner from "./CommentDedupBanner.vue";
import FilterDropdown from "../shared/FilterDropdown.vue";

const COMMENT_MAX = 4000;

export default {
  name: "CommentComposerModal",
  components: { CommentDedupBanner, FilterDropdown },
  // FormMixin sets axios.defaults['X-CSRF-Token'] on mount. Required because
  // each esbuild pack has its own axios singleton (bundle isolation) — the
  // navbar pack's FormMixin doesn't reach the consuming pack. Without this
  // the modal's POST /rules/:id/reviews call would 422 on CSRF in a pack
  // that lacks pack-level CSRF setup.
  mixins: [AlertMixin, FormMixin],
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], required: true },
    ruleDisplayedName: { type: String, default: "" },
    initialSection: { type: String, default: null },
    replyToReviewId: { type: [Number, String], default: null },
  },
  data() {
    return {
      // Mirror the props as internal state so the modal can update them
      // when the user picks a different section in the dropdown OR clicks
      // [Reply] in the dedup banner. Watchers below sync prop changes
      // back into these (so a click on a different SectionCommentIcon
      // updates the pre-selected section without remounting).
      section: this.initialSection,
      currentReplyToId: this.replyToReviewId,
      commentText: "",
    };
  },
  computed: {
    sectionOptions() {
      return [
        { value: null, text: "(general)" },
        ...Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text })),
      ];
    },
    modalTitle() {
      return this.currentReplyToId ? "Reply to comment" : "New comment";
    },
    placeholder() {
      return this.currentReplyToId ? "Reply to this comment..." : "Type your comment...";
    },
    textState() {
      if (!this.commentText) return null;
      return this.commentText.trim().length === 0 ? false : null;
    },
    charCount() {
      return `${this.commentText.length} / ${COMMENT_MAX} characters`;
    },
    canSubmit() {
      return this.commentText.trim().length > 0 && this.commentText.length <= COMMENT_MAX;
    },
  },
  watch: {
    // Vue 2 data() runs once at mount, so a parent that just updates
    // :initial-section won't re-init this.section. Sync the prop into
    // local state explicitly. Same for replyToReviewId.
    initialSection(newVal) {
      this.section = newVal;
    },
    replyToReviewId(newVal) {
      this.currentReplyToId = newVal;
    },
  },
  methods: {
    async submit() {
      const payload = {
        review: {
          action: "comment",
          comment: this.commentText.trim(),
          component_id: this.componentId,
        },
      };
      if (this.section) payload.review.section = this.section;
      if (this.currentReplyToId) {
        payload.review.responding_to_review_id = this.currentReplyToId;
      }

      try {
        const res = await axios.post(`/rules/${this.ruleId}/reviews`, payload);
        // confirm to the commenter that the
        // post landed. ReviewsController#create returns the canonical
        // toast object; AlertMixin renders it identically to the other
        // success-toast endpoints in the app.
        this.alertOrNotifyResponse(res);
        this.$emit("posted");
        this.$bvModal.hide("comment-composer-modal");
        this.commentText = "";
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    onHidden() {
      this.commentText = "";
      // Reset reply mode on close so the next open is a fresh new-comment
      // (the parent decides via :reply-to-review-id when explicitly replying).
      this.currentReplyToId = this.replyToReviewId;
      this.$emit("hidden");
    },
    // CommentDedupBanner [Reply] click handler — switches the modal into
    // reply mode without closing/reopening. Section dropdown hides because
    // reply inherits the parent comment's section anyway.
    onReplyClicked(reviewId) {
      this.currentReplyToId = reviewId;
    },
    cancelReply() {
      this.currentReplyToId = null;
    },
  },
};
</script>
