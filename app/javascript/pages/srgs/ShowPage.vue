<script setup lang="ts">
import type { IBenchmark } from '@/types'
/**
 * SRG Show Page
 *
 * Displays a single SRG with its rules using the unified BenchmarkViewer.
 */
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { BenchmarkViewer } from '@/components/benchmarks'
import { useSrgs } from '@/composables'
import { srgToBenchmark } from '@/types'

const route = useRoute()
const { currentSrg, loading, error, fetchById } = useSrgs()

// Converted benchmark for the viewer
const benchmark = ref<IBenchmark | null>(null)

// Fetch SRG on mount
onMounted(async () => {
  const id = Number(route.params.id)
  if (id) {
    const srg = await fetchById(id)
    if (srg) {
      benchmark.value = srgToBenchmark(srg)
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
        Loading SRG...
      </p>
    </div>
    <div v-else-if="error" class="alert alert-danger">
      {{ error }}
    </div>
    <BenchmarkViewer
      v-else-if="benchmark"
      type="srg"
      :benchmark="benchmark"
    />
    <div v-else class="alert alert-warning">
      SRG not found
    </div>
  </div>
</template>
