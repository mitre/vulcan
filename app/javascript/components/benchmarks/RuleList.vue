<script setup lang="ts">
/**
 * RuleList.vue
 *
 * Filterable and searchable list of rules for benchmark viewer.
 * Left sidebar component.
 */
import type { BenchmarkType, IBenchmarkRule } from '@/types'
import { BButton, BFormSelect } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'

const props = defineProps<{
  type: BenchmarkType
  rules: IBenchmarkRule[]
  selectedRule: IBenchmarkRule | null
}>()

const emit = defineEmits<{
  ruleSelected: [rule: IBenchmarkRule]
}>()

// Local state
const searchText = ref('')
const selectedSeverity = ref<string>('')
const sortField = ref<'rule_id' | 'version'>('rule_id')
const sortOrder = ref<'asc' | 'desc'>('asc')

// Field options for sorting
const fieldOptions = computed(() => [
  { value: 'rule_id', text: props.type === 'stig' ? 'SRG ID' : 'Rule ID' },
  { value: 'version', text: props.type === 'stig' ? 'STIG ID' : 'Version' },
])

// Severity counts
const severityCounts = computed(() => ({
  high: props.rules.filter(r => r.rule_severity === 'high').length,
  medium: props.rules.filter(r => r.rule_severity === 'medium').length,
  low: props.rules.filter(r => r.rule_severity === 'low').length,
}))

// Filtered rules
const filteredRules = computed(() => {
  let result = [...props.rules]

  // Search filter
  if (searchText.value) {
    const term = searchText.value.toLowerCase()
    result = result.filter(
      rule =>
        rule.rule_id.toLowerCase().includes(term)
        || rule.version.toLowerCase().includes(term),
    )
  }

  // Severity filter
  if (selectedSeverity.value) {
    result = result.filter(rule => rule.rule_severity === selectedSeverity.value)
  }

  // Sort
  result.sort((a, b) => {
    const aVal = sortField.value === 'rule_id' ? a.rule_id : a.version
    const bVal = sortField.value === 'rule_id' ? b.rule_id : b.version
    const comparison = aVal.localeCompare(bVal)
    return sortOrder.value === 'asc' ? comparison : -comparison
  })

  return result
})

/**
 * Set severity filter
 */
function setSeverity(severity: string) {
  selectedSeverity.value = severity
}

/**
 * Toggle sort order
 */
function toggleSort() {
  sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
}

/**
 * Select a rule
 */
function selectRule(rule: IBenchmarkRule) {
  emit('ruleSelected', rule)
}

/**
 * Check if rule is selected
 */
function isSelected(rule: IBenchmarkRule): boolean {
  return props.selectedRule?.id === rule.id
}
</script>

<template>
  <!-- Rule list fills parent sidebar panel via flexbox -->
  <div class="card rule-list d-flex flex-column flex-grow-1 h-100">
    <!-- Filter Section (fixed height) -->
    <div class="card-header flex-shrink-0">
      <h5 class="card-title mb-2">
        Filter & Search
      </h5>
      <div class="mb-2">
        <input
          v-model="searchText"
          type="text"
          class="form-control form-control-sm"
          :placeholder="`Search by ${type === 'stig' ? 'STIG ID or SRG ID' : 'Rule ID or Version'}`"
        >
      </div>
      <div class="d-flex flex-wrap gap-1">
        <BButton size="sm" variant="danger" @click="setSeverity('high')">
          High
          <span class="badge bg-light text-dark">{{ severityCounts.high }}</span>
        </BButton>
        <BButton size="sm" variant="warning" @click="setSeverity('medium')">
          Med
          <span class="badge bg-light text-dark">{{ severityCounts.medium }}</span>
        </BButton>
        <BButton size="sm" variant="success" @click="setSeverity('low')">
          Low
          <span class="badge bg-light text-dark">{{ severityCounts.low }}</span>
        </BButton>
        <BButton size="sm" variant="secondary" @click="setSeverity('')">
          All
          <span class="badge bg-light text-dark">{{ rules.length }}</span>
        </BButton>
      </div>
    </div>

    <!-- Scrollable Rule List -->
    <div class="card-body rule-table-container flex-grow-1 overflow-auto p-0">
      <table class="table table-hover table-sm mb-0">
        <thead class="sticky-top bg-body">
          <tr>
            <th class="d-flex align-items-center gap-2 py-2">
              <BFormSelect v-model="sortField" :options="fieldOptions" size="sm" class="w-auto" />
              <button class="btn btn-sm btn-link p-0" @click="toggleSort">
                <i
                  :class="sortOrder === 'asc' ? 'bi bi-arrow-down-circle' : 'bi bi-arrow-up-circle'"
                  aria-hidden="true"
                />
              </button>
              <span class="text-muted small ms-auto">{{ filteredRules.length }}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="rule in filteredRules"
            :key="rule.id"
            :class="{ 'bg-primary text-white': isSelected(rule) }"
            class="rule-row"
            @click="selectRule(rule)"
          >
            <td class="py-1">
              {{ sortField === 'rule_id' ? rule.rule_id : rule.version }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.rule-list {
  /* Fills parent flexbox - no magic height needed */
  overflow: hidden; /* Parent clips, .rule-table-container child scrolls */
  min-height: 0; /* Fix: allows flex item to shrink for scroll */
}
.rule-table-container {
  min-height: 0; /* Fix: allows flex item to shrink for scroll */
}
.rule-row {
  cursor: pointer;
}
.rule-row:hover:not(.bg-primary) {
  background-color: var(--bs-secondary-bg);
}
</style>
