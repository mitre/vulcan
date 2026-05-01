<template>
  <b-modal
    id="comment-triage-modal"
    size="lg"
    :title="modalTitle"
    centered
    no-close-on-backdrop
    @hidden="$emit('hidden')"
  >
    <template v-if="review">
      <p class="mb-1">
        <strong>{{ review.rule_displayed_name }}</strong>
        · Section: <SectionLabel :section="review.section" />
        <b-button
          v-if="canEditSection && !sectionEditMode"
          variant="link"
          size="sm"
          class="p-0 ml-1"
          data-testid="edit-section-affordance"
          @click="enterSectionEdit"
        >
          <b-icon icon="pencil" /> Edit
        </b-button>
      </p>

      <!-- PR-717 Task 30: retroactive section editing. Triager (author+)
           retags a misclassified comment to the correct XCCDF section. The
           server requires an audit comment for the change to land. Saving
           the same section is a no-op (idempotent — no audit record). -->
      <div
        v-if="sectionEditMode"
        class="mb-3 p-2 border rounded bg-light"
        data-testid="section-edit-form"
      >
        <label class="small text-muted mb-1">Move this comment to section:</label>
        <FilterDropdown
          v-model="newSection"
          :options="sectionOptions"
          aria-label="Pick a new section for this comment"
          class="d-inline-block"
        />
        <b-form-textarea
          v-model="sectionAuditComment"
          rows="2"
          placeholder="Why is this section wrong? (audit log)"
          size="sm"
          class="mt-2"
          data-testid="section-edit-audit-comment"
        />
        <div class="mt-2">
          <b-button size="sm" data-testid="section-edit-cancel" @click="cancelSectionEdit">
            Cancel
          </b-button>
          <b-button
            size="sm"
            variant="primary"
            data-testid="section-edit-confirm"
            :disabled="!canSubmitSectionChange"
            @click="submitSectionChange"
          >
            Save section
          </b-button>
        </div>
      </div>

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
          Duplicate of another comment in this component
        </b-form-radio>
        <CanonicalCommentPicker
          v-if="triageStatus === 'duplicate' && pickerComponentId"
          class="mt-2 ml-4"
          :component-id="pickerComponentId"
          :exclude-review-id="review.id"
          :selected-review-id="duplicateOfId"
          @selected="onDuplicateSelected"
        />
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

      <!-- PR-717 Task 25: admin override actions. Visible only to project
           admins. Audit comment required server-side; the Confirm button
           is gated on a non-blank textarea. Force-withdraw is always
           available; Restore is offered only when the comment is already
           adjudicated (otherwise there is nothing to revert). -->
      <div v-if="canAdminAct" class="mt-3 border-top pt-3">
        <b-button
          variant="link"
          size="sm"
          class="p-0"
          data-testid="open-admin-actions"
          :aria-expanded="String(adminActionsOpen)"
          @click="adminActionsOpen = !adminActionsOpen"
        >
          <b-icon icon="shield-lock" class="text-warning" />
          Admin actions {{ adminActionsOpen ? "▴" : "▾" }}
        </b-button>

        <div v-show="adminActionsOpen" class="mt-2 p-2 border rounded bg-light">
          <p class="text-muted small mb-2">
            Use sparingly — admin overrides are recorded in the audit log with the reason you
            provide below. These actions bypass the standard triage flow.
          </p>
          <div v-if="!adminAction">
            <b-button
              size="sm"
              variant="outline-warning"
              class="mr-2"
              data-testid="admin-action-force-withdraw"
              @click="adminAction = 'force-withdraw'"
            >
              <b-icon icon="x-octagon" /> Force-withdraw
            </b-button>
            <b-button
              v-if="canRestore"
              size="sm"
              variant="outline-secondary"
              class="mr-2"
              data-testid="admin-action-restore"
              @click="adminAction = 'restore'"
            >
              <b-icon icon="arrow-counterclockwise" /> Restore
            </b-button>
            <b-button
              size="sm"
              variant="outline-secondary"
              class="mr-2"
              data-testid="admin-action-move-to-rule"
              @click="adminAction = 'move-to-rule'"
            >
              <b-icon icon="arrow-right-square" /> Move to rule
            </b-button>
            <b-button
              size="sm"
              variant="outline-danger"
              data-testid="admin-action-hard-delete"
              @click="adminAction = 'hard-delete'"
            >
              <b-icon icon="trash" /> Hard-delete
            </b-button>
          </div>
          <div v-else>
            <p
              v-if="adminAction === 'hard-delete'"
              class="text-danger small mb-2 font-weight-bold"
              role="alert"
            >
              <b-icon icon="exclamation-triangle-fill" />
              This permanently deletes the comment AND ALL REPLIES. It cannot be undone.
            </p>
            <RulePicker
              v-if="adminAction === 'move-to-rule' && pickerComponentId"
              class="mb-2"
              :component-id="pickerComponentId"
              :exclude-rule-id="review.rule_id"
              :selected-rule-id="adminTargetRuleId"
              @selected="onTargetRuleSelected"
            />
            <b-form-textarea
              v-model="adminAuditComment"
              rows="2"
              :placeholder="adminActionPrompt"
              size="sm"
              data-testid="admin-action-audit-comment"
            />
            <div v-if="adminAction === 'hard-delete'" class="mt-2">
              <label class="small text-muted mb-1">
                Type the comment ID
                <strong>{{ review.id }}</strong>
                to confirm:
              </label>
              <b-form-input
                v-model="adminConfirmationId"
                size="sm"
                placeholder="Comment ID"
                data-testid="admin-action-confirmation-id"
              />
            </div>
            <div class="mt-2">
              <b-button size="sm" data-testid="admin-action-cancel" @click="cancelAdminAction">
                Cancel
              </b-button>
              <b-button
                size="sm"
                :variant="adminConfirmVariant"
                data-testid="admin-action-confirm"
                :disabled="!canSubmitAdminAction"
                @click="submitAdminAction"
              >
                Confirm {{ adminConfirmLabel }}
              </b-button>
            </div>
          </div>
        </div>
      </div>
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
import AlertMixin from "../../mixins/AlertMixin.vue";
import FormMixin from "../../mixins/FormMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import SectionLabel from "../shared/SectionLabel.vue";
import FilterDropdown from "../shared/FilterDropdown.vue";
import CanonicalCommentPicker from "./CanonicalCommentPicker.vue";
import RulePicker from "./RulePicker.vue";

// Statuses that auto-set adjudicated_at server-side via the
// Review#auto_set_adjudicated_for_terminal_statuses callback (Task 06).
// "Save & close" doesn't make sense for these — they're already terminal,
// or (needs_clarification) explicitly waiting on the commenter.
const TERMINAL_BY_RULE = ["informational", "duplicate", "needs_clarification", "withdrawn"];

export default {
  name: "CommentTriageModal",
  components: { SectionLabel, FilterDropdown, CanonicalCommentPicker, RulePicker },
  // FormMixin sets axios.defaults['X-CSRF-Token'] on mount. Required because the
  // ComponentTriagePage host pack does NOT include FormMixin, so without this the
  // modal's axios.patch calls get rejected at the Rails CSRF middleware (422).
  // Each Vue pack has its own axios singleton (esbuild bundle isolation) — the
  // navbar pack's FormMixin doesn't reach the triage pack.
  // RoleComparisonMixin provides role_gte_to() for the canEditSection gate
  // (PR-717 Task 30 — author+ retags a comment's section).
  mixins: [AlertMixin, FormMixin, RoleComparisonMixin],
  props: {
    review: { type: Object, default: null },
    // Component the picker is scoped to — defaults to the review's
    // component_id (set on the row) so project-aggregate triage queues
    // pick the right component per-row without the parent juggling state.
    componentId: { type: [Number, String], default: null },
    // PR-717 Task 25: gates the Admin actions disclosure. Project admins
    // get force-withdraw + restore (the inverse). Anything other than
    // 'admin' means the disclosure is not rendered.
    effectivePermissions: { type: String, default: null },
  },
  data() {
    return {
      triageStatus: null,
      responseComment: "",
      duplicateOfId: null,
      // Admin actions disclosure state (PR-717 Task 25). Closed by default
      // so triagers don't accidentally click into the override panel.
      adminActionsOpen: false,
      adminAction: null, // 'force-withdraw' | 'restore' | 'hard-delete' | null
      adminAuditComment: "",
      // PR-717 Task 25b: typed-confirmation safeguard for irreversible
      // hard-delete. Admin must type the review ID exactly to enable Confirm.
      adminConfirmationId: "",
      // PR-717 Task 26: target rule chosen via RulePicker for move-to-rule.
      adminTargetRuleId: null,
      // PR-717 Task 30: section editing sub-form state. Author+ retags
      // a comment's section retroactively. Closed by default — opens via
      // the pencil button next to the section badge in the modal header.
      sectionEditMode: false,
      newSection: null,
      sectionAuditComment: "",
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
    pickerComponentId() {
      return this.componentId || this.review?.component_id || null;
    },
    // PR-717 Task 25 — admin override gating. The server enforces the
    // same gate (authorize_admin_project), so this is purely UI hiding.
    canAdminAct() {
      return this.effectivePermissions === "admin";
    },
    // Restore is the inverse of any prior adjudication (force-withdraw,
    // concur, non-concur, etc.). Only meaningful on already-adjudicated
    // comments — otherwise there is nothing to revert.
    canRestore() {
      return !!this.review?.adjudicated_at;
    },
    // All admin actions require a non-blank audit comment (server enforces).
    // Hard-delete additionally requires the typed-id confirmation to match
    // the review ID exactly — typo-resistant safeguard for an irreversible op.
    // Move-to-rule additionally requires a target rule chosen via RulePicker.
    canSubmitAdminAction() {
      if (!this.adminAction || this.adminAuditComment.trim().length === 0) return false;
      if (this.adminAction === "hard-delete") {
        return this.adminConfirmationId === String(this.review?.id);
      }
      if (this.adminAction === "move-to-rule") {
        return this.adminTargetRuleId !== null && this.adminTargetRuleId !== undefined;
      }
      return true;
    },
    // Confirm-button variant per action — red for hard-delete to reinforce
    // the irreversible nature; warning for force-withdraw; primary otherwise.
    adminConfirmVariant() {
      switch (this.adminAction) {
        case "hard-delete":
          return "danger";
        case "force-withdraw":
          return "warning";
        default:
          return "primary";
      }
    },
    adminConfirmLabel() {
      switch (this.adminAction) {
        case "hard-delete":
          return "hard-delete";
        case "force-withdraw":
          return "force-withdraw";
        case "restore":
          return "restore";
        case "move-to-rule":
          return "move";
        default:
          return "";
      }
    },
    // Contextual placeholder for the audit-comment textarea.
    adminActionPrompt() {
      switch (this.adminAction) {
        case "force-withdraw":
          return "Reason for force-withdraw (audit log) — e.g. spam, PII, policy violation...";
        case "restore":
          return "Reason for restore (audit log) — e.g. force-withdrew the wrong comment...";
        case "hard-delete":
          return "Documented reason for irreversible hard-delete (audit log) — required.";
        case "move-to-rule":
          return "Reason for moving this comment (audit log) — e.g. posted on the wrong rule...";
        default:
          return "";
      }
    },
    // PR-717 Task 30 — gate the Edit section affordance to author+ users.
    // Server enforces the same gate (authorize_author_project), so this is
    // purely UI hiding. Viewers + commenters see the section badge but no
    // edit affordance.
    canEditSection() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    // Reuse the same option shape as CommentComposerModal so the picker
    // surfaces an identical menu when retagging post-creation.
    sectionOptions() {
      return [
        { value: null, text: "(general)" },
        ...Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text })),
      ];
    },
    // Server requires audit_comment for any section change (422 if blank).
    canSubmitSectionChange() {
      return this.sectionAuditComment.trim().length > 0;
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
    onDuplicateSelected(reviewId) {
      this.duplicateOfId = reviewId;
    },
    onTargetRuleSelected(ruleId) {
      this.adminTargetRuleId = ruleId;
    },
    // PR-717 Task 25 — close the admin-action sub-form without resetting
    // the disclosure (so the user can choose a different admin action).
    cancelAdminAction() {
      this.adminAction = null;
      this.adminAuditComment = "";
      this.adminConfirmationId = "";
      this.adminTargetRuleId = null;
    },
    // PR-717 Task 30 — open the section-edit sub-form, seeded with the
    // current value so re-saving with no change is detected as no-op
    // by the server (idempotent path returns 200 with no audit record).
    enterSectionEdit() {
      this.newSection = this.review?.section ?? null;
      this.sectionAuditComment = "";
      this.sectionEditMode = true;
    },
    cancelSectionEdit() {
      this.sectionEditMode = false;
      this.newSection = null;
      this.sectionAuditComment = "";
    },
    async submitSectionChange() {
      if (!this.review || !this.canSubmitSectionChange) return;
      try {
        const res = await axios.patch(`/reviews/${this.review.id}/section`, {
          section: this.newSection,
          audit_comment: this.sectionAuditComment.trim(),
        });
        this.$emit("triaged", res.data.review);
        this.cancelSectionEdit();
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    // PR-717 Task 25 + 25b — dispatch the right endpoint for the chosen
    // admin action. Emits 'triaged' on patch operations so the parent
    // table refreshes, or 'destroyed' on hard-delete so the parent can
    // remove the row entirely. All paths reset state and close the modal.
    async submitAdminAction() {
      if (!this.review || !this.canSubmitAdminAction) return;
      const reviewId = this.review.id;
      const auditComment = this.adminAuditComment.trim();
      try {
        if (this.adminAction === "hard-delete") {
          await axios.delete(`/reviews/${reviewId}/admin_destroy`, {
            data: { audit_comment: auditComment },
          });
          this.$emit("destroyed", reviewId);
        } else if (this.adminAction === "move-to-rule") {
          const res = await axios.patch(`/reviews/${reviewId}/move_to_rule`, {
            rule_id: this.adminTargetRuleId,
            audit_comment: auditComment,
          });
          this.$emit("triaged", res.data.review);
        } else {
          const endpoint =
            this.adminAction === "force-withdraw" ? "admin_withdraw" : "admin_restore";
          const res = await axios.patch(`/reviews/${reviewId}/${endpoint}`, {
            audit_comment: auditComment,
          });
          this.$emit("triaged", res.data.review);
        }
        this.cancelAdminAction();
        this.adminActionsOpen = false;
        this.$bvModal.hide("comment-triage-modal");
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
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
