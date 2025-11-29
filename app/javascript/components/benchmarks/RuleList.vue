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
  <div class="p-3">
    <!-- Filter Section -->
    <div class="mb-3">
      <h5 class="card-title">
        Filter & Search
      </h5>
      <div class="mb-3">
        <label class="form-label"><strong>Search</strong></label>
        <input
          v-model="searchText"
          type="text"
          class="form-control"
          :placeholder="`Search by ${type === 'stig' ? 'STIG ID or SRG ID' : 'Rule ID or Version'}`"
        >
      </div>
      <div class="mb-3">
        <label class="form-label"><strong>Filter by Severity</strong></label>
        <div class="d-flex flex-wrap gap-1">
          <BButton size="sm" variant="danger" @click="setSeverity('high')">
            High
            <span class="badge bg-light text-dark">{{ severityCounts.high }}</span>
          </BButton>
          <BButton size="sm" variant="warning" @click="setSeverity('medium')">
            Medium
            <span class="badge bg-light text-dark">{{ severityCounts.medium }}</span>
          </BButton>
          <BButton size="sm" variant="success" @click="setSeverity('low')">
            Low
            <span class="badge bg-light text-dark">{{ severityCounts.low }}</span>
          </BButton>
          <BButton size="sm" variant="info" @click="setSeverity('')">
            All
            <span class="badge bg-light text-dark">{{ rules.length }}</span>
          </BButton>
        </div>
      </div>
    </div>

    <!-- Table of Rules -->
    <div class="mt-3" style="max-height: 700px; overflow-y: auto">
      <h5 class="card-title">
        Requirements
      </h5>
      <table class="table table-hover">
        <thead>
          <tr>
            <th class="d-flex align-items-center gap-2">
              <BFormSelect v-model="sortField" :options="fieldOptions" size="sm" />
              <button class="btn btn-sm btn-link p-0" @click="toggleSort">
                <i
                  :class="sortOrder === 'asc' ? 'bi bi-arrow-down-circle' : 'bi bi-arrow-up-circle'"
                  aria-hidden="true"
                />
              </button>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="rule in filteredRules"
            :key="rule.id"
            :class="{ 'bg-secondary text-white': isSelected(rule) }"
            style="cursor: pointer"
            @click="selectRule(rule)"
          >
            <td>{{ sortField === 'rule_id' ? rule.rule_id : rule.version }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
