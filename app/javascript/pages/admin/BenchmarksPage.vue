<script setup lang="ts">
/**
 * Admin Benchmarks Page
 *
 * Unified management interface for STIGs, SRGs, and Components.
 * Uses tabs to switch between benchmark types.
 * Leverages existing BenchmarkList and BenchmarkTable components.
 *
 * Architecture: Uses useBenchmarks composable with reactive type switching
 */

import type { BenchmarkType } from '@/types'
import { computed, ref } from 'vue'
import { BenchmarkList } from '@/components/benchmarks'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import { useBenchmarks } from '@/composables'

// Current selected type (tab)
const selectedType = ref<BenchmarkType>('stig')

// Create composables for all types (we'll switch which one is active)
const stigBenchmarks = useBenchmarks('stig')
const srgBenchmarks = useBenchmarks('srg')
const componentBenchmarks = useBenchmarks('component')

// Active composable based on selected type
const activeBenchmarks = computed(() => {
  switch (selectedType.value) {
    case 'stig':
      return stigBenchmarks
    case 'srg':
      return srgBenchmarks
    case 'component':
      return componentBenchmarks
    default:
      return stigBenchmarks
  }
})

// Loading state
const loading = ref(true)
const error = ref<string | null>(null)

// Tab definitions
const tabs = [
  { key: 'stig' as BenchmarkType, label: 'STIGs', icon: 'bi-file-earmark-lock' },
  { key: 'srg' as BenchmarkType, label: 'SRGs', icon: 'bi-file-earmark-text' },
  { key: 'component' as BenchmarkType, label: 'Components', icon: 'bi-puzzle' },
]

// Load data for current type
async function loadData() {
  loading.value = true
  error.value = null
  try {
    await activeBenchmarks.value.refresh()
  }
  catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load data'
  }
  finally {
    loading.value = false
  }
}

// Handle tab switch
async function switchTab(type: BenchmarkType) {
  if (type === selectedType.value) return
  selectedType.value = type
  await loadData()
}

// Handle upload
async function handleUpload(file: File) {
  const success = await activeBenchmarks.value.upload(file)
  if (success) {
    await loadData()
  }
}

// Handle delete
async function handleDelete(id: number) {
  const success = await activeBenchmarks.value.remove(id)
  if (success) {
    await loadData()
  }
}

// Initial load
loadData()
</script>

<template>
  <div class="admin-benchmarks">
    <div class="d-flex justify-content-between align-items-center mb-4">
      <h1 class="h3 mb-0">
        <i class="bi bi-collection me-2" />
        Benchmarks
      </h1>
    </div>

    <!-- Type Tabs -->
    <ul class="nav nav-tabs mb-4">
      <li v-for="tab in tabs" :key="tab.key" class="nav-item">
        <button
          class="nav-link"
          :class="{ active: selectedType === tab.key }"
          type="button"
          @click="switchTab(tab.key)"
        >
          <i :class="tab.icon" class="me-1" />
          {{ tab.label }}
          <BBadge
            variant="secondary"
            class="ms-1"
          >
            {{ tab.key === 'stig' ? stigBenchmarks.items.value.length
              : tab.key === 'srg' ? srgBenchmarks.items.value.length
                : componentBenchmarks.items.value.length }}
          </BBadge>
        </button>
      </li>
    </ul>

    <!-- Loading state -->
    <PageSpinner v-if="loading" message="Loading benchmarks..." />

    <!-- Error state -->
    <BAlert v-else-if="error" variant="danger" show>
      {{ error }}
      <BButton size="sm" variant="outline-danger" class="ms-2" @click="loadData">
        Retry
      </BButton>
    </BAlert>

    <!-- Benchmark List (reuse existing component) -->
    <BenchmarkList
      v-else
      :type="selectedType"
      :items="activeBenchmarks.items.value"
      :is-admin="true"
      @refresh="loadData"
      @upload="handleUpload"
      @delete="handleDelete"
    />
  </div>
</template>
