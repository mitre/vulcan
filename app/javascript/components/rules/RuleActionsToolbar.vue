<template>
  <div class="rule-actions-toolbar mb-3">
    <!-- Row 1: Info/Reference (read-only panels and viewing) -->
    <div class="toolbar-row">
      <span class="toolbar-label">Info</span>
      <b-button-group size="sm">
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
          <b-icon icon="chat-left-text" /> Reviews
        </b-button>
        <CommentModal
          title="Comment"
          :message="msg.commentMessage"
          :require-non-empty="true"
          button-text="Comment"
          button-icon="chat-left-text"
          button-variant="outline-secondary"
          button-size="sm"
          :button-disabled="false"
          wrapper-class="d-inline-block"
          @comment="$emit('comment', $event)"
        />
        <b-button
          variant="outline-info"
          size="sm"
          href="https://vulcan.mitre.org/disa-process/"
          target="_blank"
          rel="noopener noreferrer"
        >
          <b-icon icon="question-circle" /> DISA Guide
        </b-button>
      </b-button-group>
    </div>

    <hr class="toolbar-divider" />

    <!-- Row 2: Actions/Maintenance (state-changing operations) -->
    <div class="toolbar-row">
      <span class="toolbar-label">Actions</span>
      <b-button-group size="sm">
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
          wrapper-class="d-inline-block"
          @comment="$emit('save', $event)"
        />
        <b-button variant="outline-info" :disabled="readOnly" @click="$emit('clone')">
          <b-icon icon="files" /> Clone
        </b-button>
      </b-button-group>
      <!-- Destructive/admin actions separated with gap -->
      <b-button-group v-if="effectivePermissions === 'admin'" size="sm" class="ml-3">
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
          wrapper-class="d-inline-block"
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
          wrapper-class="d-inline-block"
          @comment="$emit('lock', $event)"
        />
      </b-button-group>
    </div>
  </div>
</template>

<script>
import CommentModal from "../shared/CommentModal.vue";
import { MESSAGE_LABELS } from "../../constants/terminology";

export default {
  name: "RuleActionsToolbar",
  components: {
    CommentModal,
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
  },
};
</script>

<style scoped>
.rule-actions-toolbar {
  padding: 0.375rem 0.5rem;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.375rem;
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
