<script setup lang="ts">
/**
 * ErrorBoundary - Catches errors from async child components
 *
 * Used with Suspense to provide error handling for async setup().
 * Wrap Suspense in ErrorBoundary to catch and display errors.
 */
import { onErrorCaptured, ref } from 'vue'

interface Props {
  /** Custom error message prefix */
  messagePrefix?: string
}

const props = withDefaults(defineProps<Props>(), {
  messagePrefix: 'An error occurred',
})

const error = ref<Error | null>(null)

// Capture errors from child async components
onErrorCaptured((err: Error) => {
  error.value = err
  console.error('ErrorBoundary caught:', err)
  return false // Stop propagation
})

function retry() {
  error.value = null
}
</script>

<template>
  <div v-if="error" class="alert alert-danger" role="alert">
    <h5 class="alert-heading">
      <i class="bi bi-exclamation-triangle-fill me-2" />
      {{ messagePrefix }}
    </h5>
    <p class="mb-2">
      {{ error.message }}
    </p>
    <hr>
    <button class="btn btn-outline-danger btn-sm" @click="retry">
      <i class="bi bi-arrow-clockwise me-1" />
      Try Again
    </button>
  </div>
  <slot v-else />
</template>
