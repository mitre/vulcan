<template>
  <BaseCommandBar>
    <!-- Above: Breadcrumbs (inline, no separate row) -->
    <template v-if="breadcrumbs && breadcrumbs.length" #above>
      <nav aria-label="breadcrumb" data-testid="command-bar-breadcrumbs" class="mb-1">
        <ol class="breadcrumb bg-transparent p-0 mb-0 small">
          <li
            v-for="(item, i) in breadcrumbs"
            :key="i"
            class="breadcrumb-item"
            :class="{ active: item.active }"
          >
            <a v-if="!item.active && item.href" :href="item.href">{{ item.text }}</a>
            <span v-else>{{ item.text }}</span>
          </li>
        </ol>
      </nav>
    </template>

    <!-- Left: Primary actions + overflow -->
    <template #left>
      <div data-testid="toolbar-actions" class="d-inline-flex align-items-center">
        <b-button
          v-if="readOnly && canEdit"
          v-b-tooltip.hover
          title="Switch to edit mode"
          variant="primary"
          size="sm"
          class="mr-2"
          :href="`/components/${component.id}/edit`"
        >
          <b-icon icon="pencil" /> Edit
        </b-button>
        <b-button
          v-if="!readOnly && canEdit"
          v-b-tooltip.hover
          title="Switch to view mode"
          variant="outline-primary"
          size="sm"
          class="mr-2"
          :href="`/components/${component.id}`"
        >
          <b-icon icon="eye" /> View
        </b-button>
        <b-button
          v-if="canCommentOnComponent"
          v-b-tooltip.hover
          title="Post a comment on this component"
          variant="outline-secondary"
          size="sm"
          data-testid="comment-on-component-btn"
          @click="$emit('open-component-composer')"
        >
          <b-icon icon="chat-left-text" /> Comment
        </b-button>
      </div>

      <!-- Separator -->
      <span class="border-left align-self-stretch mx-2" />

      <!-- Center: Status indicator -->
      <div data-testid="toolbar-status" class="d-inline-flex align-items-center">
        <CommentStatusChip
          :component="component"
          @open-comments-panel="$emit('open-comments-panel')"
        />
      </div>
    </template>

    <!-- Right: Clear Filters + Panel Toggles -->
    <template #right>
      <b-button
        v-if="showFilterToggle && activeFilterCount > 0"
        v-b-tooltip.hover
        title="Reset all active filters"
        variant="link"
        size="sm"
        class="mr-2 text-decoration-none"
        data-testid="clear-filters-btn"
        @click="$emit('clear-filters')"
      >
        <b-icon icon="x-circle" /> Clear Filters
      </b-button>
      <b-button-group size="sm" data-testid="panel-toggles">
        <b-button
          v-if="showFilterToggle"
          v-b-tooltip.hover
          title="Show or hide the filter bar"
          :variant="filterBarVisible ? 'secondary' : 'outline-secondary'"
          data-testid="filter-toggle-btn"
          @click="$emit('toggle-filter-bar')"
        >
          <b-icon icon="funnel" /> Filters
          <b-badge v-if="activeFilterCount > 0" variant="warning" pill class="ml-1">
            {{ activeFilterCount }}
          </b-badge>
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Component details panel"
          :variant="isPanelActive('details') ? 'secondary' : 'outline-secondary'"
          @click="onTogglePanel('details')"
        >
          <b-icon icon="info-circle" /> {{ labels.details }}
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Component metadata panel"
          :variant="isPanelActive('metadata') ? 'secondary' : 'outline-secondary'"
          @click="onTogglePanel('metadata')"
        >
          <b-icon icon="tags" /> {{ labels.metadata }}
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Additional questions panel"
          :variant="isPanelActive('questions') ? 'secondary' : 'outline-secondary'"
          @click="onTogglePanel('questions')"
        >
          <b-icon icon="question-circle" /> {{ labels.questions }}
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Component change history"
          :variant="isPanelActive('comp-history') ? 'secondary' : 'outline-secondary'"
          @click="onTogglePanel('comp-history')"
        >
          <b-icon icon="clock-history" /> {{ labels.compHistory }}
        </b-button>
        <b-button
          v-b-tooltip.hover
          title="Open comment triage page"
          :href="`/components/${component.id}/triage`"
          variant="outline-secondary"
          data-testid="triage-btn"
        >
          <b-icon icon="chat-left-text" /> Triage
          <b-badge v-if="component.pending_comment_count > 0" variant="primary" pill class="ml-1">
            {{ component.pending_comment_count }}
          </b-badge>
        </b-button>
        <b-button
          v-if="canAdmin"
          v-b-tooltip.hover
          title="Component settings"
          :href="`/components/${component.id}/settings`"
          variant="outline-secondary"
        >
          <b-icon icon="gear" /> Settings
        </b-button>
        <b-dropdown
          v-b-tooltip.hover.bottom
          title="Download, Upload, Release"
          data-testid="toolbar-overflow"
          size="sm"
          variant="outline-secondary"
          no-caret
          right
        >
          <template #button-content>
            <b-icon icon="three-dots" />
          </template>
          <b-dropdown-item data-testid="download-btn" @click="$emit('download')">
            <b-icon icon="download" /> Download
          </b-dropdown-item>
          <b-dropdown-item v-if="canEdit" @click="openSpreadsheetUpload">
            <b-icon icon="upload" /> Update from Spreadsheet
          </b-dropdown-item>
          <b-dropdown-divider v-if="canRelease" />
          <b-dropdown-item v-if="canRelease" :disabled="!isReleasable" @click="onRelease">
            <b-icon icon="patch-check" /> Release
            <small v-if="!isReleasable" class="text-muted d-block">
              {{ releaseComponentTooltip }}
            </small>
          </b-dropdown-item>
        </b-dropdown>
      </b-button-group>
    </template>

    <!-- Hidden: UpdateFromSpreadsheetModal (triggered from overflow menu) -->
    <UpdateFromSpreadsheetModal
      v-if="canEdit"
      ref="spreadsheetModal"
      :component="component"
      class="d-none"
      @spreadsheet-updated="onSpreadsheetUpdated"
    />

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
import CommentStatusChip from "./CommentStatusChip.vue";
import UpdateFromSpreadsheetModal from "../components/UpdateFromSpreadsheetModal.vue";
import { PANEL_LABELS } from "../../constants/terminology";

export default {
  name: "ControlsCommandBar",
  components: { BaseCommandBar, CommentStatusChip, UpdateFromSpreadsheetModal },
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
    breadcrumbs: {
      type: Array,
      default: null,
    },
    showFilterToggle: {
      type: Boolean,
      default: false,
    },
    filterBarVisible: {
      type: Boolean,
      default: false,
    },
    activeFilterCount: {
      type: Number,
      default: 0,
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
    canCommentOnComponent() {
      return !!this.effectivePermissions;
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
    openSpreadsheetUpload() {
      if (this.$refs.spreadsheetModal) {
        this.$refs.spreadsheetModal.showModal();
      }
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
  border: 1px solid var(--vulcan-gray-300);
}

.command-bar > div {
  gap: 0.5rem;
}

.rule-context-bar h5 {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

@media (max-width: 1199.98px) {
  .command-bar > div {
    flex-wrap: wrap;
  }
}

@media (max-width: 767.98px) {
  .command-bar {
    padding: 0.75rem !important;
  }

  .command-bar > div > div {
    width: 100%;
    flex-wrap: wrap;
    gap: 0.5rem;
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
