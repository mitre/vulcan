<script setup lang="ts">
/**
 * RequirementsFocus - Authoring Mode
 *
 * Two-panel layout:
 * - Left: Collapsible navigator
 * - Right: Full editor with accordion sections
 *
 * For deep authoring work on individual requirements.
 */

import type { ISlimRule } from '@/types'
import { useRules } from '@/composables'
import RequirementEditor from './RequirementEditor.vue'
import RequirementNavigator from './RequirementNavigator.vue'

// Props
interface Props {
  effectivePermissions: string
  componentId: number
  projectPrefix: string
}

const props = defineProps<Props>()

// Store
const { currentRule } = useRules()

// Handlers - receives slim rule from navigator
function handleSelect(rule: ISlimRule) {
  // Selection handled by navigator via store
  // Full data is fetched automatically by selectRule()
}

function handleSaved() {
  // Could trigger refresh or show notification
}
</script>

<template>
  <!-- Two-panel layout: Navigator + Editor -->
  <!-- flex-grow-1 fills available space from parent (ControlsPage content area) -->
  <div class="requirements-focus d-flex flex-grow-1 overflow-hidden">
    <!-- Navigator - fixed width, scrolls independently -->
    <RequirementNavigator
      :component-id="componentId"
      :project-prefix="projectPrefix"
      :read-only="effectivePermissions === 'viewer'"
      @select="handleSelect"
    />

    <!-- Editor - takes remaining space, scrolls independently -->
    <div class="flex-grow-1 d-flex flex-column overflow-hidden">
      <RequirementEditor
        :rule="currentRule"
        :effective-permissions="effectivePermissions"
        :component-id="componentId"
        :project-prefix="projectPrefix"
        @saved="handleSaved"
      />
    </div>
  </div>
</template>

<style scoped>
/* Container query context for responsive child components */
.requirements-focus {
  container-type: inline-size;
  container-name: requirements-focus;
  /* Fix: min-height: 0 allows flex item to shrink below content size */
  /* This ensures the scroll zones work correctly in nested flex layouts */
  min-height: 0;
}

/* Responsive layout: stack vertically on narrow containers */
@container requirements-focus (max-width: 768px) {
  .requirements-focus {
    flex-direction: column;
  }
}

/* Fallback for older browsers */
@supports not (container-type: inline-size) {
  @media (max-width: 768px) {
    .requirements-focus {
      flex-direction: column;
    }
  }
}
</style>
