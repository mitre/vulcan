<script setup lang="ts">
import { computed } from 'vue'
import IBiCircleHalf from '~icons/bi/circle-half'
import IBiMoonFill from '~icons/bi/moon-fill'
import IBiShieldLock from '~icons/bi/shield-lock'
import IBiSunFill from '~icons/bi/sun-fill'
import AppBanner from '@/components/shared/AppBanner.vue'
import { useColorMode } from '@/composables'

const { colorMode, resolvedMode, cycleColorMode } = useColorMode()

const colorModeIcon = computed(() => {
  if (colorMode.value === 'auto')
    return 'circle-half'
  return resolvedMode.value === 'dark' ? 'moon' : 'sun'
})

const colorModeTitle = computed(() => {
  const modes: Record<string, string> = {
    light: 'Light mode',
    dark: 'Dark mode',
    auto: 'System preference',
  }
  return modes[colorMode.value] || 'Light mode'
})
</script>

<template>
  <header>
    <!-- App banner (optional colored bar at top) -->
    <AppBanner />

    <!-- Header with dark mode cycle - dark theme -->
    <div class="bg-dark text-light py-3 border-bottom">
      <div class="container-fluid container-app d-flex justify-content-between align-items-center">
        <div class="d-flex align-items-center gap-2">
          <IBiShieldLock style="font-size: 1.5rem;" />
          <span class="fw-bold">Vulcan</span>
        </div>

        <button
          type="button"
          class="btn btn-sm btn-outline-light"
          :title="colorModeTitle"
          @click="cycleColorMode"
        >
          <IBiSunFill v-if="colorModeIcon === 'sun'" />
          <IBiMoonFill v-else-if="colorModeIcon === 'moon'" />
          <IBiCircleHalf v-else />
        </button>
      </div>
    </div>
  </header>
</template>
