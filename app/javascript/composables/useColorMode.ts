/**
 * Color Mode Composable
 * Manages light/dark theme with localStorage persistence
 *
 * Bootstrap 5 uses data-bs-theme attribute on <html> element
 * Values: 'light' | 'dark' | 'auto' (follows system preference)
 */

import { ref, watch, onMounted } from 'vue'

export type ColorMode = 'light' | 'dark' | 'auto'

const STORAGE_KEY = 'vulcan-color-mode'

// Shared state across all component instances
const colorMode = ref<ColorMode>('light')
const resolvedMode = ref<'light' | 'dark'>('light')

// Track if we've initialized
let initialized = false

/**
 * Get system preference for color scheme
 */
function getSystemPreference(): 'light' | 'dark' {
  if (typeof window === 'undefined') return 'light'
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

/**
 * Apply theme to document
 */
function applyTheme(mode: 'light' | 'dark') {
  if (typeof document === 'undefined') return
  document.documentElement.setAttribute('data-bs-theme', mode)
  resolvedMode.value = mode
}

/**
 * Resolve 'auto' to actual light/dark based on system preference
 */
function resolveMode(mode: ColorMode): 'light' | 'dark' {
  if (mode === 'auto') {
    return getSystemPreference()
  }
  return mode
}

/**
 * Initialize color mode from storage or default
 */
function initialize() {
  if (initialized || typeof window === 'undefined') return
  initialized = true

  // Load from localStorage
  const stored = localStorage.getItem(STORAGE_KEY) as ColorMode | null
  if (stored && ['light', 'dark', 'auto'].includes(stored)) {
    colorMode.value = stored
  }

  // Apply initial theme
  applyTheme(resolveMode(colorMode.value))

  // Listen for system preference changes (for 'auto' mode)
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (colorMode.value === 'auto') {
      applyTheme(e.matches ? 'dark' : 'light')
    }
  })
}

export function useColorMode() {
  // Initialize on first use
  onMounted(() => {
    initialize()
  })

  // Watch for mode changes
  watch(colorMode, (newMode) => {
    // Persist to localStorage
    localStorage.setItem(STORAGE_KEY, newMode)
    // Apply theme
    applyTheme(resolveMode(newMode))
  })

  /**
   * Set color mode
   */
  function setColorMode(mode: ColorMode) {
    colorMode.value = mode
  }

  /**
   * Toggle between light and dark (skips auto)
   */
  function toggleColorMode() {
    colorMode.value = resolvedMode.value === 'light' ? 'dark' : 'light'
  }

  /**
   * Cycle through all modes: light -> dark -> auto -> light
   */
  function cycleColorMode() {
    const modes: ColorMode[] = ['light', 'dark', 'auto']
    const currentIndex = modes.indexOf(colorMode.value)
    const nextIndex = (currentIndex + 1) % modes.length
    colorMode.value = modes[nextIndex]
  }

  return {
    // State
    colorMode,        // Current setting: 'light' | 'dark' | 'auto'
    resolvedMode,     // Actual applied mode: 'light' | 'dark'

    // Actions
    setColorMode,
    toggleColorMode,
    cycleColorMode,
  }
}
