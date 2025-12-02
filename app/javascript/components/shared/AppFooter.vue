<script setup lang="ts">
/**
 * AppFooter - Sticky footer component
 * Uses Bootstrap 5 mt-auto pattern for sticky positioning
 */
defineProps<{
  version?: string
}>()

const currentYear = new Date().getFullYear()
</script>

<template>
  <!-- Footer in normal document flow (not fixed-bottom) -->
  <!-- Parent App.vue uses d-flex flex-column vh-100, so footer stays at bottom via flexbox -->
  <!-- Height enforced by .footer class in application.scss (--app-footer-height: 40px) -->
  <footer class="footer mt-auto flex-shrink-0 bg-dark border-top text-light d-flex align-items-center">
    <div class="container-fluid container-app">
      <div class="d-flex justify-content-between align-items-center small">
        <span>
          <a
            href="https://github.com/mitre/vulcan"
            target="_blank"
            rel="noopener noreferrer"
            class="text-light text-decoration-none"
          >
            Vulcan
          </a>
          <span v-if="version" class="ms-1">v{{ version }}</span>
          &copy; {{ currentYear }} MITRE Corporation
        </span>
        <span>
          <a
            href="https://saf.mitre.org"
            target="_blank"
            rel="noopener noreferrer"
            class="text-light text-decoration-none"
          >
            MITRE SAF
          </a>
        </span>
      </div>
    </div>
  </footer>
</template>
