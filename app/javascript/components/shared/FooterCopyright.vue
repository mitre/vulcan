<script setup lang="ts">
import { computed } from 'vue'

// Footer config from Rails
interface FooterConfig {
  copyrightSymbol?: string
  copyrightYear?: string
  organization?: string
  copyrightStatement?: string
  trademarkProducts?: string
  permissionStatement?: string
}

declare global {
  interface Window {
    vueAppData?: {
      footer?: FooterConfig
    }
  }
}

// Get config with defaults
const config = computed<Required<FooterConfig>>(() => {
  const defaults: Required<FooterConfig> = {
    copyrightSymbol: '©',
    copyrightYear: new Date().getFullYear().toString(),
    organization: 'The MITRE Corporation',
    copyrightStatement: 'All rights reserved',
    trademarkProducts: 'MITRE Vulcan and the MITRE Vulcan logo',
    permissionStatement: 'Material on this site may be copied and distributed with permission only',
  }

  return {
    ...defaults,
    ...window.vueAppData?.footer,
  }
})

// Template rendering - two lines
const line1 = computed(() =>
  `Copyright ${config.value.copyrightSymbol} ${config.value.copyrightYear}, ${config.value.organization}. ${config.value.copyrightStatement}.`,
)

const line2 = computed(() =>
  `${config.value.trademarkProducts} are trademarks of ${config.value.organization}. ${config.value.permissionStatement}.`,
)
</script>

<template>
  <div class="footer-copyright text-center py-2">
    <p class="mb-1 text-white-50">
      {{ line1 }}
    </p>
    <p class="mb-0 text-white-50">
      {{ line2 }}
    </p>
  </div>
</template>

<style scoped>
.footer-copyright {
  font-size: 0.75rem;
  line-height: 1.5;
}
</style>
