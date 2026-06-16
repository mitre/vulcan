<template>
  <div class="comment-triage-form">
    <b-form-group label="Decision" stacked>
      <b-form-radio v-model="triageStatus" name="triage" value="concur">
        Accept (Concur) — incorporate as suggested
      </b-form-radio>
      <b-form-radio v-model="triageStatus" name="triage" value="concur_with_comment">
        Accept with changes (Concur with comment) — incorporate with changes
      </b-form-radio>
      <b-form-radio v-model="triageStatus" name="triage" value="non_concur">
        Decline (Non-concur) — won't incorporate (response required)
      </b-form-radio>
      <b-form-radio v-model="triageStatus" name="triage" value="duplicate">
        Duplicate of another comment in this component
      </b-form-radio>
      <CanonicalCommentPicker
        v-if="triageStatus === 'duplicate' && resolvedComponentId"
        class="mt-2 ml-4"
        :component-id="resolvedComponentId"
        :exclude-review-id="review.id"
        :selected-review-id="duplicateOfId"
        @selected="onDuplicateSelected"
      />
      <b-form-radio v-model="triageStatus" name="triage" value="informational">
        Informational — note acknowledged, no action required
      </b-form-radio>
      <b-form-radio v-model="triageStatus" name="triage" value="addressed_by">
        Addressed by another requirement
      </b-form-radio>
      <RulePicker
        v-if="triageStatus === 'addressed_by' && resolvedComponentId"
        class="mt-2 ml-4"
        :component-id="resolvedComponentId"
        :exclude-rule-id="review.rule_id || 0"
        :selected-rule-id="addressedByRuleId"
        @selected="onAddressedBySelected"
      />
      <b-form-radio v-model="triageStatus" name="triage" value="needs_clarification">
        Needs clarification — round-trip with commenter
      </b-form-radio>
    </b-form-group>

    <b-form-group
      label="Response to commenter (visible in their thread + 'My Comments' page)"
      :description="nonConcurHint"
    >
      <ResponseTemplateDropdown
        v-if="projectId"
        :project-id="projectId"
        :can-manage="canManageTemplates"
        @insert="insertTemplate"
      />
      <b-form-textarea
        v-model="responseComment"
        rows="3"
        :placeholder="responsePlaceholder"
        :state="responseState"
      />
      <b-form-invalid-feedback v-if="responseState === false" role="alert">
        Decline requires a response — explain why so the commenter understands.
      </b-form-invalid-feedback>
    </b-form-group>

    <div class="d-flex justify-content-between align-items-center">
      <div>
        <slot name="actions-left" />
      </div>
      <div>
        <b-button
          data-testid="cancel"
          variant="secondary"
          size="sm"
          class="mr-1"
          @click="$emit('cancel')"
        >
          Cancel
        </b-button>
        <b-button
          v-if="hasSaveDecisionOnlyOption"
          data-testid="save-decision"
          variant="outline-primary"
          size="sm"
          class="mr-1"
          :disabled="!canSave || loading"
          @click="emitSave"
        >
          Save decision
        </b-button>
        <b-button
          data-testid="save-and-next"
          variant="primary"
          size="sm"
          :disabled="!canSave || loading"
          @click="emitSaveAndNext"
        >
          {{ primaryButtonLabel }}
        </b-button>
      </div>
    </div>
  </div>
</template>

<script>
import { SINGLE_BUTTON_STATUSES } from "../../constants/triageVocabulary";
import CanonicalCommentPicker from "../components/CanonicalCommentPicker.vue";
import RulePicker from "../components/RulePicker.vue";
import ResponseTemplateDropdown from "./ResponseTemplateDropdown.vue";

export default {
  name: "CommentTriageForm",
  components: { CanonicalCommentPicker, RulePicker, ResponseTemplateDropdown },
  props: {
    review: { type: Object, required: true },
    componentId: { type: [Number, String], default: null },
    projectId: { type: [Number, String], default: null },
    canManageTemplates: { type: Boolean, default: false },
    loading: { type: Boolean, default: false },
  },
  data() {
    return {
      triageStatus: null,
      responseComment: "",
      duplicateOfId: null,
      addressedByRuleId: null,
    };
  },
  computed: {
    resolvedComponentId() {
      return this.componentId || this.review?.component_id || null;
    },
    nonConcurHint() {
      return this.triageStatus === "non_concur" ? "A response is required when declining." : "";
    },
    responsePlaceholder() {
      switch (this.triageStatus) {
        case "concur":
          return "Thanks — we'll adopt this as suggested.";
        case "concur_with_comment":
          return "Thanks — we'll adopt with the following changes...";
        case "non_concur":
          return "Thanks for the suggestion. We won't adopt because...";
        default:
          return "Optional response to the commenter.";
      }
    },
    responseState() {
      if (this.triageStatus === "non_concur" && !this.responseComment.trim()) {
        return false;
      }
      return null;
    },
    canSave() {
      if (!this.triageStatus) return false;
      if (this.triageStatus === "non_concur" && !this.responseComment.trim()) return false;
      if (this.triageStatus === "duplicate" && !this.duplicateOfId) return false;
      if (this.triageStatus === "addressed_by" && !this.addressedByRuleId) return false;
      return true;
    },
    singleButtonMode() {
      return SINGLE_BUTTON_STATUSES.has(this.triageStatus);
    },
    hasSaveDecisionOnlyOption() {
      return !this.singleButtonMode;
    },
    primaryButtonLabel() {
      if (this.triageStatus === "needs_clarification") return "Save & wait for commenter";
      return "Save & next";
    },
  },
  watch: {
    review: {
      handler(val) {
        if (val) {
          this.triageStatus = val.triage_status === "pending" ? null : val.triage_status;
          this.responseComment = "";
          this.duplicateOfId = val.duplicate_of_review_id || null;
          this.addressedByRuleId = val.addressed_by_rule_id || null;
        }
      },
      immediate: true,
    },
    triageStatus() {
      this.emitDirty();
    },
    responseComment() {
      this.emitDirty();
    },
    duplicateOfId() {
      this.emitDirty();
    },
    addressedByRuleId() {
      this.emitDirty();
    },
  },
  methods: {
    insertTemplate(body) {
      // Append below existing draft so the triager doesn't lose typed text;
      // empty textarea replaces (clean insert). Whitespace-only is treated
      // as empty so we don't carry orphan newlines from a cleared field.
      const current = (this.responseComment || "").trimEnd();
      this.responseComment = current ? `${current}\n\n${body}` : body;
    },
    buildDecision() {
      const decision = {
        triage_status: this.triageStatus,
      };
      if (this.responseComment.trim()) {
        decision.response_comment = this.responseComment.trim();
      }
      if (this.triageStatus === "duplicate") {
        decision.duplicate_of_review_id = this.duplicateOfId;
      }
      if (this.triageStatus === "addressed_by") {
        decision.addressed_by_rule_id = this.addressedByRuleId;
      }
      return decision;
    },
    emitSave() {
      if (!this.canSave) return;
      this.$emit("save", this.buildDecision());
    },
    emitSaveAndNext() {
      if (!this.canSave) return;
      this.$emit("save-and-next", this.buildDecision());
    },
    emitDirty() {
      const initialStatus =
        this.review?.triage_status === "pending" ? null : this.review?.triage_status;
      const isDirty =
        this.triageStatus !== initialStatus ||
        this.responseComment !== "" ||
        this.duplicateOfId !== (this.review?.duplicate_of_review_id || null);
      this.$emit("dirty", isDirty);
    },
    onDuplicateSelected(reviewId) {
      this.duplicateOfId = reviewId;
    },
    onAddressedBySelected(ruleId) {
      this.addressedByRuleId = ruleId;
    },
  },
};
</script>
