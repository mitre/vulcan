<template>
  <BaseCommandBar>
    <!-- Left: Actions (Edit/View, Members, Release) -->
    <template #left>
      <!-- VIEW mode: Show Edit button -->
      <b-button
        v-if="readOnly && canEdit"
        variant="primary"
        size="sm"
        class="mr-2"
        :href="`/components/${component.id}/edit`"
      >
        <b-icon icon="pencil" /> Edit
      </b-button>
      <!-- EDIT mode: Show View button -->
      <b-button
        v-if="!readOnly && canEdit"
        variant="outline-primary"
        size="sm"
        class="mr-2"
        :href="`/components/${component.id}`"
      >
        <b-icon icon="eye" /> View
      </b-button>

      <!-- Release Button (with tooltip for disabled state) -->
      <span v-if="canRelease" v-b-tooltip.hover :title="releaseComponentTooltip" class="mr-2">
        <b-button variant="outline-success" size="sm" :disabled="!isReleasable" @click="onRelease">
          <b-icon icon="patch-check" /> Release
        </b-button>
      </span>

      <!-- Download Button — opens the unified ExportModal in the parent.
           Available to anyone with component access (gates within the modal
           cover format-/mode-specific role restrictions). PR-717 Step 5 closed
           the per-component-editor "where do I click" gap with this. -->
      <b-button
        variant="outline-secondary"
        size="sm"
        class="mr-2"
        data-testid="download-btn"
        @click="$emit('download')"
      >
        <b-icon icon="download" /> Download
      </b-button>

      <!-- Update from Spreadsheet (author+ only) -->
      <UpdateFromSpreadsheetModal
        v-if="canEdit"
        :component="component"
        @spreadsheet-updated="onSpreadsheetUpdated"
      />
    </template>

    <!-- Right: Panel Toggles -->
    <template #right>
      <!-- Component Panels (component-level info, always available) -->
      <b-button-group size="sm">
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
        <!-- Triage navigates to the dedicated full-page triage view
             (the comp-reviews slideover was retired in PR #717). -->
        <b-button :href="`/components/${component.id}/triage`" variant="outline-secondary">
          <b-icon icon="chat-left-text" /> Triage
        </b-button>
        <!-- Component Settings — admin-only dedicated page for typed
             configuration (Identity, PoC, Public Comment Period).
             Replaces the "Update Details" button that lived inside
             the Details slideover. -->
        <b-button
          v-if="canAdmin"
          :href="`/components/${component.id}/settings`"
          variant="outline-secondary"
          aria-label="Component settings"
        >
          <b-icon icon="gear" /> Settings
        </b-button>
      </b-button-group>
      <!-- Rule panels (Satisfies, History, Reviews) moved to RuleActionsToolbar -->
    </template>

    <!-- Rule Context Bar (shown when rule is selected) -->
    <template #below>
      <div v-if="hasSelectedRule" class="rule-context-bar mt-3 pt-3 pb-3 border-top">
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
    </template>
  </BaseCommandBar>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import BaseCommandBar from "./BaseCommandBar.vue";
import UpdateFromSpreadsheetModal from "../components/UpdateFromSpreadsheetModal.vue";
import { PANEL_LABELS } from "../../constants/terminology";

export default {
  name: "ControlsCommandBar",
  components: { BaseCommandBar, UpdateFromSpreadsheetModal },
  mixins: [RoleComparisonMixin, DateFormatMixinVue],
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
  data() {
    return {
      labels: PANEL_LABELS,
    };
  },
  computed: {
    canEdit() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    canAdmin() {
      return this.effectivePermissions === "admin";
    },
    canRelease() {
      return this.effectivePermissions === "admin";
    },
    isReleasable() {
      return this.component.releasable && !this.component.released;
    },
    releaseComponentTooltip() {
      if (this.component.released) {
        return "Component has already been released";
      }
      if (this.component.releasable) {
        return "Release Component";
      }
      return "All rules must be locked to release a component";
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
    onTogglePanel(panel) {
      this.$emit("toggle-panel", panel);
    },
    onSpreadsheetUpdated() {
      this.$emit("spreadsheet-updated");
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
