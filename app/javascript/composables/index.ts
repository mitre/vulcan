/**
 * Composables Index
 * Central export for all composables
 *
 * Composables are the bridge between components and stores.
 * Pattern: Component → Composable → Store → API
 */

// Requirements composables (hierarchical)
export {
  useRequirementEditor,
  useRequirementFields,
  useRequirementFieldsFromRule,
  useRequirementProgress,
} from './requirements'
// Domain composables
export { useAuth } from './useAuth'
export { useBenchmarks } from './useBenchmarks'
// UI composables
export { useColorMode } from './useColorMode'
export type { ColorMode } from './useColorMode'
export { useCommandPalette } from './useCommandPalette'
export { useComponents } from './useComponents'
export { formatDate, formatDateTime, formatRelative, useDateTime } from './useDateTime'
export { useGlobalSearch } from './useGlobalSearch'
export { useNavigation } from './useNavigation'
// Utility composables
export { hasPermission, isAdmin, isAuthor, isReviewer, isViewer, usePermissions } from './usePermissions'
export { useProjects } from './useProjects'
export { RULE_SEVERITIES, RULE_STATUSES, SEVERITY_MAP, useRules } from './useRules'

export { useSrgs } from './useSrgs'
export { useStigs } from './useStigs'
// Toast composable
export { useAppToast } from './useToast'
export type { ToastOptions } from './useToast'

export { useUsers } from './useUsers'

// Keyboard shortcuts composable
export {
  formatShortcut,
  getKeySymbol,
  isMac,
  isInputFocused,
  isPrimaryModifier,
  KEY_SYMBOLS,
  primaryModifier,
  primaryModifierSymbol,
  useKeyboardShortcuts,
  usePrimaryShortcut,
} from './useKeyboardShortcuts'
export type { ShortcutDefinition } from './useKeyboardShortcuts'
