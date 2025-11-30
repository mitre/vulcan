/**
 * Cross-Platform Keyboard Shortcuts Composable
 *
 * Provides utilities for handling keyboard shortcuts consistently
 * across macOS, Windows, and Linux.
 *
 * Uses VueUse's useMagicKeys under the hood.
 */

import { useMagicKeys, whenever } from '@vueuse/core'
import { computed, onUnmounted, type Ref } from 'vue'

/**
 * Detect if running on macOS/iOS
 */
export const isMac = computed(() => {
  if (typeof navigator === 'undefined') return false
  return /Mac|iPhone|iPod|iPad/i.test(navigator.platform || navigator.userAgent)
})

/**
 * Get the platform-specific modifier key name
 * Returns 'Cmd' on Mac, 'Ctrl' on others
 */
export const primaryModifier = computed(() => isMac.value ? 'Cmd' : 'Ctrl')

/**
 * Get the platform-specific modifier symbol
 * Returns '⌘' on Mac, 'Ctrl' on others
 */
export const primaryModifierSymbol = computed(() => isMac.value ? '⌘' : 'Ctrl')

/**
 * Standard keyboard symbols for cross-platform display
 * Following Apple HIG and common conventions
 */
export const KEY_SYMBOLS = {
  // Modifiers
  meta: { mac: '⌘', other: 'Ctrl' }, // Command on Mac, Ctrl on Windows/Linux
  ctrl: { mac: '⌃', other: 'Ctrl' },
  alt: { mac: '⌥', other: 'Alt' },
  shift: { mac: '⇧', other: 'Shift' },
  // Special keys
  enter: { mac: '↩', other: 'Enter' },
  backspace: { mac: '⌫', other: 'Backspace' },
  delete: { mac: '⌦', other: 'Del' },
  escape: { mac: 'Esc', other: 'Esc' },
  tab: { mac: '⇥', other: 'Tab' },
  space: { mac: '␣', other: 'Space' },
  // Arrow keys
  up: { mac: '↑', other: '↑' },
  down: { mac: '↓', other: '↓' },
  left: { mac: '←', other: '←' },
  right: { mac: '→', other: '→' },
} as const

/**
 * Get the display string for a key
 */
export function getKeySymbol(key: string): string {
  const lowerKey = key.toLowerCase()
  const symbols = KEY_SYMBOLS[lowerKey as keyof typeof KEY_SYMBOLS]
  if (symbols) {
    return isMac.value ? symbols.mac : symbols.other
  }
  // Return as-is for unknown keys (F1, Home, End, etc.)
  return key
}

/**
 * Format a shortcut for display
 * Automatically converts modifier keys to platform-specific symbols
 *
 * @example
 * formatShortcut('Meta+K') // '⌘K' on Mac, 'Ctrl+K' on Windows
 * formatShortcut('Shift+Enter') // '⇧↩' on Mac, 'Shift+Enter' on Windows
 */
export function formatShortcut(shortcut: string): string {
  const parts = shortcut.split(/[+]/)
  const formattedParts = parts.map(part => getKeySymbol(part.trim()))

  // On Mac, join without separator for cleaner look (⌘⇧K)
  // On Windows/Linux, join with + (Ctrl+Shift+K)
  if (isMac.value) {
    return formattedParts.join('')
  }
  return formattedParts.join('+')
}

/**
 * Shortcut definition
 */
export interface ShortcutDefinition {
  /** Keys to listen for (e.g., 'ctrl+k', 'meta+k', 'escape') */
  keys: string | string[]
  /** Handler function */
  handler: (e: KeyboardEvent) => void
  /** Whether to prevent default behavior */
  preventDefault?: boolean
  /** Whether shortcut works when typing in input */
  allowInInput?: boolean
  /** Condition for shortcut to be active */
  when?: Ref<boolean> | (() => boolean)
}

/**
 * Check if the primary modifier is pressed (Cmd on Mac, Ctrl on others)
 */
export function isPrimaryModifier(e: KeyboardEvent): boolean {
  return isMac.value ? e.metaKey : e.ctrlKey
}

/**
 * Check if currently focused on an input element
 */
export function isInputFocused(): boolean {
  const el = document.activeElement as HTMLElement | null
  if (!el) return false
  const tag = el.tagName?.toLowerCase()
  if (!tag) return false
  return tag === 'input' || tag === 'textarea' || el.isContentEditable === true
}

/**
 * Composable for managing keyboard shortcuts
 *
 * @param shortcuts - Array of shortcut definitions
 * @param options - Configuration options
 *
 * @example
 * useKeyboardShortcuts([
 *   {
 *     keys: ['ctrl+k', 'meta+k'], // Ctrl+K on Win/Linux, Cmd+K on Mac
 *     handler: () => openSearch(),
 *     preventDefault: true,
 *   },
 *   {
 *     keys: 'escape',
 *     handler: () => closeModal(),
 *   },
 *   {
 *     keys: 'n',
 *     handler: () => nextItem(),
 *     allowInInput: false, // Don't trigger when typing
 *     when: () => hasItems.value,
 *   },
 * ])
 */
export function useKeyboardShortcuts(
  shortcuts: ShortcutDefinition[],
  options: { enabled?: Ref<boolean> } = {},
) {
  const { enabled = { value: true } as Ref<boolean> } = options
  const magicKeys = useMagicKeys()

  const cleanups: (() => void)[] = []

  for (const shortcut of shortcuts) {
    const keys = Array.isArray(shortcut.keys) ? shortcut.keys : [shortcut.keys]

    for (const key of keys) {
      // Use whenever to watch for key combinations
      const stop = whenever(
        () => {
          // Check if enabled
          if (!enabled.value) return false

          // Check condition
          if (shortcut.when) {
            const condition = typeof shortcut.when === 'function'
              ? shortcut.when()
              : shortcut.when.value
            if (!condition) return false
          }

          // Check if in input and not allowed
          if (!shortcut.allowInInput && isInputFocused()) {
            // Special case: always allow Escape
            if (!key.toLowerCase().includes('escape')) {
              return false
            }
          }

          // Check if key combo is pressed
          // Handle underscore notation from useMagicKeys
          const normalizedKey = key.toLowerCase().replace(/\+/g, '_')
          return magicKeys[normalizedKey]?.value ?? false
        },
        () => {
          // Create a synthetic event for the handler
          const event = new KeyboardEvent('keydown', {
            key: key.split(/[+_]/).pop() || key,
            ctrlKey: key.toLowerCase().includes('ctrl'),
            metaKey: key.toLowerCase().includes('meta'),
            shiftKey: key.toLowerCase().includes('shift'),
            altKey: key.toLowerCase().includes('alt'),
          })

          if (shortcut.preventDefault) {
            // Note: We can't actually preventDefault on a synthetic event,
            // but useMagicKeys handles this internally
          }

          shortcut.handler(event)
        },
      )

      cleanups.push(stop)
    }
  }

  // Cleanup on unmount
  onUnmounted(() => {
    cleanups.forEach(stop => stop())
  })

  return {
    isMac,
    primaryModifier,
    primaryModifierSymbol,
    formatShortcut,
  }
}

/**
 * Simple hook for a single keyboard shortcut with primary modifier
 * Automatically handles Cmd on Mac, Ctrl on others
 *
 * @example
 * usePrimaryShortcut('k', () => openSearch())
 * usePrimaryShortcut('Backspace', () => clearSearch(), { allowInInput: true })
 */
export function usePrimaryShortcut(
  key: string,
  handler: () => void,
  options: {
    preventDefault?: boolean
    allowInInput?: boolean
    when?: Ref<boolean> | (() => boolean)
    enabled?: Ref<boolean>
  } = {},
) {
  return useKeyboardShortcuts([
    {
      keys: [`ctrl+${key}`, `meta+${key}`],
      handler,
      ...options,
    },
  ], { enabled: options.enabled })
}

export default useKeyboardShortcuts
