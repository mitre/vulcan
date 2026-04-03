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

      <!-- Rule panels and actions moved to RuleActionsToolbar -->
    </div>
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";

export default {
  name: "RuleCommandBar",
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
  },
  computed: {
    ruleDisplayId() {
      return `${this.componentPrefix}-${this.rule.rule_id}`;
    },
    ruleUrl() {
      return `/components/${this.rule.component_id}/${this.ruleDisplayId}`;
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
