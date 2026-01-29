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
      const isAdmin = !this.readOnly && this.effectivePermissions === "admin";
      const isReviewer = !this.readOnly && this.effectivePermissions === "reviewer";
      const isRequestor = !this.readOnly && this.currentUserId === this.rule.review_requestor_id;
      const isUnderReview = this.rule.review_requestor_id != null;

      return [
        {
          value: "request_review",
          name: "Request Review",
          description: "Control will not be editable during the review process",
          disabledTooltip: isUnderReview
            ? "Control is already under review"
            : this.rule.locked
              ? "Control is currently locked"
              : null,
        },
        {
          value: "revoke_review_request",
          name: "Revoke Review Request",
          description: "Revoke your request for review - control will be editable again",
          disabledTooltip: !(isAdmin || isRequestor)
            ? "Only an admin or the review requestor can revoke the current review request"
            : !isUnderReview
              ? "Control is not currently under review"
              : null,
        },
        {
          value: "request_changes",
          name: "Request Changes",
          description: "Request changes on the control - control will be editable again",
          disabledTooltip: !(isAdmin || isReviewer)
            ? "Only an admin or reviewer can request changes"
            : !isUnderReview
              ? "Control is not currently under review"
              : null,
        },
        {
          value: "approve",
          name: "Approve",
          description: "Approve the control - control will become locked",
          disabledTooltip: !(isAdmin || isReviewer)
            ? "Only an admin or reviewer can approve"
            : !isUnderReview
              ? "Control is not currently under review"
              : null,
        },
        {
          value: "lock_control",
          name: "Lock Control",
          description: "Skip the review process - control will be immediately locked",
          disabledTooltip: !isAdmin
            ? "Only an admin can directly lock a control"
            : isUnderReview
              ? "Cannot lock a control that is currently under review"
              : this.rule.locked
                ? "Cannot lock a control that is already locked"
                : this.rule.status === "Applicable - Does Not Meet" &&
                    this.rule.disa_rule_descriptions_attributes?.[0]?.mitigations?.length === 0
                  ? "Cannot lock control: Mitigation is required for Applicable - Does Not Meet"
                  : this.rule.status === "Applicable - Inherently Meets" &&
                      (!this.rule.artifact_description ||
                        this.rule.artifact_description.length === 0)
                    ? "Cannot lock control: Artifact Description is required for Applicable - Inherently Meets"
                    : null,
        },
        {
          value: "unlock_control",
          name: "Unlock Control",
          description: "Unlock the control - control will be editable again",
          disabledTooltip: !isAdmin
            ? "Only an admin can unlock a control"
            : !this.rule.locked
              ? "Cannot unlock a control that is not locked"
              : null,
        },
      ];
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
