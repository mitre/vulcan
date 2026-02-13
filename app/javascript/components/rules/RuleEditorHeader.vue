<template>
  <!-- Rule Details column -->
  <div class="row">
    <div class="col-12">
      <div class="row">
        <h2>
          <b-icon v-if="rule.locked" icon="lock" aria-hidden="true" />
          <b-icon v-if="rule.review_requestor_id" icon="file-earmark-search" aria-hidden="true" />
          <b-icon v-if="rule.changes_requested" icon="exclamation-triangle" aria-hidden="true" />
          <a
            class="headerLink"
            :href="`/components/${rule.component_id}/${projectPrefix}-${rule.rule_id}`"
          >
            {{ `${projectPrefix}-${rule.rule_id}` }} // {{ rule.version }}
          </a>
        </h2>
      </div>
      <p v-if="!readOnly && rule.locked" class="text-danger font-weight-bold">
        This {{ term.singular.toLowerCase() }} is locked and must first be unlocked if changes or
        deletion are required.
      </p>
      <p v-if="!readOnly && rule.review_requestor_id" class="text-danger font-weight-bold">
        This {{ term.singular.toLowerCase() }} is under review and cannot be edited at this time.
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
          :title="msg.cloneTitle"
          :id-prefix="'duplicate'"
          :for-duplicate="true"
          :selected-rule-id="rule.id"
          :selected-rule-text="`${projectPrefix}-${rule.rule_id}`"
          @ruleSelected="$emit('ruleSelected', $event.id)"
        />
        <b-button v-b-modal.duplicate-rule-modal variant="info">{{ msg.cloneTitle }}</b-button>

        <!-- Disable and enable save & delete buttons based on locked state of rule -->
        <template v-if="rule.locked || rule.review_requestor_id ? true : false">
          <span
            v-if="effectivePermissions == 'admin'"
            v-b-tooltip.hover
            class="d-inline-block"
            :title="msg.cannotDeleteLocked"
          >
            <b-button variant="danger" disabled>{{ msg.deleteTitle }}</b-button>
          </span>
          <span v-b-tooltip.hover class="d-inline-block" :title="msg.cannotSaveLocked">
            <b-button variant="success" disabled>{{ msg.saveTitle }}</b-button>
          </span>
        </template>
        <template v-else>
          <!-- Delete rule -->
          <b-button
            v-if="effectivePermissions == 'admin'"
            v-b-modal.delete-rule-modal
            variant="danger"
          >
            {{ msg.deleteTitle }}
          </b-button>

          <!-- Save rule -->
          <CommentModal
            :title="msg.saveTitle"
            :message="msg.saveMessage"
            :require-non-empty="true"
            :button-text="msg.saveTitle"
            button-variant="success"
            :button-disabled="false"
            wrapper-class="d-inline-block"
            @comment="saveRule($event)"
          />
        </template>

        <!-- Comment -->
        <CommentModal
          title="Comment"
          :message="msg.commentMessage"
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
                <b-icon icon="x" aria-hidden="true" @click="showReviewPane = false" />
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
          :title="msg.deleteTitle"
          centered
          @ok="$root.$emit('delete:rule', rule.id)"
        >
          <p class="my-2">{{ msg.deleteConfirmMessage }}</p>

          <template #modal-footer="{ cancel, ok }">
            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button @click="cancel()"> Cancel </b-button>
            <b-button variant="danger" @click="ok()">{{ msg.deleteConfirmButton }}</b-button>
          </template>
        </b-modal>
        <b-modal
          id="also-satisfies-modal"
          title="Also Satisfies"
          centered
          size="lg"
          @ok="addMultipleSatisfiedRules"
          @hidden="clearSelectedRules"
        >
          <b-form-group :label="msg.satisfiesPrompt">
            <multiselect
              v-model="selectedSatisfiesRuleIds"
              :options="filteredSelectRules"
              :multiple="true"
              :close-on-select="false"
              :clear-on-select="false"
              :preserve-search="true"
              :taggable="true"
              tag-placeholder="Press enter to add"
              :placeholder="msg.satisfiesPlaceholder"
              label="text"
              track-by="value"
              :preselect-first="false"
              @tag="addCustomSatisfaction"
            >
              <template slot="selection" slot-scope="{ values, isOpen }">
                <span v-if="values.length && !isOpen" class="multiselect__single">
                  {{ selectedCountLabel(values.length) }}
                </span>
              </template>
            </multiselect>
          </b-form-group>
          <div class="mt-2 text-muted">
            <small>{{ selectedCountLabel(selectedSatisfiesRuleIds.length) }}</small>
          </div>
          <template #modal-footer="{ cancel, ok }">
            <b-button @click="cancel()"> Cancel </b-button>
            <b-button
              variant="info"
              :disabled="selectedSatisfiesRuleIds.length === 0"
              @click="ok()"
            >
              Add {{ selectedSatisfiesRuleIds.length }} {{ term.plural }}
            </b-button>
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
import Multiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";
import {
  RULE_TERM,
  MESSAGE_LABELS,
  REVIEW_ACTION_LABELS,
  selectedCountLabel,
} from "../../constants/terminology";

export default {
  name: "RuleEditorHeader",
  components: { CommentModal, NewRuleModalForm, Multiselect },
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
      term: RULE_TERM,
      msg: MESSAGE_LABELS,
      reviewLabels: REVIEW_ACTION_LABELS,
      showSRGIdChecked: localStorage.getItem(`showSRGIdChecked-${this.rules[0].component_id}`),
      filteredSelectRules: [],
      selectedSatisfiesRuleIds: [], // Array for multi-select
      satisfiesSearchText: "", // Search filter text
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
      const labels = this.reviewLabels;

      return [
        // should only be able to request review if
        // - not currently under review
        // - not currently locked
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

        // should only be able to revoke review request if
        // - current user is admin
        // - OR current user originally requested the review
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

        // should only be able to request changes if
        // - current user is a reviewer or admin
        // - control is currently under review
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

        // should only be able to approve if
        // - current user is a reviewer or admin
        // - control is currently under review
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

        // should only be able to lock rule if
        // - current user is admin
        // - rule is not under review
        // - rule is not locked
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
                    this.rule.disa_rule_descriptions_attributes[0].mitigations.length === 0
                  ? labels.lock.mitigationRequired
                  : this.rule.status === "Applicable - Inherently Meets" &&
                      (this.rule.artifact_description === null ||
                        this.rule.artifact_description.length === 0)
                    ? labels.lock.artifactRequired
                    : null,
        },

        // should only be able to unlock a rule if
        // - current user is admin
        // - rule is locked
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
  watch: {
    rule: function (_) {
      this.filterRules();
    },
  },
  mounted: function () {
    this.updateShowSRGIdChecked();
  },
  beforeUnmount: function () {
    clearInterval(this.showSRGIdCheckedInterval);
  },
  methods: {
    selectedCountLabel,
    updateShowSRGIdChecked: function () {
      const componentId = this.rules[0].component_id;
      this.showSRGIdCheckedInterval = setInterval(() => {
        const newValue = localStorage.getItem(`showSRGIdChecked-${componentId}`);
        if (newValue !== this.showSRGIdChecked) {
          this.showSRGIdChecked = newValue;
          this.filterRules();
        }
      }, 1000);
    },
    filterRules: function () {
      this.filteredSelectRules = this.rules
        .filter((r) => {
          return (
            r.id !== this.rule.id &&
            r.satisfies.length === 0 &&
            !this.rule.satisfies.some((s) => s.id === r.id)
          );
        })
        .map((r) => {
          return {
            value: r.id,
            text: JSON.parse(this.showSRGIdChecked) ? r.version : this.formatRuleId(r.rule_id),
          };
        });
    },
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
            component_id: this.rule.component_id,
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
      if (this.rule.satisfied_by.length > 0) {
        this.rule.satisfied_by.forEach((r) => {
          this.$root.$emit("refresh:rule", r.id, "all");
        });
      }
    },
    addCustomSatisfaction: function (searchText) {
      // Handle pasted or typed satisfaction (SRG ID or rule ID)
      // User can paste "SRG-OS-000480" or full "SRG-OS-000480-GPOS-00227"
      const trimmed = searchText.trim();
      if (!trimmed) return;

      // Try to find matching rule by SRG ID or rule ID
      const matchingRule = this.rules.find((r) => {
        return (
          r.srg_rule && r.srg_rule.version === trimmed ||
          r.rule_id === trimmed ||
          `${this.component.prefix}-${r.rule_id}` === trimmed
        );
      });

      if (matchingRule) {
        // Add to selection
        this.selectedSatisfiesRuleIds.push({
          value: matchingRule.id,
          text: `${this.component.prefix}-${matchingRule.rule_id}`
        });
      }
    },
    addMultipleSatisfiedRules: function () {
      // Add all selected rules as satisfied by this rule
      // selectedSatisfiesRuleIds contains objects with {value, text} from multiselect
      this.selectedSatisfiesRuleIds.forEach((item) => {
        const ruleId = typeof item === "object" ? item.value : item;
        this.$root.$emit("addSatisfied:rule", ruleId, this.rule.id);
      });
    },
    clearSelectedRules: function () {
      // Clear selections when modal is hidden
      this.selectedSatisfiesRuleIds = [];
      this.satisfiesSearchText = "";
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

.headerLink {
  color: inherit;
}
</style>
