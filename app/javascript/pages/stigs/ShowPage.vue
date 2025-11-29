<script setup lang="ts">
import type { IBenchmark } from '@/types'
/**
 * STIG Show Page
 *
 * Displays a single STIG with its rules using the unified BenchmarkViewer.
 */
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { BenchmarkViewer } from '@/components/benchmarks'
import { useStigs } from '@/composables'
import { stigToBenchmark } from '@/types'

const route = useRoute()
const { currentStig, loading, error, fetchById } = useStigs()

// Converted benchmark for the viewer
const benchmark = ref<IBenchmark | null>(null)

// Fetch STIG on mount
onMounted(async () => {
  const id = Number(route.params.id)
  if (id) {
    const stig = await fetchById(id)
    if (stig) {
      benchmark.value = stigToBenchmark(stig)
    }
  }
})
</script>

<template>
  <div>
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p class="mt-2">
        Loading STIG...
      </p>
    </div>
    <div v-else-if="error" class="alert alert-danger">
      {{ error }}
    </div>
    <BenchmarkViewer
      v-else-if="benchmark"
      type="stig"
      :benchmark="benchmark"
    />
    <div v-else class="alert alert-warning">
      STIG not found
    </div>
  </div>
</template>
