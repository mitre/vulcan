<template>
  <div class="command-bar bg-light px-3 py-2">
    <div class="d-flex align-items-center justify-content-between flex-wrap">
      <!-- Left: Actions -->
      <div class="d-flex align-items-center">
        <b-button-group size="sm" class="mr-3">
          <b-button v-if="canEdit" variant="primary" :href="`/components/${component.id}/edit`">
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
          <b-button
            :variant="isPanelActive('comp-reviews') ? 'secondary' : 'outline-secondary'"
            @click="onTogglePanel('comp-reviews')"
          >
            <b-icon icon="chat-left-text" /> Reviews
          </b-button>
        </b-button-group>

        <!-- Rule Panels (disabled when no rule selected) -->
        <b-button-group size="sm">
          <b-button
            :variant="isPanelActive('satisfies') ? 'secondary' : 'outline-secondary'"
            :disabled="!hasSelectedRule"
            @click="onTogglePanel('satisfies')"
          >
            <b-icon icon="check2-square" /> Satisfies
          </b-button>
          <b-button
            :variant="isPanelActive('reviews') ? 'secondary' : 'outline-secondary'"
            :disabled="!hasSelectedRule"
            @click="onTogglePanel('reviews')"
          >
            <b-icon icon="chat-left-text" /> Reviews
          </b-button>
          <b-button
            :variant="isPanelActive('history') ? 'secondary' : 'outline-secondary'"
            :disabled="!hasSelectedRule"
            @click="onTogglePanel('history')"
          >
            <b-icon icon="clock-history" /> History
          </b-button>
        </b-button-group>
      </div>
    </div>
  </div>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";

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
      return ["details", "metadata", "questions", "comp-history", "comp-reviews"];
    },
    rulePanels() {
      return ["satisfies", "reviews", "history"];
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
