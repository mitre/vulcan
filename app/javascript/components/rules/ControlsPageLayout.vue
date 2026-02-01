<template>
  <div class="controls-page-layout">
    <!-- Command Bar - Full Width -->
    <template v-if="showCommandBar">
      <slot name="command-bar" />
    </template>

    <!-- Filter Bar - Full Width -->
    <template v-if="showFilterBar">
      <slot name="filter-bar" />
    </template>

    <!-- Two-Column Layout -->
    <div class="row">
      <!-- Left Sidebar -->
      <div :class="['left-sidebar-column', 'pr-0', sidebarColumnClass]">
        <slot name="left-sidebar" />
      </div>

      <!-- Main Content -->
      <template v-if="hasSelectedRule">
        <div :class="['main-content-column', 'mb-5', mainColumnClass]">
          <slot name="main-content" />
        </div>
      </template>

      <!-- Empty State -->
      <template v-else>
        <div :class="['main-content-column', mainColumnClass]">
          <p class="text-center text-muted mt-4">
            No control currently selected. {{ emptyStateMessage }}
          </p>
        </div>
      </template>
    </div>

    <!-- Modals - Always rendered -->
    <slot name="modals" />

    <!-- Right Panels (Slideovers) - Always rendered -->
    <slot name="right-panels" />
  </div>
</template>

<script>
export default {
  name: "ControlsPageLayout",
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
    sidebarColumnClass() {
      // Mobile: full width, Desktop: configured width
      return `col-12 col-md-${this.sidebarWidth}`;
    },
    mainColumnClass() {
      // Mobile: full width, Desktop: remaining width
      return `col-12 col-md-${12 - this.sidebarWidth}`;
    },
  },
};
</script>

<style scoped>
.controls-page-layout {
  /* Container for the entire controls page */
}

/* Ensure left sidebar has no right padding for flush edges */
.left-sidebar-column {
  padding-right: 0;
}
</style>
