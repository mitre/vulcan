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
          :rule-status="activeComment.rule_content ? activeComment.rule_content.status : null"
          :focused-section="activeComment.section"
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

export default {
  name: "TriageSplitView",
  components: { TriageQueueNav, RuleContextPanel, CommentTriageForm, CommentThread, SectionLabel },
  mixins: [AlertMixin, FormMixin, RoleComparisonMixin],
  props: {
    rows: { type: Array, required: true },
    initialCommentId: { type: [Number, String], required: true },
    componentId: { type: [Number, String], required: true },
    effectivePermissions: { type: String, default: null },
  },
  data() {
    return {
      activeCommentId: this.initialCommentId,
      isDirty: false,
      saving: false,
      conflictAlert: null,
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
  },
};
</script>
