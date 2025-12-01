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
  /** Optional: Rule ID to select initially (for deep-linking from search) */
  initialRuleId?: number | null
}>()

// Selected rule state
const selectedRule = ref<IBenchmarkRule | null>(null)

// Sort rules and select first one on mount
const sortedRules = computed(() => {
  if (!props.benchmark.rules) return []
  return [...props.benchmark.rules].sort((a, b) => a.rule_id.localeCompare(b.rule_id))
})

// Select initial rule: deep-linked rule if provided, otherwise first rule
watch(
  () => sortedRules.value,
  (rules) => {
    if (rules.length > 0 && !selectedRule.value) {
      // If initialRuleId provided, find and select that rule
      if (props.initialRuleId) {
        const targetRule = rules.find(r => r.id === props.initialRuleId)
        if (targetRule) {
          selectedRule.value = targetRule
          return
        }
      }
      // Fallback to first rule
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
  <!-- Layout 3: Viewer - Three-column benchmark viewer -->
  <!-- flex-grow-1 fills available space from parent container -->
  <div class="benchmark-viewer d-flex flex-column flex-grow-1 overflow-hidden">
    <!-- Header -->
    <header class="benchmark-header pb-2 border-bottom flex-shrink-0">
      <h1 class="h4 mb-1">
        {{ benchmark.title }} :: {{ benchmark.version }}
      </h1>
      <p class="text-muted mb-0 small">
        {{ dateLabel }}: {{ benchmark.date }}
      </p>
    </header>

    <!-- Content - 3 column layout with independent scrolling -->
    <div class="benchmark-content d-flex flex-grow-1 overflow-hidden">
      <!-- Left Sidebar - Rule List (scrolls independently) -->
      <aside class="rule-list-panel d-flex flex-column border-end overflow-hidden">
        <RuleList
          :type="type"
          :rules="sortedRules"
          :selected-rule="selectedRule"
          @rule-selected="onRuleSelected"
        />
      </aside>

      <!-- Middle Section - Rule Details (scrolls independently) -->
      <main class="rule-details-panel flex-grow-1 overflow-auto p-3">
        <RuleDetails
          v-if="selectedRule"
          :type="type"
          :rule="selectedRule"
        />
        <div v-else class="alert alert-info">
          Select a rule to view details
        </div>
      </main>

      <!-- Right Sidebar - Rule Overview (scrolls independently) -->
      <aside class="rule-overview-panel d-flex flex-column border-start overflow-auto">
        <RuleOverview
          v-if="selectedRule"
          :type="type"
          :rule="selectedRule"
        />
      </aside>
    </div>
  </div>
</template>

<style scoped>
/* Container query context */
.benchmark-viewer {
  container-type: inline-size;
  container-name: benchmark-viewer;
}

/* Default widths for 3-column layout - using CSS variables */
.rule-list-panel {
  width: var(--app-sidebar-width);
  flex-shrink: 0;
}
.rule-overview-panel {
  width: var(--app-sidebar-right-width);
  flex-shrink: 0;
}

/* Responsive: 2-column on medium containers */
@container benchmark-viewer (max-width: 1200px) {
  .rule-overview-panel {
    display: none;
  }
}

/* Responsive: stack on narrow containers */
@container benchmark-viewer (max-width: 768px) {
  .benchmark-content {
    flex-direction: column;
  }
  .rule-list-panel {
    width: 100%;
    max-height: 35vh;
    border-end: none;
    border-bottom: 1px solid var(--bs-border-color);
  }
  .rule-details-panel {
    flex: 1;
  }
}

/* Fallback for older browsers */
@supports not (container-type: inline-size) {
  @media (max-width: 1200px) {
    .rule-overview-panel {
      display: none;
    }
  }
  @media (max-width: 768px) {
    .benchmark-content {
      flex-direction: column;
    }
    .rule-list-panel {
      width: 100%;
      max-height: 35vh;
    }
  }
}
</style>
