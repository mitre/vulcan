<script setup lang="ts">
/**
 * Components Index Page
 *
 * Lists all components the user has access to.
 * Uses async setup with Suspense for loading state.
 *
 * TODO: Implement component listing with useComponents composable
 */
import PageContainer from '@/components/shared/PageContainer.vue'

// TODO: Implement with async setup pattern:
// const { components, refresh } = useComponents()
// await refresh()
</script>

<template>
  <PageContainer>
    <h1>Components</h1>
    <p class="text-muted">
      Components list page - implementation pending
    </p>
    <!-- TODO: Add ComponentsList component -->
  </PageContainer>
</template>
