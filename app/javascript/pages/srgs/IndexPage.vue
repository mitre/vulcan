<script setup lang="ts">
/**
 * SRGs Index Page
 *
 * Uses unified BenchmarkList component via useBenchmarks composable.
 */
import { storeToRefs } from 'pinia'
import { onMounted } from 'vue'
import { BenchmarkList } from '@/components/benchmarks'
import { useBenchmarks } from '@/composables'
import { useAuthStore } from '@/stores'

// Use unified benchmark composable for SRGs
const { items, loading, error, refresh, upload, remove } = useBenchmarks('srg')

// Auth state
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Fetch on mount
onMounted(async () => {
  await refresh()
})
</script>

<template>
  <div>
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p class="mt-2">
        Loading SRGs...
      </p>
    </div>
    <div v-else-if="error" class="alert alert-danger">
      {{ error }}
    </div>
    <BenchmarkList
      v-else
      type="srg"
      :items="items"
      :is-admin="isAdmin"
      @refresh="refresh"
      @upload="upload"
      @delete="remove"
    />
  </div>
</template>
