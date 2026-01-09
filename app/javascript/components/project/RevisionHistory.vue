<script setup lang="ts">
/**
 * RevisionHistory Component
 *
 * Displays component revision history in an offcanvas panel.
 * Shows version changes (added/removed/updated rules) for selected component.
 * Uses Vue 3 Composition API with useRevisionHistory composable.
 */
import { watch } from 'vue'
import { BFormSelect, BInputGroup, BInputGroupText } from 'bootstrap-vue-next'
import { useRevisionHistory } from '@/composables/useRevisionHistory'

const props = defineProps<{
  project: {
    id: number
    name: string
  }
  uniqueComponentNames: string[]
}>()

const { selectedComponentName, revisionHistory, isLoading, fetchRevisionHistory } = useRevisionHistory()

// Watch for component selection changes and fetch history
watch(selectedComponentName, (newName) => {
  if (newName) {
    fetchRevisionHistory(props.project.id)
  }
})
</script>

<template>
  <div class="revision-history">
    <!-- Component Selector -->
    <BInputGroup size="sm" class="mb-3">
      <BInputGroupText class="rounded-0">
        Component Name
      </BInputGroupText>
      <BFormSelect
        v-model="selectedComponentName"
        class="form-select-sm"
      >
        <option value="">
          Select a component...
        </option>
        <option
          v-for="name in uniqueComponentNames"
          :key="name"
          :value="name"
        >
          {{ name }}
        </option>
      </BFormSelect>
    </BInputGroup>

    <!-- Loading State -->
    <div v-if="isLoading" class="mt-3 text-center">
      <h6 class="m-3">
        Loading...
      </h6>
    </div>

    <!-- Revision History Entries -->
    <div v-if="!isLoading && revisionHistory.length > 0" class="mt-3 revision-history-entries">
      <div
        v-for="(history, index) in revisionHistory.slice().reverse()"
        :key="`history-${index}`"
      >
        <!-- Component Header -->
        <div v-if="history.component">
          <h6>
            {{ history.component.name }}
            <template v-if="history.component.version || history.component.release">
              ({{
                [
                  history.component.version ? `Version ${history.component.version}` : "",
                  history.component.release ? `Release ${history.component.release}` : "",
                ].filter(Boolean).join(", ")
              }})
            </template>
          </h6>
        </div>

        <!-- Changes List -->
        <div v-if="history.changes" class="pb-2">
          <div
            v-for="(ruleId, idx) in Object.keys(history.changes).sort()"
            :key="`history-${index}-rule-${idx}`"
            class="ms-3"
          >
            <p v-if="history.changes[ruleId].change === 'added'" class="mb-1">
              {{ history.diffComponent.prefix }}-{{ ruleId }} was added
            </p>
            <p v-if="history.changes[ruleId].change === 'removed'" class="mb-1">
              {{ history.baseComponent.prefix }}-{{ ruleId }} was removed
            </p>
            <p v-if="history.changes[ruleId].change === 'updated'" class="mb-1">
              {{ history.baseComponent.prefix }}-{{ ruleId }} was updated
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-if="!isLoading && revisionHistory.length === 0 && selectedComponentName" class="mt-3 text-center text-muted">
      <p>No revision history found for this component.</p>
    </div>
  </div>
</template>

<style scoped>
.form-select-sm {
  height: 2rem;
}
</style>
