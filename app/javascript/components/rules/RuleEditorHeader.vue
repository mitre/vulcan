<template>
  <!-- Rule Details column -->
  <div class="row">
    <div class="col-12">
      <h2>
        <i v-if="rule.locked" class="mdi mdi-lock" aria-hidden="true" />
        <i v-if="rule.review_requestor_id" class="mdi mdi-file-find" aria-hidden="true" />
        <i v-if="rule.changes_requested" class="mdi mdi-delta" aria-hidden="true" />
        {{ `${projectPrefix}-${rule.rule_id}` }} // {{ rule.version }}
      </h2>

      <p v-if="!readOnly && rule.locked" class="text-danger font-weight-bold">
        This control is locked and must first be unlocked if changes or deletion are required.
      </p>
      <p v-if="!readOnly && rule.review_requestor_id" class="text-danger font-weight-bold">
        This control is under review and cannot be edited at this time.
      </p>

      <div v-if="!readOnly">
        <!-- Rule info -->
        <!-- <p>Based on ...</p> -->
        <p v-if="rule.histories && rule.histories.length > 0">
          Last updated on {{ friendlyDateTime(rule.updated_at) }} by
          {{ lastEditor }}
        </p>
        <p v-else>Created on {{ friendlyDateTime(rule.created_at) }}</p>

        <!-- Action Buttons -->
        <!-- Clone rule modal -->
        <NewRuleModalForm
          :title="'Clone Control'"
          :id-prefix="'duplicate'"
          :for-duplicate="true"
          :selected-rule-id="rule.id"
          :selected-rule-text="`${projectPrefix}-${rule.rule_id}`"
          @ruleSelected="$emit('ruleSelected', $event.id)"
        />
        <b-button v-b-modal.duplicate-rule-modal variant="info">Clone Control</b-button>
        <!-- Mark/Unmark as duplicate modal -->
        <span
          v-if="
            rule.satisfied_by &&
            rule.satisfies &&
            rule.satisfied_by.length === 0 &&
            rule.satisfies.length > 0
          "
          v-b-tooltip.hover
          title="This control cannot be marked as duplicate because it satisfies other controls"
        >
          <b-button v-b-modal.mark-as-duplicate-modal disabled variant="orange"
            >Mark as Duplicate</b-button
          >
        </span>
        <span v-b-tooltip.hover title="Merge requirement">
          <b-button
            v-if="
              rule.satisfied_by &&
              rule.satisfies &&
              rule.satisfied_by.length === 0 &&
              rule.satisfies.length === 0
            "
            v-b-modal.mark-rule-as-duplicate-modal
            variant="orange"
            >Mark as Duplicate</b-button
          >
        </span>
        <span v-b-tooltip.hover title="Unmerge requirement">
          <b-button
            v-if="rule.satisfied_by && rule.satisfied_by.length > 0"
            v-b-modal.unmark-rule-as-duplicate-modal
            variant="orange"
            >Unmark as Duplicate</b-button
          >
        </span>
        <!-- Disable and enable save & delete buttons based on locked state of rule -->
        <template v-if="rule.locked || rule.review_requestor_id ? true : false">
          <span
            v-if="effectivePermissions == 'admin'"
            v-b-tooltip.hover
            class="d-inline-block"
            title="Cannot delete a control that is locked or under review"
          >
            <b-button variant="danger" disabled>Delete Control</b-button>
          </span>
          <span
            v-b-tooltip.hover
            class="d-inline-block"
            title="Cannot save a control that is locked or under review."
          >
            <b-button variant="success" disabled>Save Control</b-button>
          </span>
        </template>
        <template v-else>
          <!-- Delete rule -->
          <b-button
            v-if="effectivePermissions == 'admin'"
            v-b-modal.delete-rule-modal
            variant="danger"
          >
            Delete Control
          </b-button>

          <!-- Save rule -->
          <CommentModal
            title="Save Control"
            message="Provide a comment that summarizes your changes to this control."
            :require-non-empty="true"
            button-text="Save Control"
            button-variant="success"
            :button-disabled="false"
            wrapper-class="d-inline-block"
            @comment="saveRule($event)"
          />
        </template>

        <!-- Comment -->
        <CommentModal
          title="Comment"
          message="Submit general feedback on the control"
          :require-non-empty="true"
          button-text="Comment"
          button-variant="secondary"
          :button-disabled="false"
          wrapper-class="d-inline-block"
          @comment="commentFormSubmitted($event)"
        />

        <!-- Review Status -->
        <b-button
          class="dropdown-toggle"
          variant="primary"
          @click="showReviewPane = !showReviewPane"
        >
          Review Status
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
                  :disabled="!!action.disabledTooltip"
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
                <b-button
                  type="submit"
                  size="sm"
                  variant="primary"
                  :disabled="selectedReviewAction == ''"
                  >Submit Review</b-button
                >
              </template>
            </b-card>
          </div>
        </b-form>

        <b-modal
          id="delete-rule-modal"
          title="Delete Control"
          centered
          @ok="$root.$emit('delete:rule', rule.id)"
        >
          <p class="my-2">
            Are you sure you want to delete this control?<br />This cannot be undone.
          </p>

          <template #modal-footer="{ cancel, ok }">
            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button @click="cancel()"> Cancel </b-button>
            <b-button variant="danger" @click="ok()"> Permanently Delete Control </b-button>
          </template>
        </b-modal>
        <b-modal
          id="mark-rule-as-duplicate-modal"
          title="Mark as Duplicate"
          centered
          @ok="$root.$emit('markDuplicate:rule', rule.id, satisfied_by_rule_id)"
        >
          <p>Mark control as duplicate of:</p>
          <b-form-select
            v-model="satisfied_by_rule_id"
            :options="
              rules
                .filter((r) => {
                  return r.id !== rule.id && (!r.satisfied_by || r.satisfied_by.length === 0);
                })
                .map((r) => {
                  return { value: r.id, text: formatRuleId(r.rule_id) };
                })
            "
          />
          <template #modal-footer="{ cancel, ok }">
            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button @click="cancel()"> Cancel </b-button>
            <b-button variant="info" @click="ok()"> OK </b-button>
          </template>
        </b-modal>
        <b-modal
          id="unmark-rule-as-duplicate-modal"
          title="Unmark as Duplicate"
          centered
          @ok="$root.$emit('unmarkDuplicate:rule', rule.id, satisfied_by_rule_id)"
        >
          <p>Unmark control as duplicate of:</p>
          <b-form-select
            v-model="satisfied_by_rule_id"
            :options="
              rule.satisfied_by
                ? rule.satisfied_by.map((r) => {
                    return { value: r.id, text: formatRuleId(r.rule_id) };
                  })
                : []
            "
          />
          <template #modal-footer="{ cancel, ok }">
            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button @click="cancel()"> Cancel </b-button>
            <b-button variant="info" @click="ok()"> OK </b-button>
          </template>
        </b-modal>
      </div>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import CommentModal from "../shared/CommentModal.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";

export default {
  name: "RuleEditorHeader",
  components: { CommentModal, NewRuleModalForm },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: {
      type: String,
      default: "",
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    rule: {
      type: Object,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data: function () {
    return {
      satisfied_by_rule_id: null,
      selectedReviewAction: null,
      showReviewPane: false,
      reviewComment: "",
    };
  },
  computed: {
    lastEditor: function () {
      const histories = this.rule.histories;
      if (histories?.length > 0) {
        return histories[0].name || "Unknown User";
      }
      return "Unknown User";
    },
    reviewActions: function () {
      // Set some helper variables for readability
      const isAdmin = !this.readOnly && this.effectivePermissions == "admin";
      const isReviewer = !this.readOnly && this.effectivePermissions == "reviewer";
      const isRequestor = !this.readOnly && this.currentUserId == this.rule.review_requestor_id;
      const isUnderReview = this.rule.review_requestor_id != null;

      return [
        // should only be able to request review if
        // - not currently under review
        // - not currently locked
        {
          value: "request_review",
          name: "Request Review",
          description: "control will not be editable during the review process",
          disabledTooltip: isUnderReview
            ? "Control is already under review"
            : this.rule.locked
            ? "Control is currently locked"
            : null,
        },

        // should only be able to revoke review request if
        // - current user is admin
        // - OR current user originally requested the review
        {
          value: "revoke_review_request",
          name: "Revoke Review Request",
          description: "revoke your request for review - control will be editable again",
          disabledTooltip: !(isAdmin || isRequestor)
            ? "Only an admin or the review requestor can revoke the current review request"
            : !isUnderReview
            ? "Control is not currently under review"
            : null,
        },

        // should only be able to request changes if
        // - current user is a reviewer or admin
        // - control is currently under review
        {
          value: "request_changes",
          name: "Request Changes",
          description: "request changes on the control - control will be editable again",
          disabledTooltip: !(isAdmin || isReviewer)
            ? "Only an admin or reviewer can request changes"
            : !isUnderReview
            ? "Control is not currently under review"
            : null,
        },

        // should only be able to approve if
        // - current user is a reviewer or admin
        // - control is currently under review
        {
          value: "approve",
          name: "Approve",
          description: "approve the control - control will become locked",
          disabledTooltip: !(isAdmin || isReviewer)
            ? "Only an admin or reviewer can approve"
            : !isUnderReview
            ? "Control is not currently under review"
            : null,
        },

        // should only be able to lock control if
        // - current user is admin
        // - control is not under review
        // - control is not locked
        {
          value: "lock_control",
          name: "Lock Control",
          description: "skip the review process - control will be immediately locked",
          disabledTooltip: !isAdmin
            ? "Only an admin can directly lock a control"
            : isUnderReview
            ? "Cannot lock a control that is currently under review"
            : this.rule.locked
            ? "Cannot lock a control that is already locked"
            : null,
        },

        // should only be able to unlock a control if
        // - current user is admin
        // - control is locked
        {
          value: "unlock_control",
          name: "Unlock Control",
          description: "unlock the control - control will be editable again",
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
    saveRule(comment) {
      const payload = {
        rule: {
          ...this.rule,
          audit_comment: comment,
        },
      };
      axios
        .put(`/rules/${this.rule.id}`, payload)
        .then(this.saveRuleSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    saveRuleSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$root.$emit("refresh:rule", this.rule.id);
    },
    formatRuleId: function (id) {
      return `${this.projectPrefix}-${id}`;
    },
    commentFormSubmitted: function (comment) {
      // guard against invalid comment body
      if (!comment.trim()) {
        return;
      }

      axios
        .post(`/rules/${this.rule.id}/reviews`, {
          review: {
            action: "comment",
            comment: comment,
          },
        })
        .then(this.reviewSubmitSuccess)
        .catch(this.alertOrNotifyResponse);
    },
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
      this.selectedReviewAction = null;
      this.showReviewPane = false;
      this.$root.$emit("refresh:rule", this.rule.id, "all");
    },
  },
};
</script>

<style scoped>
.reviewDropdownCard {
  position: absolute;
  top: 0;
  right: 0;
  height: 0;
  width: 33vw;
  z-index: 1;
}

.reviewDropdownForm {
  position: absolute;
  height: 100%;
  right: 10rem;
  width: 0;
  margin-top: 0.25rem;
}
</style>
