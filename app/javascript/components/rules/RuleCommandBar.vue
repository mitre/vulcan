<template>
  <div class="command-bar bg-light px-3 py-2">
    <div class="d-flex align-items-center justify-content-between flex-wrap">
      <!-- Group 1: Context (left) -->
      <div class="command-group context-group d-flex align-items-center">
        <h5 class="mb-0 mr-2">
          <b-icon v-if="rule.locked" icon="lock" aria-hidden="true" class="text-warning" />
          <b-icon
            v-if="rule.review_requestor_id"
            icon="file-earmark-search"
            aria-hidden="true"
            class="text-info"
          />
          <b-icon
            v-if="rule.changes_requested"
            icon="exclamation-triangle"
            aria-hidden="true"
            class="text-danger"
          />
          <a class="text-dark" :href="ruleUrl">
            {{ ruleDisplayId }}
          </a>
          <small class="text-muted ml-1">// {{ rule.version }}</small>
        </h5>
        <small v-if="lastEditor" class="text-muted">
          Updated {{ friendlyDateTime(rule.updated_at) }} by {{ lastEditor }}
        </small>
      </div>

      <!-- Group 2: Actions -->
      <div class="command-group actions-group">
        <b-button-group size="sm">
          <!-- Clone -->
          <b-button variant="outline-info" @click="$emit('clone')">
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
            button-variant="outline-secondary"
            button-size="sm"
            :button-disabled="false"
            wrapper-class="d-inline-block"
            @comment="$emit('comment', $event)"
          />
          <!-- Review -->
          <b-button variant="outline-primary" size="sm" @click="$emit('open-review-modal')">
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
              button-variant="outline-warning"
              button-size="sm"
              :button-disabled="false"
              wrapper-class="d-inline-block"
              @comment="$emit('unlock', $event)"
            />
            <CommentModal
              v-else
              title="Lock Control"
              message="Provide a reason for locking this control."
              :require-non-empty="true"
              button-text="Lock"
              button-variant="outline-dark"
              button-size="sm"
              :button-disabled="isUnderReview"
              wrapper-class="d-inline-block"
              @comment="$emit('lock', $event)"
            />
          </template>
        </b-button-group>
      </div>

      <!-- Group 3: Panels (right) -->
      <div class="command-group panels-group">
        <b-button-group size="sm">
          <b-button variant="outline-secondary" @click="$emit('open-related-modal')">
            <b-icon icon="link-45deg" /> Related
          </b-button>
          <b-button
            :variant="activePanel === 'satisfies' ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'satisfies')"
          >
            <b-icon icon="check2-square" /> Satisfies
          </b-button>
          <b-button
            :variant="activePanel === 'reviews' ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'reviews')"
          >
            <b-icon icon="chat-left-text" /> Reviews
            <b-badge v-if="reviewCount > 0" variant="dark" pill class="ml-1 badge">
              {{ reviewCount }}
            </b-badge>
          </b-button>
          <b-button
            :variant="activePanel === 'history' ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'history')"
          >
            <b-icon icon="clock-history" /> History
          </b-button>
        </b-button-group>
      </div>
    </div>
  </div>
</template>

<script>
import CommentModal from "../shared/CommentModal.vue";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";

export default {
  name: "RuleCommandBar",
  components: {
    CommentModal,
  },
  mixins: [DateFormatMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    componentPrefix: {
      type: String,
      required: true,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    activePanel: {
      type: String,
      default: null,
    },
  },
  computed: {
    ruleDisplayId() {
      return `${this.componentPrefix}-${this.rule.rule_id}`;
    },
    ruleUrl() {
      return `/components/${this.rule.component_id}/${this.ruleDisplayId}`;
    },
    isReadOnly() {
      return this.rule.locked || !!this.rule.review_requestor_id;
    },
    isUnderReview() {
      return !!this.rule.review_requestor_id;
    },
    reviewCount() {
      return this.rule.reviews ? this.rule.reviews.length : 0;
    },
    lastEditor() {
      if (this.rule.histories && this.rule.histories.length > 0) {
        return this.rule.histories[0].name || null;
      }
      return null;
    },
  },
};
</script>

<style scoped>
.command-bar {
  position: sticky;
  top: 0;
  z-index: 100;
  border-radius: 0.375rem;
  border: 1px solid #dee2e6;
}

.command-group {
  margin: 0.25rem 0;
}

.actions-group {
  margin-left: 1rem;
}

.panels-group {
  margin-left: auto;
}

.context-group {
  min-width: 0;
  flex-shrink: 1;
}

.context-group h5 {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Responsive: Small screens (< 768px) */
@media (max-width: 767.98px) {
  .command-bar {
    padding: 0.75rem !important;
  }

  .command-bar > div {
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .context-group {
    width: 100%;
    flex-basis: 100%;
  }

  .actions-group {
    margin-left: 0;
  }

  .panels-group {
    margin-left: auto;
  }

  .actions-group >>> .btn-group,
  .panels-group >>> .btn-group {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }

  .context-group h5 {
    font-size: 1rem;
  }

  .context-group small {
    display: block;
    margin-top: 0.25rem;
  }
}

/* Responsive: Medium screens (768px - 991px) */
@media (min-width: 768px) and (max-width: 991.98px) {
  .command-bar > div {
    gap: 0.5rem;
  }
}
</style>
