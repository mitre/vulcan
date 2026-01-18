<script setup lang="ts">
/**
 * PageContainer - Standard page layout container
 *
 * Provides consistent alignment with navbar and footer.
 * Use this in all page components to ensure layout consistency.
 */

interface Props {
  /** Remove max-width constraint for full-width pages */
  fluid?: boolean
  /** Remove vertical padding */
  noPadding?: boolean
}

withDefaults(defineProps<Props>(), {
  fluid: false,
  noPadding: false,
})
</script>

<template>
  <div
    class="container-fluid"
    :class="{
      'container-app': !fluid,
      'py-3 py-lg-4': !noPadding,
    }"
  >
    <slot />
  </div>
</template>
