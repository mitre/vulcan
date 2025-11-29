<script setup lang="ts">
/**
 * BenchmarkViewer.vue
 *
 * Unified 3-column layout for viewing STIG/SRG benchmarks.
 * - Left: Rule list with search/filter
 * - Middle: Rule details
 * - Right: Rule overview/metadata
 */
import type { BenchmarkType, IBenchmark, IBenchmarkRule } from '@/types'
import { computed, ref, watch } from 'vue'
import RuleDetails from './RuleDetails.vue'
import RuleList from './RuleList.vue'
import RuleOverview from './RuleOverview.vue'

const props = defineProps<{
  type: BenchmarkType
  benchmark: IBenchmark
}>()

// Selected rule state
const selectedRule = ref<IBenchmarkRule | null>(null)

// Sort rules and select first one on mount
const sortedRules = computed(() => {
  if (!props.benchmark.rules) return []
  return [...props.benchmark.rules].sort((a, b) => a.rule_id.localeCompare(b.rule_id))
})

// Select first rule initially
watch(
  () => sortedRules.value,
  (rules) => {
    if (rules.length > 0 && !selectedRule.value) {
      selectedRule.value = rules[0]
    }
  },
  { immediate: true },
)

// Type-specific labels
const typeLabel = computed(() => (props.type === 'stig' ? 'STIG' : 'SRG'))
const dateLabel = computed(() => (props.type === 'stig' ? 'Benchmark Date' : 'Release Date'))

/**
 * Handle rule selection from list
 */
function onRuleSelected(rule: IBenchmarkRule) {
  selectedRule.value = rule
}
</script>

<template>
  <main role="main" class="container-fluid">
    <h1>{{ benchmark.title }} :: {{ benchmark.version }}</h1>
    <h6 class="card-subtitle text-muted mb-2">
      {{ dateLabel }}: {{ benchmark.date }}
    </h6>
    <br>
    <hr>
    <div class="row">
      <!-- Left Sidebar - Rule List -->
      <aside class="col-md-3">
        <RuleList
          :type="type"
          :rules="sortedRules"
          :selected-rule="selectedRule"
          @rule-selected="onRuleSelected"
        />
      </aside>
      <!-- Middle Section - Rule Details -->
      <main class="col-md-6">
        <RuleDetails
          v-if="selectedRule"
          :type="type"
          :rule="selectedRule"
        />
        <div v-else class="alert alert-info">
          Select a rule to view details
        </div>
      </main>
      <!-- Right Sidebar - Rule Overview -->
      <aside class="col-md-3">
        <RuleOverview
          v-if="selectedRule"
          :type="type"
          :rule="selectedRule"
        />
      </aside>
    </div>
  </main>
</template>
