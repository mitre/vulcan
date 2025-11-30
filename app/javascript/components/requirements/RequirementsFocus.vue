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
  <div class="requirements-focus d-flex h-100">
    <!-- Navigator -->
    <RequirementNavigator
      :component-id="componentId"
      :project-prefix="projectPrefix"
      :read-only="effectivePermissions === 'viewer'"
      @select="handleSelect"
    />

    <!-- Editor -->
    <div class="flex-grow-1 h-100 overflow-hidden">
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
.requirements-focus {
  min-height: 0; /* Allow flex children to shrink */
}
</style>
