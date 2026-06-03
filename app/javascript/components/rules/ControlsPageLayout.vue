<template>
  <div class="controls-page-layout">
    <!-- Command Bar - Full Width -->
    <template v-if="showCommandBar">
      <slot name="command-bar" />
    </template>

    <!-- Filter Bar - Full Width -->
    <div v-if="showFilterBar" class="filter-bar-wrapper mb-3">
      <slot name="filter-bar" />
    </div>

    <!-- Two-Column Layout via PanelLayout -->
    <PanelLayout :panels="layoutPanels">
      <template #left>
        <slot name="left-sidebar" />
      </template>

      <template #center>
        <template v-if="hasSelectedRule">
          <slot name="main-content" />
        </template>
        <p v-else class="text-center text-muted mt-4">
          No control currently selected. {{ emptyStateMessage }}
        </p>
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
.controls-page-layout {
  /* Container for the entire controls page */
}
</style>
