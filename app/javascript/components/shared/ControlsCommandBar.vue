<template>
  <div class="command-bar bg-light px-3 py-2">
    <!-- Main Toolbar Row -->
    <div class="d-flex align-items-center justify-content-between flex-wrap">
      <!-- Left: Actions (ordered by frequency: Edit/View, Members, Release) -->
      <div class="d-flex align-items-center">
        <b-button-group size="sm" class="mr-3">
          <!-- VIEW mode: Show Edit button -->
          <b-button
            v-if="readOnly && canEdit"
            variant="primary"
            :href="`/components/${component.id}/edit`"
          >
            <b-icon icon="pencil" /> Edit
          </b-button>
          <!-- EDIT mode: Show View button -->
          <b-button
            v-if="!readOnly && canEdit"
            variant="outline-primary"
            :href="`/components/${component.id}`"
          >
            <b-icon icon="eye" /> View
          </b-button>
          <b-button variant="outline-secondary" @click="onOpenMembers">
            <b-icon icon="people" /> Members
          </b-button>
          <b-button
            v-if="canRelease"
            variant="success"
            :disabled="!isReleasable"
            @click="onRelease"
          >
            <b-icon icon="patch-check" /> Release
          </b-button>
        </b-button-group>

        <b-form-checkbox
          v-if="canToggleAdvancedFields"
          :checked="component.advanced_fields"
          switch
          size="sm"
          @change="onToggleAdvancedFields"
        >
          Advanced
        </b-form-checkbox>
      </div>

      <!-- Right: Panel Toggles -->
      <div class="d-flex align-items-center">
        <!-- Component Panels (component-level info, always available) -->
        <b-button-group size="sm" class="mr-3">
          <b-button
            :variant="isPanelActive('details') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('details')"
          >
            <b-icon icon="info-circle" /> {{ labels.details }}
          </b-button>
          <b-button
            :variant="isPanelActive('metadata') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('metadata')"
          >
            <b-icon icon="tags" /> {{ labels.metadata }}
          </b-button>
          <b-button
            :variant="isPanelActive('questions') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('questions')"
          >
            <b-icon icon="question-circle" /> {{ labels.questions }}
          </b-button>
          <b-button
            :variant="isPanelActive('comp-history') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('comp-history')"
          >
            <b-icon icon="clock-history" /> {{ labels.compHistory }}
          </b-button>
          <b-button
            :variant="isPanelActive('comp-reviews') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('comp-reviews')"
          >
            <b-icon icon="chat-left-text" /> {{ labels.compReviews }}
          </b-button>
        </b-button-group>
        <!-- Rule panels (Satisfies, History, Reviews) moved to RuleActionsToolbar -->
      </div>
    </div>

    <!-- Rule Context Bar (shown when rule is selected) -->
    <div v-if="hasSelectedRule" class="rule-context-bar mt-2 pt-2 border-top">
      <div class="d-flex align-items-center justify-content-between">
        <div class="d-flex align-items-center">
          <h5 class="mb-0 mr-2">
            <b-icon
              v-if="selectedRule.locked"
              icon="lock"
              aria-hidden="true"
              class="text-warning"
            />
            <b-icon
              v-if="selectedRule.review_requestor_id"
              icon="file-earmark-search"
              aria-hidden="true"
              class="text-info"
            />
            <b-icon
              v-if="selectedRule.changes_requested"
              icon="exclamation-triangle"
              aria-hidden="true"
              class="text-danger"
            />
            <a class="text-dark" :href="ruleUrl">
              {{ ruleDisplayId }}
            </a>
            <small class="text-muted ml-1">// {{ selectedRule.version }}</small>
          </h5>
          <small v-if="lastEditor" class="text-muted">
            Updated {{ friendlyDateTime(selectedRule.updated_at) }} by {{ lastEditor }}
          </small>
        </div>

      </div>
    </div>
  </div>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import { PANEL_LABELS } from "../../constants/terminology";

export default {
  name: "ControlsCommandBar",
  mixins: [RoleComparisonMixin, DateFormatMixinVue],
  data() {
    return {
      labels: PANEL_LABELS,
    };
  },
  props: {
    component: {
      type: Object,
      required: true,
    },
    selectedRule: {
      type: Object,
      default: null,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    activePanel: {
      type: String,
      default: null,
    },
    readOnly: {
      type: Boolean,
      default: true,
    },
  },
  computed: {
    canEdit() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    canRelease() {
      return this.effectivePermissions === "admin";
    },
    isReleasable() {
      return this.component.releasable && !this.component.released;
    },
    canToggleAdvancedFields() {
      return this.effectivePermissions === "admin";
    },
    hasSelectedRule() {
      return !!this.selectedRule;
    },
    ruleDisplayId() {
      if (!this.selectedRule) return "";
      return `${this.component.prefix}-${this.selectedRule.rule_id}`;
    },
    ruleUrl() {
      if (!this.selectedRule) return "";
      return `/components/${this.selectedRule.component_id}/${this.ruleDisplayId}`;
    },
    lastEditor() {
      if (
        this.selectedRule &&
        this.selectedRule.histories &&
        this.selectedRule.histories.length > 0
      ) {
        return this.selectedRule.histories[0].name || null;
      }
      return null;
    },
  },
  methods: {
    isPanelActive(panel) {
      return this.activePanel === panel;
    },
    onRelease() {
      this.$emit("release");
    },
    onToggleAdvancedFields(value) {
      this.$emit("toggle-advanced-fields", value);
    },
    onOpenMembers() {
      this.$emit("open-members");
    },
    onTogglePanel(panel) {
      this.$emit("toggle-panel", panel);
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

.command-bar > div {
  gap: 0.5rem;
}

.rule-context-bar h5 {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Responsive: wrap to two rows on medium screens */
@media (max-width: 1199.98px) {
  .command-bar > div {
    flex-wrap: wrap;
  }
}

/* Responsive: stack on small screens */
@media (max-width: 767.98px) {
  .command-bar {
    padding: 0.75rem !important;
  }

  .command-bar > div > div {
    width: 100%;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .command-bar .btn-group {
    flex-wrap: wrap;
  }

  .rule-context-bar h5 {
    font-size: 1rem;
  }

  .rule-context-bar small {
    display: block;
    margin-top: 0.25rem;
  }
}
</style>
