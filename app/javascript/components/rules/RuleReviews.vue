<template>
  <div>
    <!-- Collapsable header -->
    <div class="clickable" @click="showReviews = !showReviews">
      <h2 class="m-0 d-inline-block">Reviews &amp; Comments</h2>
      <b-badge pill class="ml-1 superVerticalAlign">{{ rule.reviews.length }}</b-badge>

      <i v-if="showReviews" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
      <i v-if="!showReviews" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
    </div>

    <b-collapse id="collapse-reviews" v-model="showReviews">
      <!-- New review action -->
      <b-button
        class="dropdown-toggle m-2"
        variant="primary"
        size="sm"
        @click="showReviewPane = !showReviewPane"
      >
        Add Review or Comment
      </b-button>

      <!-- Review card -->
      <b-form class="reviewDropdownForm" @submit="reviewFormSubmitted">
        <div class="reviewDropdownCard">
          <b-card v-if="showReviewPane" class="shadow">
            <!-- Submit button -->
            <template #header>
              <strong>Complete a Review</strong>
              <i
                class="mdi mdi-close h5 mb-0 clickable float-right"
                aria-hidden="true"
                @click="showReviewPane = false"
              />
            </template>

            <!-- Review comment -->
            <b-form-group>
              <b-form-textarea
                v-model="reviewComment"
                name="rule_review[comment]"
                placeholder="Leave a comment..."
                rows="3"
                required
              />
            </b-form-group>

            <!-- Review action -->
            <b-form-group label="" class="mb-0">
              <b-form-radio
                v-for="action in reviewActions"
                :key="action.value"
                v-model="selectedReviewAction"
                v-b-tooltip.leftbottom.hover
                name="review-action-radios"
                :value="action.value"
                class="mb-1"
                :disabled="action.disabledTooltip != ''"
                :title="action.disabledTooltip"
              >
                <p class="mb-0">
                  <small
                    ><strong>{{ action.name }}</strong></small
                  >
                </p>
                <small
                  ><em>{{ action.description }}</em></small
                >
              </b-form-radio>
            </b-form-group>

            <!-- Submit button -->
            <template #footer>
              <b-button type="submit" size="sm" variant="primary">Submit Review</b-button>
            </template>
          </b-card>
        </div>
      </b-form>

      <!-- All reviews -->
      <p
        v-if="numShownReviews < rule.reviews.length"
        class="ml-2 mb-0 text-primary clickable"
        @click="numShownReviews += 5"
      >
        show older reviews...
      </p>
      <div v-for="review in shownReviews" :key="review.id">
        <p class="ml-2 mb-0 mt-2">
          <strong>{{ review.name }} - {{ actionDescriptions[review.action] }}</strong>
        </p>
        <p class="ml-2 mb-0">
          <small>{{ friendlyDateTime(review.created_at) }}</small>
        </p>
        <p class="ml-3 mb-3">{{ review.comment }}</p>
      </div>
    </b-collapse>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "RuleReviews",
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: {
      type: String,
      required: true,
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    rule: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      numShownReviews: 5,
      showReviews: false,
      showReviewPane: false,
      reviewComment: "",
      selectedReviewAction: "comment",
      actionDescriptions: {
        comment: "Commented",
        request_review: "Requested Review",
        revoke_review_request: "Revoked Request for Review",
        request_changes: "Requested Changes",
        approve: "Approved",
        lock_control: "Locked",
        unlock_control: "Unlocked",
      },
    };
  },
  computed: {
    shownReviews: function () {
      return this.rule.reviews.slice(-1 * this.numShownReviews);
    },
    reviewActions: function () {
      let actions = [
        {
          value: "comment",
          name: "Comment",
          description: "submit general feedback on the control",
          disabledTooltip: "",
        },
        {
          value: "request_review",
          name: "Request Review",
          description: "control will not be editable during the review process",
          disabledTooltip: "",
        },
        {
          value: "revoke_review_request",
          name: "Revoke Review Request",
          description: "revoke your request for review - control will be editable again",
          disabledTooltip: "",
        },
        {
          value: "request_changes",
          name: "Request Changes",
          description: "request changes on the control - control will be editable again",
          disabledTooltip: "",
        },
        {
          value: "approve",
          name: "Approve",
          description: "approve the control - control will become locked",
          disabledTooltip: "",
        },
        {
          value: "lock_control",
          name: "Lock Control",
          description: "skip the review process - control will be immediately locked",
          disabledTooltip: "",
        },
        {
          value: "unlock_control",
          name: "Unlock Control",
          description: "unlock the control - control will be editable again",
          disabledTooltip: "",
        },
      ];

      // Set some helper variables for readability
      const isRequestor = this.currentUserId == this.rule.review_requestor_id;
      const isAdmin = this.effectivePermissions == "admin";
      const isUnderReview = this.rule.review_requestor_id != null;
      const isReviewer = this.effectivePermissions == "reviewer";

      // should only be able to request review if
      // - not currently under review
      // - not currently locked
      if (isUnderReview) {
        actions[1]["disabledTooltip"] = "Control is already under review";
      }
      if (this.rule.locked) {
        actions[1]["disabledTooltip"] = "Control is currently locked";
      }

      // should only be able to revoke review request if
      // - current user is admin
      // - OR current user originally requested the review
      if (!(isAdmin || isRequestor)) {
        actions[2]["disabledTooltip"] =
          "Only an admin or the review requestor can revoke the current review request";
      } else if (!isUnderReview) {
        actions[2]["disabledTooltip"] = "Control is not currently under review";
      }

      // should only be able to request changes or approve if
      // - current user is a reviewer or admin
      // - control is currently under review
      if (!(isAdmin || isReviewer)) {
        actions[3]["disabledTooltip"] = "Only an admin or reviewer can request changes";
        actions[4]["disabledTooltip"] = "Only an admin or reviewer can approve";
      } else if (!isUnderReview) {
        actions[3]["disabledTooltip"] = "Control is not currently under review";
        actions[4]["disabledTooltip"] = "Control is not currently under review";
      }

      // should only be able to lock control if
      // - current user is admin
      // - control is not under review
      // - control is not locked
      if (!isAdmin) {
        actions[5]["disabledTooltip"] = "Only an admin can directly lock a control";
      } else {
        if (isUnderReview) {
          actions[5]["disabledTooltip"] = "Cannot lock a control that is currently under review";
        } else if (this.rule.locked) {
          actions[5]["disabledTooltip"] = "Cannot lock a control that is already locked";
        }
      }

      // should only be able to unlock a control if
      // - current user is admin
      // - control is locked
      if (!isAdmin) {
        actions[6]["disabledTooltip"] = "Only an admin can unlock a control";
      } else {
        if (!this.rule.locked) {
          actions[6]["disabledTooltip"] = "Cannot unlock a control that is not locked";
        }
      }

      return actions;
    },
  },
  methods: {
    reviewFormSubmitted: function (event) {
      event.preventDefault();

      // guard against invalid comment body
      if (!this.reviewComment.trim() || !this.selectedReviewAction) {
        return;
      }

      axios
        .post(`/rules/${this.rule.id}/reviews`, {
          review: {
            action: this.selectedReviewAction,
            comment: this.reviewComment.trim(),
          },
        })
        .then(this.reviewSubmitSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    reviewSubmitSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.reviewComment = "";
      this.selectedReviewAction = "comment";
      this.showReviewPane = false;
      this.$root.$emit("refresh:rule", this.rule.id, "all");
    },
  },
};
</script>

<style scoped>
.reviewDropdownCard {
  /* position: fixed;
  width: 33vw;
  right: 1rem;
  bottom: 1rem; */

  position: sticky;
  position: -webkit-sticky;
  top: 1rem;
  height: 0;
  width: 33vw;
}

.reviewDropdownForm {
  position: absolute;
  height: 100%;
  width: 0;
}
</style>
