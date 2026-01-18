<script setup lang="ts">
/**
 * Benchmarks Index Page (Public)
 *
 * Unified view for browsing STIGs, SRGs, and Components.
 * Uses tabs to switch between benchmark types.
 * Admin users see upload/delete actions; regular users see view-only.
 *
 * Architecture: Uses useBenchmarks composable with reactive type switching
 */

import type { BenchmarkType } from '@/types'
import { storeToRefs } from 'pinia'
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { BenchmarkList } from '@/components/benchmarks'
import PageContainer from '@/components/shared/PageContainer.vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import { useBenchmarks } from '@/composables'
import { useAuthStore } from '@/stores'

// Auth state
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Route for tab from URL query param
const route = useRoute()
const router = useRouter()

// Get tab from URL or default to 'stig'
function getTabFromRoute(): BenchmarkType {
  const tab = route.query.tab as string
  if (tab === 'stig' || tab === 'srg' || tab === 'component') {
    return tab
  }
  return 'stig'
}

// Current selected type (tab)
const selectedType = ref<BenchmarkType>(getTabFromRoute())

// Watch for route query changes (handles redirects from /stigs, /srgs, /components)
watch(
  () => route.query.tab,
  (newTab) => {
    const tab = newTab as string
    if (tab === 'stig' || tab === 'srg' || tab === 'component') {
      if (selectedType.value !== tab) {
        selectedType.value = tab
        loadData()
      }
    }
  },
  { immediate: false },
)

// Create composables for all types
const stigBenchmarks = useBenchmarks('stig')
const srgBenchmarks = useBenchmarks('srg')
// For components: non-admins only see released components
const showReleasedOnly = computed(() => !isAdmin.value)
const componentBenchmarks = useBenchmarks('component', { releasedOnly: showReleasedOnly })

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

// Handle tab switch - update URL and load data
async function switchTab(type: BenchmarkType) {
  if (type === selectedType.value) return
  selectedType.value = type
  // Update URL query param without full navigation
  router.replace({ query: { tab: type } })
  await loadData()
}

// Handle upload (admin only, STIGs/SRGs only)
async function handleUpload(file: File) {
  if (activeBenchmarks.value.upload) {
    const success = await activeBenchmarks.value.upload(file)
    if (success) {
      await loadData()
    }
  }
}

// Handle delete (admin only)
async function handleDelete(id: number) {
  const success = await activeBenchmarks.value.remove(id)
  if (success) {
    await loadData()
  }
}

// Initial load - fetch all types for accurate tab counts
async function initialLoad() {
  loading.value = true
  error.value = null
  try {
    // Load all types in parallel for tab badge counts
    await Promise.all([
      stigBenchmarks.refresh(),
      srgBenchmarks.refresh(),
      componentBenchmarks.refresh(),
    ])
  }
  catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load data'
  }
  finally {
    loading.value = false
  }
}

initialLoad()
</script>

<template>
  <PageContainer>
    <div class="benchmarks-page">
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
        :is-admin="isAdmin"
        @refresh="loadData"
        @upload="handleUpload"
        @delete="handleDelete"
      />
    </div>
  </PageContainer>
</template>
