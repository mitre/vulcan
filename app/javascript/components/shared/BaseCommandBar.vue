<template>
  <div class="command-bar bg-light px-3 py-2 mb-3">
    <!-- Above: Breadcrumbs or other inline header content -->
    <slot name="above" />

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
  border: 1px solid var(--vulcan-gray-300, var(--gray-300));
  border-radius: 0.375rem;
}

.command-bar >>> .btn-sm {
  font-size: var(--vulcan-action-btn-font-size, 0.75rem);
  padding: 0.2rem 0.5rem;
  line-height: 1.5;
}

.command-bar >>> .d-flex {
  gap: 0.375rem;
}
</style>
