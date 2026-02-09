<template>
  <b-modal id="review-modal" title="Complete a Review" centered size="md" @hidden="resetForm">
    <b-form @submit.prevent="submitReview">
      <b-form-group label="Comment" label-for="review-comment">
        <b-form-textarea
          id="review-comment"
          v-model="reviewComment"
          placeholder="Leave a comment..."
          rows="3"
          required
        />
      </b-form-group>

      <b-form-group label="Action" class="mb-0">
        <b-form-radio
          v-for="action in reviewActions"
          :key="action.value"
          v-model="selectedReviewAction"
          v-b-tooltip.left.hover
          name="review-action-radios"
          :value="action.value"
          class="mb-2"
          :disabled="!!action.disabledTooltip"
          :title="action.disabledTooltip"
        >
          <div>
            <strong class="small">{{ action.name }}</strong>
            <br />
            <small class="text-muted">{{ action.description }}</small>
          </div>
        </b-form-radio>
      </b-form-group>
    </b-form>

    <template #modal-footer="{ cancel }">
      <b-button variant="secondary" @click="cancel()">Cancel</b-button>
      <b-button
        variant="primary"
        :disabled="!selectedReviewAction || !reviewComment.trim()"
        @click="submitReview"
      >
        Submit Review
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { buildReviewActions } from "../../utils/reviewActionHelpers";

export default {
  name: "RuleReviewModal",
  mixins: [AlertMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    effectivePermissions: {
      type: String,
      default: "",
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedReviewAction: null,
      reviewComment: "",
    };
  },
  computed: {
    reviewActions() {
      return buildReviewActions(
        this.rule,
        this.readOnly,
        this.effectivePermissions,
        this.currentUserId,
      );
    },
  },
  methods: {
    resetForm() {
      this.reviewComment = "";
      this.selectedReviewAction = null;
    },
    submitReview() {
      if (!this.reviewComment.trim() || !this.selectedReviewAction) {
        return;
      }

      axios
        .post(`/rules/${this.rule.id}/reviews`, {
          review: {
            component_id: this.rule.component_id,
            action: this.selectedReviewAction,
            comment: this.reviewComment.trim(),
          },
        })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.resetForm();
          this.$bvModal.hide("review-modal");
          this.$emit("reviewSubmitted");
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>
