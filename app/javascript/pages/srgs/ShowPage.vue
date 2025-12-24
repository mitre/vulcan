<script setup lang="ts">
/**
 * SRG Show Page
 *
 * Uses async setup with Suspense for loading state.
 * Supports deep-linking to specific rules via ?rule= query param.
 */
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { BenchmarkViewer } from '@/components/benchmarks'
import { useSrgs } from '@/composables'
import { srgToBenchmark } from '@/types'

const route = useRoute()
const { fetchById } = useSrgs()

// Get ID from route params - validate it's a valid number
const id = Number(route.params.id)
if (!id || Number.isNaN(id)) {
  throw new Error(`Invalid SRG ID: ${route.params.id}`)
}

// Top-level await makes this component suspensible
const srg = await fetchById(id)

if (!srg) {
  throw new Error(`SRG with ID ${id} not found`)
}

const benchmark = srgToBenchmark(srg)

// Deep-link support: ?rule=123 - find the rule ID to select initially
const initialRuleId = computed(() => {
  const ruleParam = route.query.rule
  return ruleParam ? Number(ruleParam) : null
})
</script>

<template>
  <!-- Layout 3: Viewer - Three-column for benchmark viewing -->
  <!-- Height constrained to main content area via CSS variable -->
  <div class="srg-show-page d-flex flex-column" style="height: var(--app-main-height);">
    <div class="container-fluid container-app flex-grow-1 d-flex flex-column py-3 overflow-hidden">
      <BenchmarkViewer type="srg" :benchmark="benchmark" :initial-rule-id="initialRuleId" />
    </div>
  </div>
</template>

<style scoped>
/* Layout handled by Bootstrap utilities and inline min-height: 0 */
</style>
