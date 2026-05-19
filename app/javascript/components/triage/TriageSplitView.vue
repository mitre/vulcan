<template>
  <div class="triage-split-view">
    <TriageQueueNav :comments="sortedRows" :current-id="activeCommentId" @select="onQueueSelect" />

    <b-alert
      v-if="conflictAlert"
      variant="warning"
      show
      dismissible
      class="mt-2"
      @dismissed="conflictAlert = null"
    >
      <strong>Conflict:</strong> This comment was modified by another user since you loaded it.
      Please refresh and try again.
    </b-alert>

    <b-row v-if="activeComment" class="mt-3">
      <b-col lg="5">
        <RuleContextPanel
          :rule-content="activeComment.rule_content"
          :rule-displayed-name="activeComment.rule_displayed_name"
          :rule-status="activeComment.rule_content ? activeComment.rule_content.status : null"
          :focused-section="activeComment.section"
          :context-mode="contextMode"
          :commented-sections="commentedSections"
          :section-comment-counts="sectionCommentCounts"
          :section-comments="activeRuleComments"
          :active-comment-id="activeCommentId"
          @select-comment="onQueueSelect"
        />
      </b-col>
      <b-col lg="7">
        <div class="mb-2">
          <p class="mb-1">
            <strong>{{ activeComment.rule_displayed_name }}</strong>
            · Section:
            <SectionLabel
              :section="activeComment.section"
              :commentable-type="activeComment.commentable_type"
            />
          </p>
          <p class="mb-1 text-muted small">
            <strong>{{ activeComment.author_name || "—" }}</strong>
            · posted {{ relativeTime(activeComment.created_at) }}
          </p>
          <blockquote class="border-left pl-3 py-2 mb-2 bg-light">
            {{ activeComment.comment }}
          </blockquote>
          <ReactionButtons
            :review-id="activeComment.id"
            :reactions="activeComment.reactions || { up: 0, down: 0 }"
            @toggle="onReactionToggle"
          />
          <CommentThread
            :parent-review-id="activeComment.id"
            :responses-count="activeComment.responses_count || 0"
            :can-reply="true"
            class="mb-3"
            @reply="$emit('open-reply-composer', activeComment)"
          />
        </div>
        <CommentTriageForm
          v-if="canTriage"
          :review="activeComment"
          :component-id="componentId"
          :loading="saving"
          @save="onTriageSave"
          @save-and-next="onTriageSaveAndNext"
          @cancel="onCancel"
          @dirty="isDirty = $event"
        />
        <p v-else class="text-muted small font-italic">
          Read-only — author or higher role required to triage.
        </p>
      </b-col>
    </b-row>

    <b-sidebar
      id="sidebar-admin-actions"
      title="Admin Actions"
      right
      shadow
      backdrop
      width="400px"
      :visible="adminPanelOpen"
      @hidden="$emit('admin-panel-close')"
    >
      <div v-if="activeComment" class="px-3 py-2">
        <p class="text-muted small mb-3">
          Admin overrides are recorded in the audit log. Use sparingly.
        </p>
        <p class="small mb-3">
          Comment <strong>#{{ activeComment.id }}</strong> on
          <strong>{{ activeComment.rule_displayed_name }}</strong>
        </p>

        <div v-if="!adminAction" class="d-flex flex-column" style="gap: 0.5rem">
          <b-button
            size="sm"
            variant="outline-warning"
            data-testid="admin-action-force-withdraw"
            @click="adminAction = 'force-withdraw'"
          >
            <b-icon icon="x-octagon" /> Force-withdraw
          </b-button>
          <b-button
            v-if="canRestore"
            size="sm"
            variant="outline-secondary"
            data-testid="admin-action-restore"
            @click="adminAction = 'restore'"
          >
            <b-icon icon="arrow-counterclockwise" /> Restore
          </b-button>
          <b-button
            size="sm"
            variant="outline-secondary"
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
            v-if="adminAction === 'move-to-rule' && resolvedComponentId"
            class="mb-2"
            :component-id="resolvedComponentId"
            :exclude-rule-id="activeComment.rule_id"
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
            <label for="split-admin-confirmation-id" class="small text-muted mb-1">
              Type the comment ID
              <strong>{{ activeComment.id }}</strong>
              to confirm:
            </label>
            <b-form-input
              id="split-admin-confirmation-id"
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
    </b-sidebar>
  </div>
</template>

<script>
import axios from "axios";
import AlertMixin from "../../mixins/AlertMixin.vue";
import FormMixin from "../../mixins/FormMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import { SINGLE_BUTTON_STATUSES } from "../../constants/triageVocabulary";
import SectionLabel from "../shared/SectionLabel.vue";
import CommentThread from "../shared/CommentThread.vue";
import TriageQueueNav from "./TriageQueueNav.vue";
import RuleContextPanel from "./RuleContextPanel.vue";
import CommentTriageForm from "./CommentTriageForm.vue";
import RulePicker from "../components/RulePicker.vue";
import ReactionButtons from "../shared/ReactionButtons.vue";

export default {
  name: "TriageSplitView",
  components: {
    TriageQueueNav,
    RuleContextPanel,
    CommentTriageForm,
    CommentThread,
    SectionLabel,
    RulePicker,
    ReactionButtons,
  },
  mixins: [AlertMixin, FormMixin, RoleComparisonMixin],
  props: {
    rows: { type: Array, required: true },
    initialCommentId: { type: [Number, String], required: true },
    componentId: { type: [Number, String], required: true },
    effectivePermissions: { type: String, default: null },
    adminPanelOpen: { type: Boolean, default: false },
    contextMode: { type: String, default: "commented" },
  },
  data() {
    return {
      activeCommentId: this.initialCommentId,
      isDirty: false,
      saving: false,
      conflictAlert: null,
      adminAction: null,
      adminAuditComment: "",
      adminConfirmationId: "",
      adminTargetRuleId: null,
    };
  },
  computed: {
    sortedRows() {
      return [...this.rows].sort((a, b) => a.id - b.id);
    },
    activeComment() {
      return this.sortedRows.find((r) => r.id === this.activeCommentId) || null;
    },
    canTriage() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    activeRuleComments() {
      if (!this.activeComment) return [];
      return this.sortedRows.filter(
        (r) => r.rule_id === this.activeComment.rule_id && !r.responding_to_review_id,
      );
    },
    commentedSections() {
      return new Set(this.activeRuleComments.map((r) => r.section).filter(Boolean));
    },
    sectionCommentCounts() {
      const counts = {};
      for (const r of this.activeRuleComments) {
        if (r.section) counts[r.section] = (counts[r.section] || 0) + 1;
      }
      return counts;
    },
    canAdminAct() {
      return this.effectivePermissions === "admin";
    },
    canRestore() {
      return !!this.activeComment?.adjudicated_at;
    },
    resolvedComponentId() {
      return this.componentId || this.activeComment?.component_id || null;
    },
    canSubmitAdminAction() {
      if (!this.adminAction || this.adminAuditComment.trim().length === 0) return false;
      if (this.adminAction === "hard-delete") {
        return this.adminConfirmationId === String(this.activeComment?.id);
      }
      if (this.adminAction === "move-to-rule") {
        return this.adminTargetRuleId !== null && this.adminTargetRuleId !== undefined;
      }
      return true;
    },
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
    adminActionPrompt() {
      switch (this.adminAction) {
        case "force-withdraw":
          return "Reason for force-withdraw (audit log)...";
        case "restore":
          return "Reason for restore (audit log)...";
        case "hard-delete":
          return "Documented reason for hard-delete (audit log) — required.";
        case "move-to-rule":
          return "Reason for moving this comment (audit log)...";
        default:
          return "";
      }
    },
  },
  watch: {
    activeComment(val) {
      if (!val) {
        this.$emit("exit");
      }
    },
  },
  methods: {
    relativeTime(iso) {
      if (!iso) return "";
      return new Date(iso).toLocaleString();
    },
    onQueueSelect(id) {
      if (this.isDirty) {
        if (!window.confirm("You have unsaved changes. Switch anyway?")) return;
      }
      this.activeCommentId = id;
      this.isDirty = false;
      this.conflictAlert = null;
    },
    async onTriageSave(decision) {
      await this.doSave(decision, false);
    },
    async onTriageSaveAndNext(decision) {
      await this.doSave(decision, true);
    },
    async doSave(decision, advance) {
      if (!this.activeComment) return;
      this.saving = true;
      this.conflictAlert = null;
      try {
        const payload = {
          triage_status: decision.triage_status,
          expected_updated_at: this.activeComment.updated_at,
        };
        if (decision.response_comment) {
          payload.response_comment = decision.response_comment;
        }
        if (decision.triage_status === "duplicate") {
          payload.duplicate_of_review_id = decision.duplicate_of_review_id;
        }

        const triageRes = await axios.patch(`/reviews/${this.activeComment.id}/triage`, payload);
        this.$emit("triaged", triageRes.data.review);

        if (triageRes.data.response_review) {
          this.$emit("response-posted", {
            parentId: this.activeComment.id,
            responseReview: triageRes.data.response_review,
          });
        }

        if (!SINGLE_BUTTON_STATUSES.has(decision.triage_status)) {
          const adjRes = await axios.patch(`/reviews/${this.activeComment.id}/adjudicate`, {});
          this.$emit("adjudicated", adjRes.data.review);
        }

        this.isDirty = false;

        if (advance) {
          this.advanceToNext();
        }
      } catch (error) {
        if (error.response?.status === 409) {
          this.conflictAlert = true;
        } else {
          this.alertOrNotifyResponse(error);
        }
      } finally {
        this.saving = false;
      }
    },
    advanceToNext() {
      const idx = this.sortedRows.findIndex((r) => r.id === this.activeCommentId);
      if (idx >= 0 && idx < this.sortedRows.length - 1) {
        this.activeCommentId = this.sortedRows[idx + 1].id;
      }
    },
    onCancel() {
      this.$emit("exit");
    },
    async onReactionToggle(kind) {
      if (!this.activeComment) return;
      try {
        await axios.post(
          `/reviews/${this.activeComment.id}/reactions`,
          { kind },
          { headers: { Accept: "application/json" } },
        );
        this.$emit("refresh");
      } catch (err) {
        this.showAlert("danger", "Reaction failed", err?.response?.data?.error || "Unknown error");
      }
    },
    onTargetRuleSelected(ruleId) {
      this.adminTargetRuleId = ruleId;
    },
    cancelAdminAction() {
      this.adminAction = null;
      this.adminAuditComment = "";
      this.adminConfirmationId = "";
      this.adminTargetRuleId = null;
    },
    async submitAdminAction() {
      if (!this.activeComment || !this.canSubmitAdminAction) return;
      const reviewId = this.activeComment.id;
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
        this.$emit("admin-panel-close");
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
  },
};
</script>
