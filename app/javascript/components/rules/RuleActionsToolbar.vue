<template>
  <div class="rule-actions-toolbar mb-3">
    <!-- Row 1: Info/Reference (read-only panels and viewing) -->
    <div class="toolbar-row">
      <span class="toolbar-label">Info</span>
      <div class="toolbar-btn-group">
        <b-button variant="outline-secondary" size="sm" @click="$emit('open-related-modal')">
          <b-icon icon="link-45deg" /> Related
        </b-button>
        <b-button variant="outline-secondary" size="sm" @click="$emit('toggle-panel', 'satisfies')">
          <b-icon icon="diagram-3" /> Satisfies
        </b-button>
        <b-button
          variant="outline-secondary"
          size="sm"
          @click="$emit('toggle-panel', 'rule-history')"
        >
          <b-icon icon="clock-history" /> History
        </b-button>
        <b-button
          variant="outline-secondary"
          size="sm"
          @click="$emit('toggle-panel', 'rule-reviews')"
        >
          <b-icon icon="chat-quote" /> Comment History
        </b-button>
        <!-- General Comment — opens the same CommentComposerModal as the
             per-section icons, with no section pre-selected (defaults to
             "(general)"). The event bubbles up to RulesCodeEditorView /
             ProjectComponent which mount the modal. -->
        <b-button
          variant="outline-secondary"
          size="sm"
          :title="commentButtonTooltip"
          :disabled="commentButtonDisabled"
          :class="{ 'opacity-65': commentButtonDisabled }"
          @click="$emit('open-composer', null)"
        >
          <b-icon icon="pencil-square" /> Comment
        </b-button>
        <b-button variant="outline-info" size="sm" href="/disa-guide" target="_blank">
          <b-icon icon="question-circle" /> DISA Guide
        </b-button>
      </div>
    </div>

    <hr class="toolbar-divider" />

    <!-- Row 2: Actions/Maintenance (state-changing operations) -->
    <div class="toolbar-row">
      <span class="toolbar-label">Actions</span>
      <div class="toolbar-btn-group">
        <b-button
          variant="outline-primary"
          size="sm"
          :disabled="readOnly"
          @click="$emit('open-review-modal')"
        >
          <b-icon icon="clipboard-check" /> Change Review Status
        </b-button>
        <CommentModal
          :title="msg.saveTitle"
          :message="msg.saveMessage"
          :require-non-empty="true"
          button-text="Save"
          button-icon="save"
          button-variant="outline-success"
          button-size="sm"
          :button-disabled="isReadOnly"
          wrapper-class="d-inline-flex"
          @comment="$emit('save', $event)"
        />
        <b-button variant="outline-info" :disabled="readOnly" @click="$emit('clone')">
          <b-icon icon="files" /> Clone
        </b-button>
      </div>
      <!-- Destructive/admin actions separated with gap -->
      <div v-if="effectivePermissions === 'admin'" class="toolbar-btn-group ml-3">
        <b-button variant="outline-danger" :disabled="isReadOnly" @click="$emit('delete')">
          <b-icon icon="trash" /> Delete
        </b-button>
        <CommentModal
          v-if="rule.locked"
          :title="msg.unlockTitle"
          :message="msg.unlockMessage"
          :require-non-empty="true"
          button-text="Unlock"
          button-icon="unlock"
          button-variant="outline-warning"
          button-size="sm"
          :button-disabled="readOnly"
          wrapper-class="d-inline-flex"
          @comment="$emit('unlock', $event)"
        />
        <CommentModal
          v-else
          :title="msg.lockTitle"
          :message="msg.lockMessage"
          :require-non-empty="true"
          button-text="Lock"
          button-icon="lock"
          button-variant="outline-dark"
          button-size="sm"
          :button-disabled="readOnly || isUnderReview"
          wrapper-class="d-inline-flex"
          @comment="$emit('lock', $event)"
        />
      </div>
    </div>
  </div>
</template>

<script>
import CommentModal from "../shared/CommentModal.vue";
import { MESSAGE_LABELS } from "../../constants/terminology";
import { commentsClosedTooltip } from "../../constants/triageVocabulary";

export default {
  name: "RuleActionsToolbar",
  components: {
    CommentModal,
  },
  // Component-level "comments closed" gate is provided by ProjectComponent
  // / RulesCodeEditorView. Default keeps tests + isolated mounts green.
  inject: {
    isCommentsClosed: { default: () => () => false },
    getClosedReason: { default: () => () => null },
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      msg: MESSAGE_LABELS,
    };
  },
  computed: {
    isReadOnly() {
      // Disabled if explicitly read-only, or rule is locked/under review
      return this.readOnly || this.rule.locked || !!this.rule.review_requestor_id;
    },
    isUnderReview() {
      return !!this.rule.review_requestor_id;
    },
    commentsClosedForComponent() {
      return this.isCommentsClosed();
    },
    // Comment button activation: locked rule blocks (rule scope) and a
    // closed comment phase blocks (component scope). The rule's own
    // status is intentionally NOT a precondition — viewers can comment
    // on a requirement before its status is set.
    commentButtonDisabled() {
      return !!this.rule.locked || this.commentsClosedForComponent;
    },
    commentButtonTooltip() {
      if (this.rule.locked) {
        return "Rule is locked — comments are closed for this rule";
      }
      if (this.commentsClosedForComponent) {
        return commentsClosedTooltip(this.getClosedReason());
      }
      return "Add a general comment on this rule";
    },
  },
};
</script>

<style scoped>
.rule-actions-toolbar {
  padding: 0.375rem 0.5rem;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.375rem;
  position: sticky;
  top: 0;
  z-index: 10;
}

/* Each row: flex with label + button groups */
.toolbar-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* Row labels */
.toolbar-label {
  font-size: 0.625rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #6c757d;
  min-width: 2.75rem;
  flex-shrink: 0;
}

/* Divider between rows */
.toolbar-divider {
  margin: 0.25rem 0;
  border: 0;
  border-top: 1px solid #dee2e6;
}

/* Individual rounded buttons with consistent spacing */
.toolbar-btn-group {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 0.25rem;
}

/* Disabled buttons should be clearly grayed out */
.rule-actions-toolbar >>> .btn:disabled,
.rule-actions-toolbar >>> .btn.disabled {
  opacity: 0.5;
  color: #6c757d !important;
  border-color: #6c757d !important;
  background-color: transparent !important;
  cursor: not-allowed;
}
</style>
