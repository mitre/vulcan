<template>
  <div class="rule-actions-toolbar mb-3">
    <!-- Row 1: Info/Reference (read-only panels and viewing) -->
    <div class="toolbar-row">
      <span class="toolbar-label">Info</span>
      <div class="toolbar-btn-group">
        <!-- Related + Satisfies are Rule-only: the related search keys
             off Rule SRG linkage (the backend 404s authored rows) and
             the backend omits satisfies data for authored rows
             entirely — absence, not a disabled state, is the design. -->
        <b-button
          v-if="!isSrg"
          v-b-tooltip.hover
          title="View related rules from other components"
          variant="outline-secondary"
          size="sm"
          @click="$emit('open-related-modal')"
        >
          <b-icon icon="link-45deg" /> Related
        </b-button>
        <b-button
          v-if="!isSrg"
          v-b-tooltip.hover
          title="Rules this control satisfies or is satisfied by"
          variant="outline-secondary"
          size="sm"
          @click="$emit('toggle-panel', 'satisfies')"
        >
          <b-icon icon="diagram-3" /> Satisfies
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Rule changelog — field-level changes"
          variant="outline-secondary"
          size="sm"
          @click="$emit('toggle-panel', 'rule-history')"
        >
          <b-icon icon="clock-history" /> {{ labels.ruleHistory }}
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Comments, reviews, and triage decisions on this rule"
          variant="outline-secondary"
          size="sm"
          @click="$emit('toggle-panel', 'rule-reviews')"
        >
          <b-icon icon="chat-quote" /> {{ labels.ruleReviews }}
        </b-button>
        <!-- General Comment — opens the same CommentComposerModal as the
             per-section icons, with no section pre-selected (defaults to
             "(general)"). The event bubbles up to RulesCodeEditorView /
             ProjectComponent which mount the modal. -->
        <b-button
          v-b-tooltip.hover
          variant="outline-secondary"
          size="sm"
          :title="commentButtonTooltip"
          :disabled="commentButtonDisabled"
          :class="{ 'opacity-65': commentButtonDisabled }"
          @click="$emit('open-composer', null)"
        >
          <b-icon icon="pencil-square" /> Comment
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Open DISA Vendor STIG Process Guide"
          variant="outline-info"
          size="sm"
          href="/disa-guide"
          target="_blank"
        >
          <b-icon icon="question-circle" /> DISA Guide
        </b-button>
        <!-- The standing per-family relocation backlog (SRG authoring) —
             a read-only panel, so it stays enabled for every role. -->
        <b-button
          v-if="isSrg"
          v-b-tooltip.hover
          title="Pending relocation markers by destination family"
          variant="outline-secondary"
          size="sm"
          @click="$emit('toggle-panel', 'relocations')"
        >
          <b-icon icon="box-arrow-in-right" /> Backlog
        </b-button>
      </div>
    </div>

    <hr class="toolbar-divider" />

    <!-- Row 2: Actions/Maintenance (state-changing operations) -->
    <div class="toolbar-row">
      <span class="toolbar-label">Actions</span>
      <div class="toolbar-btn-group">
        <b-button
          v-b-tooltip.hover
          title="Submit or change the review status"
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
          button-tooltip="Save rule with a comment"
          :button-disabled="isReadOnly"
          wrapper-class="d-inline-flex"
          @comment="$emit('save', $event)"
        />
        <!-- Clone creates a Rule — the backend rejects that on SRG-kind
             components by design (requirements come from source SRGs). -->
        <b-button
          v-if="!isSrg"
          v-b-tooltip.hover
          title="Duplicate this rule"
          variant="outline-info"
          :disabled="readOnly"
          @click="$emit('clone')"
        >
          <b-icon icon="files" /> Clone
        </b-button>
        <!-- Relocation marking is SRG authoring, source side — absent for
             STIG kind. Disabled-not-hidden within SRG kind: the wrapping
             span carries the tooltip because disabled buttons swallow
             pointer events. -->
        <span v-if="isSrg" v-b-tooltip.hover :title="relocateTooltip" data-test="relocate-tip">
          <b-button
            variant="outline-warning"
            size="sm"
            :disabled="!!pendingRelocation || readOnly"
            @click="$emit('open-relocation-modal')"
          >
            <b-icon icon="box-arrow-right" /> Relocate
          </b-button>
        </span>
      </div>
      <!-- Destructive/admin actions separated with gap -->
      <div v-if="effectivePermissions === 'admin'" class="toolbar-btn-group ml-3">
        <b-button
          v-b-tooltip.hover
          title="Permanently delete this rule"
          variant="outline-danger"
          :disabled="isReadOnly"
          @click="$emit('delete')"
        >
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
          button-tooltip="Unlock this rule for editing"
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
          button-variant="outline-secondary"
          button-size="sm"
          button-tooltip="Lock this rule to prevent edits"
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
import { MESSAGE_LABELS, PANEL_LABELS } from "../../constants/terminology";
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
      default: null,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    documentType: {
      type: String,
      default: "stig",
    },
    // The open requirement's pending relocation record, or null —
    // marking is one-per-source, so a pending marker disables the button.
    pendingRelocation: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      msg: MESSAGE_LABELS,
    };
  },
  computed: {
    isSrg() {
      return this.documentType === "srg";
    },
    relocateTooltip() {
      if (this.pendingRelocation) {
        return `Already marked for relocation to ${this.pendingRelocation.target_technology_token} — un-mark from the backlog`;
      }
      if (this.readOnly) {
        return "Requires author role";
      }
      return "Mark this requirement for relocation to another family";
    },
    isReadOnly() {
      // Disabled if explicitly read-only, or rule is locked/under review
      return this.readOnly || this.rule.locked || !!this.rule.review_requestor_id;
    },
    isUnderReview() {
      return !!this.rule.review_requestor_id;
    },
    labels() {
      return PANEL_LABELS;
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
  background-color: var(--vulcan-gray-100);
  border: 1px solid var(--vulcan-gray-300);
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
  color: var(--vulcan-secondary);
  min-width: 2.75rem;
  flex-shrink: 0;
}

/* Divider between rows */
.toolbar-divider {
  margin: 0.25rem 0;
  border: 0;
  border-top: 1px solid var(--vulcan-gray-300);
}

/* Individual rounded buttons with consistent spacing */
.toolbar-btn-group {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.toolbar-btn-group >>> .btn-sm {
  font-size: var(--vulcan-action-btn-font-size, 0.75rem);
  padding: 0.2rem 0.5rem;
  line-height: 1.5;
}

/* Disabled buttons should be clearly grayed out */
.rule-actions-toolbar >>> .btn:disabled,
.rule-actions-toolbar >>> .btn.disabled {
  opacity: 0.5;
  color: var(--vulcan-secondary) !important;
  border-color: var(--vulcan-secondary) !important;
  background-color: transparent !important;
  cursor: not-allowed;
}
</style>
