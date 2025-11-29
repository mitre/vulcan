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
  <footer class="footer fixed-bottom py-2 bg-body-tertiary border-top">
    <div class="container-fluid">
      <div class="d-flex justify-content-between align-items-center text-body-secondary small">
        <span>
          <a
            href="https://github.com/mitre/vulcan"
            target="_blank"
            rel="noopener noreferrer"
            class="text-body-secondary text-decoration-none"
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
            class="text-body-secondary text-decoration-none"
          >
            MITRE SAF
          </a>
        </span>
      </div>
    </div>
  </footer>
</template>
