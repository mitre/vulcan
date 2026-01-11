<script setup lang="ts">
import { computed } from 'vue'
import { useColorMode } from '@/composables'
import ClassificationBanner from '@/components/shared/ClassificationBanner.vue'
import IBiShieldLock from '~icons/bi/shield-lock'
import IBiSunFill from '~icons/bi/sun-fill'
import IBiMoonFill from '~icons/bi/moon-fill'
import IBiCircleHalf from '~icons/bi/circle-half'

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
  <!-- Classification Banner -->
  <ClassificationBanner />

  <!-- Header with dark mode cycle -->
  <header class="py-3 px-4">
    <div class="container-fluid d-flex justify-content-between align-items-center">
      <div class="d-flex align-items-center gap-2">
        <IBiShieldLock style="font-size: 1.5rem;" />
        <span class="fw-bold">Vulcan</span>
      </div>

      <button
        type="button"
        class="btn btn-sm btn-outline-secondary"
        :title="colorModeTitle"
        @click="cycleColorMode"
      >
        <IBiSunFill v-if="colorModeIcon === 'sun'" />
        <IBiMoonFill v-else-if="colorModeIcon === 'moon'" />
        <IBiCircleHalf v-else />
      </button>
    </div>
  </header>
</template>
