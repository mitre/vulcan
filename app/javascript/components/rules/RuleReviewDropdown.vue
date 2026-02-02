<template>
  <div class="review-dropdown mt-2">
    <b-card class="shadow-sm">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <strong>Complete a Review</strong>
          <b-button variant="link" size="sm" class="p-0" @click="$emit('close')">
            <b-icon icon="x" />
          </b-button>
        </div>
      </template>

      <b-form @submit.prevent="submitReview">
        <b-form-group>
          <b-form-textarea
            v-model="reviewComment"
            placeholder="Leave a comment..."
            rows="3"
            required
          />
        </b-form-group>

        <b-form-group label="" class="mb-0">
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

      <template #footer>
        <b-button
          type="submit"
          size="sm"
          variant="primary"
          :disabled="!selectedReviewAction || !reviewComment.trim()"
          @click="submitReview"
        >
          Submit Review
        </b-button>
      </template>
    </b-card>
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { REVIEW_ACTION_LABELS } from "../../constants/terminology";

export default {
  name: "RuleReviewDropdown",
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
      reviewLabels: REVIEW_ACTION_LABELS,
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
      const labels = this.reviewLabels;

      return [
        {
          value: "request_review",
          name: labels.requestReview.name,
          description: labels.requestReview.description,
          disabledTooltip: isUnderReview
            ? labels.requestReview.alreadyUnderReview
            : this.rule.locked
              ? labels.requestReview.isLocked
              : null,
        },
        {
          value: "revoke_review_request",
          name: labels.revokeReview.name,
          description: labels.revokeReview.description,
          disabledTooltip: !(isAdmin || isRequestor)
            ? labels.revokeReview.notAllowed
            : !isUnderReview
              ? labels.revokeReview.notUnderReview
              : null,
        },
        {
          value: "request_changes",
          name: labels.requestChanges.name,
          description: labels.requestChanges.description,
          disabledTooltip: !(isAdmin || isReviewer)
            ? labels.requestChanges.notAllowed
            : !isUnderReview
              ? labels.requestChanges.notUnderReview
              : null,
        },
        {
          value: "approve",
          name: labels.approve.name,
          description: labels.approve.description,
          disabledTooltip: !(isAdmin || isReviewer)
            ? labels.approve.notAllowed
            : !isUnderReview
              ? labels.approve.notUnderReview
              : null,
        },
        {
          value: "lock_control",
          name: labels.lock.name,
          description: labels.lock.description,
          disabledTooltip: !isAdmin
            ? labels.lock.notAllowed
            : isUnderReview
              ? labels.lock.underReview
              : this.rule.locked
                ? labels.lock.alreadyLocked
                : this.rule.status === "Applicable - Does Not Meet" &&
                    this.rule.disa_rule_descriptions_attributes?.[0]?.mitigations?.length === 0
                  ? labels.lock.mitigationRequired
                  : this.rule.status === "Applicable - Inherently Meets" &&
                      (!this.rule.artifact_description ||
                        this.rule.artifact_description.length === 0)
                    ? labels.lock.artifactRequired
                    : null,
        },
        {
          value: "unlock_control",
          name: labels.unlock.name,
          description: labels.unlock.description,
          disabledTooltip: !isAdmin
            ? labels.unlock.notAllowed
            : !this.rule.locked
              ? labels.unlock.notLocked
              : null,
        },
      ];
    },
  },
  methods: {
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
          this.reviewComment = "";
          this.selectedReviewAction = null;
          this.$emit("reviewSubmitted");
          this.$emit("close");
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped>
.review-dropdown {
  max-width: 400px;
}
</style>
