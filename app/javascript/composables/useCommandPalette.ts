/**
 * useCommandPalette - Command Palette UI state management
 *
 * Uses singleton pattern so all components share the same state.
 *
 * Manages:
 * - Open/close state
 * - Keyboard shortcuts (Cmd+J / Ctrl+J)
 * - Search term
 *
 * Does NOT manage:
 * - Data fetching (see useGlobalSearch)
 * - Results (see useGlobalSearch)
 */

import { useMagicKeys, whenever } from '@vueuse/core'
import { ref, watch } from 'vue'
import { getKeySymbol, isMac } from './useKeyboardShortcuts'

// Singleton state - shared across all component instances
const open = ref(false)
const searchTerm = ref('')
let keyboardShortcutsInitialized = false

/**
 * Composable for Command Palette UI state.
 *
 * Uses singleton pattern so state is shared between App.vue and CommandPalette.vue.
 *
 * @example
 * ```typescript
 * const { open, searchTerm, toggle, close } = useCommandPalette()
 *
 * // Open palette on button click
 * <button @click="open = true">Search</button>
 *
 * // Keyboard shortcut Cmd+J is automatically registered
 * ```
 */
export function useCommandPalette() {
  // Only initialize keyboard shortcuts once (prevents duplicate listeners)
  if (!keyboardShortcutsInitialized) {
    keyboardShortcutsInitialized = true

    // Keyboard shortcut: Cmd+J (Mac) or Ctrl+J (Windows/Linux)
    // Using J instead of K to avoid conflicts with browser shortcuts
    const { meta_j, ctrl_j } = useMagicKeys({
      passive: false,
      onEventFired(e) {
        if ((e.metaKey || e.ctrlKey) && e.key === 'j') {
          e.preventDefault()
        }
      },
    })

    whenever(meta_j, () => {
      open.value = true
    })

    whenever(ctrl_j, () => {
      open.value = true
    })

    // Reset search term when closing
    watch(open, (isOpen) => {
      if (!isOpen) {
        searchTerm.value = ''
      }
    })
  }

  /**
   * Toggle the command palette open/closed
   */
  function toggle() {
    open.value = !open.value
  }

  /**
   * Close the command palette
   */
  function close() {
    open.value = false
  }

  return {
    /** Whether the command palette is open */
    open,
    /** Current search term */
    searchTerm,
    /** Toggle open/closed */
    toggle,
    /** Close the palette */
    close,
    /** Whether running on Mac (for displaying shortcuts) */
    isMac,
    /** Get platform-specific key symbol */
    getKeySymbol,
  }
}
