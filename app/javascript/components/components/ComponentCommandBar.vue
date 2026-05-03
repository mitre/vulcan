<template>
  <div class="command-bar bg-light px-3 py-2">
    <div class="d-flex align-items-center justify-content-between flex-wrap">
      <!-- Left: Actions -->
      <div class="d-flex align-items-center">
        <b-button-group size="sm" class="mr-3">
          <b-button v-if="editMode" variant="outline-primary" :href="`/components/${component.id}`">
            <b-icon icon="eye" /> View
          </b-button>
          <b-button
            v-else-if="canEdit"
            variant="primary"
            :href="`/components/${component.id}/edit`"
          >
            <b-icon icon="pencil" /> Edit
          </b-button>
          <b-button
            v-if="canRelease"
            variant="success"
            :disabled="!isReleasable"
            @click="onRelease"
          >
            <b-icon icon="patch-check" /> Release
          </b-button>
          <b-button variant="outline-secondary" @click="onOpenMembers">
            <b-icon icon="people" /> Members
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
        <!-- Component Panels -->
        <b-button-group size="sm" class="mr-3">
          <b-button
            :variant="isPanelActive('details') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('details')"
          >
            <b-icon icon="info-circle" /> Details
          </b-button>
          <b-button
            :variant="isPanelActive('metadata') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('metadata')"
          >
            <b-icon icon="tags" /> Metadata
          </b-button>
          <b-button
            :variant="isPanelActive('questions') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('questions')"
          >
            <b-icon icon="question-circle" /> Questions
          </b-button>
          <b-button
            :variant="isPanelActive('comp-history') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('comp-history')"
          >
            <b-icon icon="clock-history" /> History
          </b-button>
          <!-- Comments navigates to the full-page triage view. The badge
               doubles as the inline open/closed status indicator so the
               comment-period state is readable at a glance from anywhere
               on the component page. -->
          <b-button
            :href="`/components/${component.id}/triage`"
            variant="outline-secondary"
            data-testid="component-commandbar-comments"
          >
            <b-icon icon="chat-left-text" /> Comments
            <b-badge :variant="commentStatusVariant" class="ml-1">
              {{ commentStatusText }}
            </b-badge>
          </b-button>
        </b-button-group>
        <!-- Rule panels (Satisfies, History, Reviews) moved to RuleActionsToolbar -->
      </div>
    </div>
  </div>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import { commentPhaseStatusText } from "../../constants/triageVocabulary";

export default {
  name: "ComponentCommandBar",
  mixins: [RoleComparisonMixin],
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
    editMode: {
      type: Boolean,
      default: false,
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
    componentPanels() {
      return ["details", "metadata", "questions", "comp-history"];
    },
    rulePanels() {
      return ["satisfies", "rule-reviews", "rule-history"];
    },
    commentStatusText() {
      const phase = this.component.comment_phase || "open";
      return commentPhaseStatusText(phase, this.component.closed_reason);
    },
    commentStatusVariant() {
      return (this.component.comment_phase || "open") === "open" ? "success" : "secondary";
    },
  },
  methods: {
    isPanelActive(panel) {
      return this.activePanel === panel;
    },
    onEdit() {
      this.$emit("edit");
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
}
</style>
