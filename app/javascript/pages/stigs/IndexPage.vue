<script setup lang="ts">
/**
 * STIGs Index Page
 *
 * Uses async setup with Suspense for loading state.
 */
import { storeToRefs } from 'pinia'
import { BenchmarkList } from '@/components/benchmarks'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useBenchmarks } from '@/composables'
import { useAuthStore } from '@/stores'

// Use unified benchmark composable for STIGs
const { items, refresh, upload, remove } = useBenchmarks('stig')

// Auth state
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Top-level await makes this component suspensible
await refresh()
</script>

<template>
  <PageContainer>
    <BenchmarkList
      type="stig"
      :items="items"
      :is-admin="isAdmin"
      @refresh="refresh"
      @upload="upload"
      @delete="remove"
    />
  </PageContainer>
</template>
