<template>
  <div class="triage-split-view">
    <b-alert
      v-if="conflictAlert"
      variant="warning"
      show
      dismissible
      class="mt-2 mb-2"
      @dismissed="conflictAlert = null"
    >
      <strong>Conflict:</strong> This comment was modified by another user since you loaded it.
      Please refresh and try again.
    </b-alert>

    <div v-if="activeComment" class="skip-links">
      <a href="#triage-content" class="skip-link sr-only sr-only-focusable">Skip to content</a>
      <a href="#triage-form" class="skip-link sr-only sr-only-focusable">Skip to triage form</a>
    </div>

    <TriageQueueNav
      v-if="activeComment"
      :comments="sortedRows"
      :current-id="activeCommentId"
      class="mb-2"
      @select="onQueueSelect"
    />

    <hr v-if="activeComment" class="mt-1 mb-2" data-testid="nav-separator" />
    <b-row v-if="activeComment" class="triage-columns">
      <b-col lg="2" class="triage-col triage-panel triage-panel--sidebar">
        <nav aria-label="Comment triage queue" class="h-100">
          <TriageRuleSidebar
            :comments="sortedRows"
            :current-id="activeCommentId"
            @select="onQueueSelect"
          />
        </nav>
      </b-col>
      <b-col
        id="triage-content"
        lg="5"
        class="triage-col triage-panel triage-panel--content"
        role="main"
        aria-label="Comment details"
      >
        <h6 ref="contentHeading" tabindex="-1" class="sr-only" data-testid="content-heading">
          {{ activeComment.rule_displayed_name }} — {{ activeComment.section || "Overall" }}
        </h6>
        <RuleContextPanel
          :rule-content="activeComment.rule_content"
          :rule-displayed-name="activeComment.rule_displayed_name"
          :parent-rule-displayed-name="activeComment.parent_rule_displayed_name"
          :rule-status="activeComment.rule_content ? activeComment.rule_content.status : null"
          :focused-section="activeComment.section"
          :context-mode="contextMode"
          :commented-sections="commentedSections"
          :section-comment-counts="sectionCommentCounts"
          @update:contextMode="$emit('update:contextMode', $event)"
        />
      </b-col>
      <b-col
        id="triage-form"
        lg="5"
        class="triage-col triage-panel triage-panel--form"
        role="complementary"
        aria-label="Triage decision"
      >
        <div class="mb-2">
          <p class="mb-1">
            <strong>{{ activeComment.rule_displayed_name }}</strong>
            · Section:
            <SectionLabel
              :section="activeComment.section"
              :commentable-type="activeComment.commentable_type"
            />
          </p>
          <div class="mb-1">
            <CommentAuthorLine
              :name="activeComment.author_name"
              :commenter-display-name="activeComment.commenter_display_name"
              :email="activeComment.author_email"
              :date="activeComment.created_at"
              layout="block"
            />
            <b-badge
              v-if="isContentStale"
              variant="warning"
              pill
              class="ml-0 mt-1"
              data-testid="staleness-badge"
            >
              Section updated since this comment
            </b-badge>
          </div>
          <hr class="mt-1 mb-2" data-testid="comment-divider" />
          <blockquote
            class="border-left pl-3 py-2 mb-2 bg-light"
            :class="triageBgClass(activeComment.triage_status)"
          >
            <template v-if="activeComment.comment && activeComment.comment.length > 200">
              {{
                commentExpanded
                  ? activeComment.comment
                  : activeComment.comment.substring(0, 200) + "…"
              }}
              <a
                href="#"
                class="text-primary ml-1"
                @click.prevent="commentExpanded = !commentExpanded"
              >
                {{ commentExpanded ? "show less" : "show more" }}
              </a>
            </template>
            <template v-else>{{ activeComment.comment }}</template>
          </blockquote>
          <ReactionButtons
            :review-id="activeComment.id"
            :reactions="activeComment.reactions || { up: 0, down: 0 }"
            @toggle="onReactionToggle"
          />
          <CommentThread
            :parent-review-id="activeComment.id"
            :parent-triage-status="activeComment.triage_status"
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
        >
          <template v-if="canAdminAct" #actions-left>
            <b-dropdown
              size="sm"
              variant="outline-secondary"
              data-testid="admin-actions-inline"
              no-caret
            >
              <template #button-content> <b-icon icon="shield-lock" /> Admin </template>
              <b-dropdown-item
                data-testid="admin-action-force-withdraw"
                @click="adminAction = 'force-withdraw'"
              >
                <b-icon icon="x-octagon" class="text-warning" /> Force-withdraw
              </b-dropdown-item>
              <b-dropdown-item
                v-if="canRestore"
                data-testid="admin-action-restore"
                @click="adminAction = 'restore'"
              >
                <b-icon icon="arrow-counterclockwise" /> Restore
              </b-dropdown-item>
              <b-dropdown-item
                data-testid="admin-action-move-to-rule"
                @click="adminAction = 'move-to-rule'"
              >
                <b-icon icon="arrow-right-square" /> Move to rule
              </b-dropdown-item>
              <b-dropdown-divider />
              <b-dropdown-item
                data-testid="admin-action-hard-delete"
                @click="adminAction = 'hard-delete'"
              >
                <b-icon icon="trash" class="text-danger" /> Hard-delete
              </b-dropdown-item>
            </b-dropdown>
          </template>
        </CommentTriageForm>
        <p v-else class="text-muted small font-italic">
          Read-only — author or higher role required to triage.
        </p>

        <!-- Admin action confirmation (expands below when an action is selected) -->
        <div v-if="canAdminAct && adminAction" class="mt-2 p-2 border rounded bg-light">
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
              @click="doSubmitAdminAction"
            >
              Confirm {{ adminConfirmLabel }}
            </b-button>
          </div>
        </div>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import AlertMixin from "../../mixins/AlertMixin.vue";
import FormMixin from "../../mixins/FormMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import { SINGLE_BUTTON_STATUSES } from "../../constants/triageVocabulary";
import { submitTriage, submitAdjudicate, submitAdminAction } from "../../services/triageService";
import SectionLabel from "../shared/SectionLabel.vue";
import CommentThread from "../shared/CommentThread.vue";
import TriageRuleSidebar from "./TriageRuleSidebar.vue";
import TriageQueueNav from "./TriageQueueNav.vue";
import RuleContextPanel from "./RuleContextPanel.vue";
import CommentTriageForm from "./CommentTriageForm.vue";
import RulePicker from "../components/RulePicker.vue";
import ReactionButtons from "../shared/ReactionButtons.vue";
import CommentAuthorLine from "../shared/CommentAuthorLine.vue";
import ReactionToggleMixin from "../../mixins/ReactionToggleMixin.vue";
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import { triageBgClass } from "../../utils/triageBgClass";
import { compareBySectionOrder } from "../../utils/sectionSortOrder";

export default {
  name: "TriageSplitView",
  components: {
    TriageRuleSidebar,
    TriageQueueNav,
    RuleContextPanel,
    CommentTriageForm,
    CommentThread,
    SectionLabel,
    RulePicker,
    ReactionButtons,
    CommentAuthorLine,
  },
  mixins: [AlertMixin, FormMixin, RoleComparisonMixin, ReactionToggleMixin, DateFormatMixin],
  props: {
    rows: { type: Array, required: true },
    initialCommentId: { type: [Number, String], default: null },
    componentId: { type: [Number, String], required: true },
    effectivePermissions: { type: String, default: null },
    adminPanelOpen: { type: Boolean, default: false },
    contextMode: { type: String, default: "commented" },
  },
  data() {
    return {
      activeCommentId: this.initialCommentId != null ? Number(this.initialCommentId) : null,
      isDirty: false,
      saving: false,
      conflictAlert: null,
      adminAction: null,
      adminAuditComment: "",
      adminConfirmationId: "",
      adminTargetRuleId: null,
      commentExpanded: false,
    };
  },
  computed: {
    sortedRows() {
      return [...this.rows].sort((a, b) => {
        const groupA = a.group_rule_displayed_name || a.rule_displayed_name || "(component)";
        const groupB = b.group_rule_displayed_name || b.rule_displayed_name || "(component)";
        if (groupA !== groupB) {
          if (groupA === "(component)") return -1;
          if (groupB === "(component)") return 1;
          const cmp = groupA.localeCompare(groupB, undefined, { numeric: true });
          if (cmp !== 0) return cmp;
        }
        return compareBySectionOrder(a, b);
      });
    },
    activeComment() {
      return this.sortedRows.find((r) => r.id === this.activeCommentId) || null;
    },
    canTriage() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    isContentStale() {
      if (!this.activeComment?.rule_content?.rule_updated_at) return false;
      return (
        new Date(this.activeComment.rule_content.rule_updated_at) >
        new Date(this.activeComment.created_at)
      );
    },
    activeRuleComments() {
      if (!this.activeComment) return [];
      return this.sortedRows.filter(
        (r) => r.rule_id === this.activeComment.rule_id && !r.responding_to_review_id,
      );
    },
    commentedSections() {
      return [...new Set(this.activeRuleComments.map((r) => r.section).filter(Boolean))];
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
    activeCommentId() {
      this.commentExpanded = false;
    },
    activeComment(val) {
      if (!val && this.sortedRows.length === 0) {
        this.$emit("exit");
      } else if (!val && this.sortedRows.length > 0) {
        this.activeCommentId = this.sortedRows[0].id;
        this.$nextTick(() => this.focusContentHeading());
      }
    },
  },
  mounted() {
    this.$nextTick(() => this.focusContentHeading());
  },
  methods: {
    focusContentHeading() {
      const el = this.$refs.contentHeading;
      if (el && el.focus) el.focus();
    },
    triageBgClass,
    onQueueSelect(id) {
      if (this.isDirty) {
        if (!window.confirm("You have unsaved changes. Switch anyway?")) return;
      }
      this.activeCommentId = Number(id);
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
        if (decision.triage_status === "addressed_by") {
          payload.addressed_by_rule_id = decision.addressed_by_rule_id;
        }

        const triageRes = await submitTriage(this.activeComment.id, payload);
        this.$emit("triaged", triageRes.data.review);

        if (triageRes.data.response_review) {
          this.$emit("response-posted", {
            parentId: this.activeComment.id,
            responseReview: triageRes.data.response_review,
          });
        }

        if (advance && !SINGLE_BUTTON_STATUSES.has(decision.triage_status)) {
          const adjRes = await submitAdjudicate(this.activeComment.id);
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
        this.$nextTick(() => this.focusContentHeading());
      }
    },
    onCancel() {
      this.$emit("exit");
    },
    onReactionToggle(kind) {
      if (!this.activeComment) return;
      const reviewId = this.activeComment.id;
      const prev = { ...this.activeComment.reactions };
      const apply = (reactions) => {
        this.$emit("reaction-updated", { id: reviewId, reactions });
      };
      this.submitReactionToggle({ reviewId, prev, kind, apply });
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
    async doSubmitAdminAction() {
      if (!this.activeComment || !this.canSubmitAdminAction) return;
      const reviewId = this.activeComment.id;
      const auditComment = this.adminAuditComment.trim();
      try {
        const params = { audit_comment: auditComment };
        if (this.adminAction === "move-to-rule") params.rule_id = this.adminTargetRuleId;

        const res = await submitAdminAction(reviewId, this.adminAction, params);

        if (this.adminAction === "hard-delete") {
          this.$emit("destroyed", reviewId);
        } else {
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

<style scoped>
.triage-col {
  overflow-y: auto;
}

/* ── Shared panel base ─────────────────────────────────────────────
   ONE class for padding + overflow on all three panes.
   Modifiers add border + background per the three-tier hierarchy. */
.triage-panel {
  padding: 0.75rem 1rem;
}

.triage-panel--sidebar {
  background-color: var(--vulcan-secondary-bg, var(--vulcan-component-bg));
  border-right: 1px solid var(--vulcan-border-color);
  padding-right: 0.5rem;
}

.triage-panel--content {
  /* body-bg — inherited, no override needed */
}

.triage-panel--form {
  background-color: var(--vulcan-tertiary-bg, var(--vulcan-component-bg-alt));
  border-left: 1px solid var(--vulcan-border-color);
}

@media (min-width: 992px) {
  .triage-columns {
    /* 320px = navbar ~56px + breadcrumb ~40px + page header ~60px
       + progress bar ~50px + filters ~40px + nav bar ~40px + margins ~34px */
    height: calc(100vh - 320px);
    min-height: 400px;
  }

  .triage-col {
    height: 100%;
  }
}
</style>
