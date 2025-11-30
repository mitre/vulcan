<script setup lang="ts">
/**
 * SRGs Index Page
 *
 * Uses async setup with Suspense for loading state.
 */
import { storeToRefs } from 'pinia'
import { BenchmarkList } from '@/components/benchmarks'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useBenchmarks } from '@/composables'
import { useAuthStore } from '@/stores'

// Use unified benchmark composable for SRGs
const { items, refresh, upload, remove } = useBenchmarks('srg')

// Auth state
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Top-level await makes this component suspensible
await refresh()
</script>

<template>
  <PageContainer>
    <BenchmarkList
      type="srg"
      :items="items"
      :is-admin="isAdmin"
      @refresh="refresh"
      @upload="upload"
      @delete="remove"
    />
  </PageContainer>
</template>
