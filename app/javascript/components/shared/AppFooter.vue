<script setup lang="ts">
/**
 * AppFooter - Sticky footer component
 * Uses Bootstrap 5 mt-auto pattern for sticky positioning
 */
import AppBanner from '@/components/shared/AppBanner.vue'
import FooterCopyright from '@/components/shared/FooterCopyright.vue'

defineProps<{
  version?: string
}>()
</script>

<template>
  <!-- Footer in normal document flow (not fixed-bottom) -->
  <!-- Parent App.vue uses d-flex flex-column vh-100, so footer stays at bottom via flexbox -->
  <footer class="footer mt-auto flex-shrink-0 bg-dark border-top text-light">
    <div class="container-fluid container-app">
      <!-- Top row: GitHub, Version, MITRE SAF -->
      <div class="d-flex justify-content-between align-items-center small py-2 border-bottom border-secondary">
        <!-- GitHub Link -->
        <a
          href="https://github.com/mitre/vulcan"
          target="_blank"
          rel="noopener noreferrer"
          class="text-light text-decoration-none d-flex align-items-center gap-1"
          title="View source on GitHub"
        >
          <i class="bi bi-github" style="font-size: 1.1rem;" />
          <span class="d-none d-sm-inline">GitHub</span>
        </a>

        <!-- Version -->
        <span v-if="version" class="text-light">
          v{{ version }}
        </span>

        <!-- MITRE SAF Link with Logo -->
        <a
          href="https://saf.mitre.org"
          target="_blank"
          rel="noopener noreferrer"
          class="text-light text-decoration-none d-flex align-items-center gap-2"
          title="MITRE Security Automation Framework"
        >
          <span class="d-none d-sm-inline">MITRE SAF</span>
          <img
            src="https://mitre.github.io/saf-training/logo.svg"
            alt="MITRE SAF"
            style="height: 1.25rem; width: auto;"
          />
        </a>
      </div>

      <!-- Legal footer -->
      <FooterCopyright />
    </div>

    <!-- App banner (optional colored bar at bottom) -->
    <AppBanner />
  </footer>
</template>
