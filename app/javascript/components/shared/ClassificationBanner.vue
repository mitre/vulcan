<script setup lang="ts">
/**
 * Classification Banner Component
 * Displays security classification level at top/bottom of pages
 *
 * Classification levels and colors (per DoD standards):
 * - UNCLASSIFIED: Green
 * - CUI (Controlled Unclassified Information): Purple
 * - CONFIDENTIAL: Blue
 * - SECRET: Red
 * - TOP SECRET: Orange
 *
 * Colors are theme-aware (lighter in light mode, darker in dark mode)
 */

import { computed } from 'vue'
import { useColorMode } from '@/composables'

const { resolvedMode } = useColorMode()

// Get classification from window data (set by Rails)
interface WindowWithVueData extends Window {
  vueAppData?: {
    classificationLevel?: string
  }
}

const windowData = (window as WindowWithVueData).vueAppData
const classificationLevel = windowData?.classificationLevel || 'UNCLASSIFIED'

// Map classification levels to colors (DoD standard colors)
// Light mode: Vibrant colors, Dark mode: Slightly muted for better contrast
const classificationColors: Record<string, { light: string, dark: string }> = {
  'UNCLASSIFIED': {
    light: '#28a745', // Bootstrap success green
    dark: '#198754', // Slightly darker for dark mode
  },
  'CUI': {
    light: '#800080',
    dark: '#9d4edd',
  },
  'CONFIDENTIAL': {
    light: '#0033a0',
    dark: '#4361ee',
  },
  'SECRET': {
    light: '#dc3545', // Bootstrap danger red
    dark: '#dc3545',
  },
  'TOP SECRET': {
    light: '#fd7e14', // Bootstrap warning orange
    dark: '#fd7e14',
  },
}

const backgroundColor = computed(() => {
  const colors = classificationColors[classificationLevel.toUpperCase()] || classificationColors['UNCLASSIFIED']
  return resolvedMode.value === 'dark' ? colors.dark : colors.light
})
</script>

<template>
  <div
    class="text-white text-center py-1 small fw-bold user-select-none"
    :style="{ backgroundColor: backgroundColor }"
  >
    {{ classificationLevel }}
  </div>
</template>
