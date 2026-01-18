<script setup lang="ts">
/**
 * AppBanner Component
 * Generic configurable banner for top/bottom of pages
 * Can be used for classification levels, environment indicators, etc.
 *
 * Configuration via window.vueAppData.banner:
 * - text: Banner text to display
 * - backgroundColor: Bootstrap color name, CSS variable, or hex (default: success)
 * - textColor: Bootstrap color name, CSS variable, or hex (default: white)
 * - enabled: Show/hide banner (default: false)
 *
 * Color formats supported:
 * - Bootstrap names: "success", "primary", "danger", "warning", "info", "dark", "light", "white"
 * - CSS variables: "var(--bs-success)", "var(--custom-color)"
 * - Hex codes: "#198754", "#ffffff"
 */

import { computed } from 'vue'

// Banner config from Rails
interface BannerConfig {
  text?: string
  backgroundColor?: string
  textColor?: string
  enabled?: boolean
}

declare global {
  interface Window {
    vueAppData?: {
      banner?: BannerConfig
    }
  }
}

// Map Bootstrap color names to CSS variables
// This integrates with Bootstrap's theming system
const bootstrapColors: Record<string, string> = {
  primary: 'var(--bs-primary)',
  secondary: 'var(--bs-secondary)',
  success: 'var(--bs-success)',
  danger: 'var(--bs-danger)',
  warning: 'var(--bs-warning)',
  info: 'var(--bs-info)',
  light: 'var(--bs-light)',
  dark: 'var(--bs-dark)',
  white: 'var(--bs-white)',
  black: 'var(--bs-black)',
  muted: 'var(--bs-secondary)',
}

// Convert color name/hex/variable to valid CSS color
function resolveColor(color: string | undefined, defaultColor: string): string {
  if (!color) return defaultColor

  // Already a CSS variable
  if (color.startsWith('var(')) return color

  // Bootstrap color name
  if (bootstrapColors[color.toLowerCase()]) {
    return bootstrapColors[color.toLowerCase()]
  }

  // Hex code or any other valid CSS color
  return color
}

const bannerConfig = computed<BannerConfig>(() => {
  return window.vueAppData?.banner || {}
})

const showBanner = computed(() => {
  return bannerConfig.value.enabled && bannerConfig.value.text
})

const backgroundColor = computed(() => {
  return resolveColor(bannerConfig.value.backgroundColor, 'var(--bs-success)')
})

const textColor = computed(() => {
  return resolveColor(bannerConfig.value.textColor, 'var(--bs-white)')
})
</script>

<template>
  <div
    v-if="showBanner"
    class="app-banner text-center py-1 small fw-bold user-select-none"
    :style="{
      backgroundColor,
      color: textColor,
    }"
  >
    {{ bannerConfig.text }}
  </div>
</template>
