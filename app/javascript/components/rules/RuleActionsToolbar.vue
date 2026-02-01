<template>
  <div class="rule-actions-toolbar mb-3">
    <b-button-group size="sm">
      <!-- Clone -->
      <b-button variant="outline-info" :disabled="readOnly" @click="$emit('clone')">
        <b-icon icon="files" /> Clone
      </b-button>
      <!-- Delete (admin only) -->
      <b-button
        v-if="effectivePermissions === 'admin'"
        variant="outline-danger"
        :disabled="isReadOnly"
        @click="$emit('delete')"
      >
        <b-icon icon="trash" /> Delete
      </b-button>
      <!-- Save -->
      <CommentModal
        title="Save Control"
        message="Provide a comment that summarizes your changes to this control."
        :require-non-empty="true"
        button-text="Save"
        button-icon="save"
        button-variant="outline-success"
        button-size="sm"
        :button-disabled="isReadOnly"
        wrapper-class="d-inline-block"
        @comment="$emit('save', $event)"
      />
      <!-- Comment -->
      <CommentModal
        title="Comment"
        message="Submit general feedback on the control"
        :require-non-empty="true"
        button-text="Comment"
        button-icon="chat-left-text"
        button-variant="outline-secondary"
        button-size="sm"
        :button-disabled="false"
        wrapper-class="d-inline-block"
        @comment="$emit('comment', $event)"
      />
      <!-- Review -->
      <b-button variant="outline-primary" size="sm" :disabled="readOnly" @click="$emit('open-review-modal')">
        <b-icon icon="clipboard-check" /> Review
      </b-button>
      <!-- Lock/Unlock (admin only) -->
      <template v-if="effectivePermissions === 'admin'">
        <CommentModal
          v-if="rule.locked"
          title="Unlock Control"
          message="Provide a reason for unlocking this control."
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
          title="Lock Control"
          message="Provide a reason for locking this control."
          :require-non-empty="true"
          button-text="Lock"
          button-icon="lock"
          button-variant="outline-dark"
          button-size="sm"
          :button-disabled="readOnly || isUnderReview"
          wrapper-class="d-inline-block"
          @comment="$emit('lock', $event)"
        />
      </template>
    </b-button-group>
  </div>
</template>

<script>
import CommentModal from "../shared/CommentModal.vue";

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
  padding: 0.5rem;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.375rem;
  text-align: center;
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
