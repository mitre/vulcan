<template>
  <b-modal
    id="comment-triage-modal"
    size="lg"
    :title="modalTitle"
    no-close-on-backdrop
    @hidden="$emit('hidden')"
  >
    <template v-if="review">
      <p class="mb-1">
        <strong>{{ review.rule_displayed_name }}</strong>
        · Section: <SectionLabel :section="review.section" />
      </p>
      <p class="mb-1 text-muted small">
        <strong>{{ review.author_name }}</strong>
        <span v-if="review.author_email"> · {{ review.author_email }}</span>
        · posted {{ relativeTime(review.created_at) }}
      </p>
      <blockquote class="border-left pl-3 py-2 mb-3 bg-light">
        {{ review.comment }}
      </blockquote>

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
          Duplicate of:
          <b-form-input
            v-if="triageStatus === 'duplicate'"
            v-model.number="duplicateOfId"
            type="number"
            placeholder="comment #"
            size="sm"
            class="d-inline-block ml-2"
            style="width: 120px"
          />
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="informational">
          Informational — note acknowledged, no action required
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="needs_clarification">
          Needs clarification — round-trip with commenter
        </b-form-radio>
      </b-form-group>

      <b-form-group
        label="Response to commenter (visible in their thread + 'My Comments' page)"
        :description="nonConcurHint"
      >
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
    </template>

    <template #modal-footer="{ cancel }">
      <b-button variant="secondary" @click="cancel()">Cancel</b-button>
      <b-button variant="outline-primary" :disabled="!canSave" @click="saveTriage(false)">
        Save decision
      </b-button>
      <b-button
        variant="primary"
        :disabled="!canSave || !canSaveAndClose"
        @click="saveTriage(true)"
      >
        Save &amp; close
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import AlertMixin from "@/mixins/AlertMixin.vue";
import SectionLabel from "@/components/shared/SectionLabel.vue";

// Statuses that auto-set adjudicated_at server-side via the
// Review#auto_set_adjudicated_for_terminal_statuses callback (Task 06).
// "Save & close" doesn't make sense for these — they're already terminal,
// or (needs_clarification) explicitly waiting on the commenter.
const TERMINAL_BY_RULE = ["informational", "duplicate", "needs_clarification", "withdrawn"];

export default {
  name: "CommentTriageModal",
  components: { SectionLabel },
  mixins: [AlertMixin],
  props: {
    review: { type: Object, default: null },
  },
  data() {
    return {
      triageStatus: null,
      responseComment: "",
      duplicateOfId: null,
    };
  },
  computed: {
    modalTitle() {
      if (!this.review) return "Triage comment";
      return `Triage comment #${this.review.id}`;
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
      return true;
    },
    canSaveAndClose() {
      return !TERMINAL_BY_RULE.includes(this.triageStatus);
    },
  },
  watch: {
    review(val) {
      if (val) {
        this.triageStatus = val.triage_status === "pending" ? null : val.triage_status;
        this.responseComment = "";
        this.duplicateOfId = val.duplicate_of_review_id || null;
      }
    },
  },
  methods: {
    relativeTime(iso) {
      if (!iso) return "";
      return new Date(iso).toLocaleString();
    },
    async saveTriage(alsoAdjudicate) {
      if (!this.review) return;
      try {
        const triagePayload = {
          triage_status: this.triageStatus,
        };
        if (this.responseComment.trim()) {
          triagePayload.response_comment = this.responseComment.trim();
        }
        if (this.triageStatus === "duplicate") {
          triagePayload.duplicate_of_review_id = this.duplicateOfId;
        }

        const triageRes = await axios.patch(`/reviews/${this.review.id}/triage`, triagePayload);
        this.$emit("triaged", triageRes.data.review);

        if (alsoAdjudicate) {
          const adjudicateRes = await axios.patch(`/reviews/${this.review.id}/adjudicate`, {});
          this.$emit("adjudicated", adjudicateRes.data.review);
        }

        this.$bvModal.hide("comment-triage-modal");
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
  },
};
</script>
