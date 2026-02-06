<template>
  <div class="command-bar bg-light px-3 py-2 mb-3">
    <div class="d-flex align-items-center justify-content-between flex-wrap">
      <!-- Left: Page-specific actions -->
      <div class="d-flex align-items-center">
        <slot name="left" />
      </div>

      <!-- Right: Panel toggles and secondary actions -->
      <div class="d-flex align-items-center">
        <slot name="right" />
      </div>
    </div>

    <!-- Below: Content that appears on next line (e.g., Rule Context Bar) -->
    <slot name="below" />
  </div>
</template>

<script>
/**
 * BaseCommandBar - Reusable command bar wrapper
 *
 * Provides consistent structure for command bars across the application.
 * Pages provide their own actions (left) and panels (right) via slots.
 *
 * Usage:
 *   <BaseCommandBar>
 *     <template #left>
 *       <b-button>My Action</b-button>
 *     </template>
 *     <template #right>
 *       <b-button-group>
 *         <b-button>Panel 1</b-button>
 *         <b-button>Panel 2</b-button>
 *       </b-button-group>
 *     </template>
 *   </BaseCommandBar>
 *
 * Slots:
 *   - left: Page-specific actions (Create, Edit, Download, etc.)
 *   - right: Panel toggles and info buttons
 *
 * Design:
 *   - No props - pure presentation
 *   - No state - stateless wrapper
 *   - No logic - just structure
 */
export default {
  name: "BaseCommandBar",
};
</script>

<style scoped>
.command-bar {
  /* Consistent command bar styling across all pages */
}
</style>
