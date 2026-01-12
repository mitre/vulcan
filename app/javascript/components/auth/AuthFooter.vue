<script setup lang="ts">
/**
 * AuthFooter Component
 * Wrapper for AppFooter - used in standalone auth pages (ForgotPasswordPage)
 * Maintained for backwards compatibility during SPA migration
 */
import AppFooter from '@/components/shared/AppFooter.vue'
</script>

<template>
  <!-- DRY: Just use AppFooter (includes banner) -->
  <AppFooter />
</template>
