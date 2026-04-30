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
      <template v-if="!replyToReviewId">
        ·
        <FilterDropdown
          v-model="section"
          :options="sectionOptions"
          aria-label="Section to comment on"
          class="ml-1 d-inline-block"
        />
      </template>
      <template v-else> · Replying to comment #{{ replyToReviewId }} </template>
    </p>

    <CommentDedupBanner
      v-if="!replyToReviewId"
      :component-id="componentId"
      :rule-id="ruleId"
      :section="section"
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
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import CommentDedupBanner from "./CommentDedupBanner.vue";
import FilterDropdown from "../shared/FilterDropdown.vue";

const COMMENT_MAX = 4000;

export default {
  name: "CommentComposerModal",
  components: { CommentDedupBanner, FilterDropdown },
  mixins: [AlertMixin],
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], required: true },
    ruleDisplayedName: { type: String, default: "" },
    initialSection: { type: String, default: null },
    replyToReviewId: { type: [Number, String], default: null },
  },
  data() {
    return {
      section: this.initialSection,
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
      return this.replyToReviewId ? "Reply to comment" : "New comment";
    },
    placeholder() {
      return this.replyToReviewId ? "Reply to this comment..." : "Type your comment...";
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
      if (this.replyToReviewId) {
        payload.review.responding_to_review_id = this.replyToReviewId;
      }

      try {
        await axios.post(`/rules/${this.ruleId}/reviews`, payload);
        this.$emit("posted");
        this.$bvModal.hide("comment-composer-modal");
        this.commentText = "";
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    onHidden() {
      this.commentText = "";
      this.$emit("hidden");
    },
  },
};
</script>
