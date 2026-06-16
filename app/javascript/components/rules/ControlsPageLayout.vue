<template>
  <div class="controls-page-layout vulcan-editor-layout">
    <!-- Command Bar - Fixed at top, never scrolls -->
    <div v-if="showCommandBar" class="flex-shrink-0">
      <slot name="command-bar" />
    </div>

    <!-- Filter Bar - Fixed below command bar, never scrolls -->
    <div v-if="showFilterBar" class="filter-bar-wrapper flex-shrink-0 mb-3">
      <slot name="filter-bar" />
    </div>

    <!-- Two-Column Layout — fills remaining viewport, each panel scrolls independently -->
    <PanelLayout :panels="layoutPanels" class="flex-grow-1 overflow-hidden">
      <!-- Sidebar pinned header (search, filter, open rules) -->
      <template v-if="$slots['left-sidebar-header']" #left-header>
        <slot name="left-sidebar-header" />
      </template>

      <!-- Sidebar scrollable body (all rules list) -->
      <template #left>
        <slot name="left-sidebar" />
      </template>

      <!-- Main panel pinned header (rule context, toolbar, tabs) -->
      <template v-if="$slots['main-content-header']" #center-header>
        <slot name="main-content-header" />
      </template>

      <!-- Main panel scrollable body (rule editor fields) -->
      <template #center>
        <template v-if="hasSelectedRule">
          <slot name="main-content" />
        </template>
        <div
          v-else
          class="empty-state d-flex flex-column align-items-center justify-content-center text-muted"
        >
          <b-icon icon="file-earmark-text" font-scale="3" class="mb-3" />
          <p class="mb-1 font-weight-bold">No control currently selected</p>
          <p class="small mb-0">{{ emptyStateMessage }}</p>
        </div>
      </template>
    </PanelLayout>

    <!-- Modals - Always rendered -->
    <slot name="modals" />

    <!-- Right Panels (Slideovers) - Always rendered -->
    <slot name="right-panels" />
  </div>
</template>

<script>
import PanelLayout from "../shared/PanelLayout.vue";

export default {
  name: "ControlsPageLayout",
  components: { PanelLayout },
  props: {
    hasSelectedRule: {
      type: Boolean,
      default: false,
    },
    showCommandBar: {
      type: Boolean,
      default: false,
    },
    showFilterBar: {
      type: Boolean,
      default: false,
    },
    sidebarWidth: {
      type: Number,
      default: 2,
      validator: (value) => value >= 1 && value <= 6,
    },
    emptyStateMessage: {
      type: String,
      default: "Select a control on the left to view or edit.",
    },
  },
  computed: {
    layoutPanels() {
      return [
        { name: "left", cols: this.sidebarWidth, bgTier: "secondary" },
        { name: "center", cols: 12 - this.sidebarWidth, bgTier: "body" },
      ];
    },
  },
};
</script>

<style scoped>
.empty-state {
  min-height: 50vh;
}
</style>
