<script setup lang="ts">
/**
 * AppFooter - Footer component positioned by CSS Grid in App.vue
 */
import AppBanner from '@/components/shared/AppBanner.vue'
import FooterCopyright from '@/components/shared/FooterCopyright.vue'

defineProps<{
  version?: string
}>()
</script>

<template>
  <!-- Footer positioned by CSS Grid in App.vue (grid-row: 3) -->
  <footer class="footer mt-auto flex-shrink-0 bg-dark border-top text-light">
    <div class="container-fluid container-app py-3">
      <!-- Single row: Copyright text left, icons right -->
      <div class="d-flex justify-content-between align-items-center gap-3 flex-wrap">
        <!-- Copyright text on left -->
        <div class="flex-grow-1">
          <FooterCopyright />
        </div>

        <!-- Icons on right -->
        <div class="d-flex align-items-center gap-3">
          <!-- GitHub Icon -->
          <a
            href="https://github.com/mitre/vulcan"
            target="_blank"
            rel="noopener noreferrer"
            class="text-light text-decoration-none"
            title="View source on GitHub"
          >
            <i class="bi bi-github" style="font-size: 1.25rem;" />
          </a>

          <!-- MITRE SAF Logo -->
          <a
            href="https://saf.mitre.org"
            target="_blank"
            rel="noopener noreferrer"
            class="text-light text-decoration-none"
            title="MITRE Security Automation Framework"
          >
            <img
              src="https://mitre.github.io/saf-training/logo.svg"
              alt="MITRE SAF"
              style="height: 1.5rem; width: auto;"
            />
          </a>
        </div>
      </div>
    </div>

    <!-- App banner (optional colored bar at bottom) -->
    <AppBanner />
  </footer>
</template>
