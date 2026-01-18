<script setup lang="ts">
/**
 * PageSpinner - Loading spinner for page-level async operations
 *
 * Used as Suspense fallback content.
 */

interface Props {
  /** Loading message to display below spinner */
  message?: string
}

withDefaults(defineProps<Props>(), {
  message: 'Loading...',
})
</script>

<template>
  <div class="text-center py-5">
    <div class="spinner-border" role="status">
      <span class="visually-hidden">{{ message }}</span>
    </div>
    <p class="mt-2 text-muted">
      {{ message }}
    </p>
  </div>
</template>
