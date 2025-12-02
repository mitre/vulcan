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
export { useAdminDashboard } from './useAdminDashboard'
export { useAdminSettings } from './useAdminSettings'
export { useAudits } from './useAudits'
// Domain composables
export { useAuth } from './useAuth'
// Table composable
export { useBaseTable } from './useBaseTable'
export type { BaseTableConfig, BaseTableReturn } from './useBaseTable'
export { useBenchmarks } from './useBenchmarks'
// UI composables
export { useColorMode } from './useColorMode'
export type { ColorMode } from './useColorMode'
export { useCommandPalette } from './useCommandPalette'
export { useComponents } from './useComponents'
// Confirmation modal composable (programmatic dialogs)
export { useConfirmModal } from './useConfirmModal'
export type { ConfirmOptions } from './useConfirmModal'
// Rails integration composables
export { useCsrfToken } from './useCsrfToken'
export { formatDate, formatDateTime, formatRelative, useDateTime } from './useDateTime'

export { useDeleteConfirmation } from './useDeleteConfirmation'
export type { DeleteConfirmationConfig, DeleteConfirmationReturn } from './useDeleteConfirmation'
export { useGlobalSearch } from './useGlobalSearch'
// Keyboard shortcuts composable
export {
  formatShortcut,
  getKeySymbol,
  isInputFocused,
  isMac,
  isPrimaryModifier,
  KEY_SYMBOLS,
  primaryModifier,
  primaryModifierSymbol,
  useKeyboardShortcuts,
  usePrimaryShortcut,
} from './useKeyboardShortcuts'
export type { ShortcutDefinition } from './useKeyboardShortcuts'
export { useNavigation } from './useNavigation'
// Utility composables
export { hasPermission, isAdmin, isAuthor, isReviewer, isViewer, usePermissions } from './usePermissions'
export { useProfile } from './useProfile'
export { useProjects } from './useProjects'
export { useRailsForm } from './useRailsForm'
export type { RailsFormOptions, RailsMethod } from './useRailsForm'

export { useReleaseCheck } from './useReleaseCheck'

export { RULE_SEVERITIES, RULE_STATUSES, SEVERITY_MAP, useRules } from './useRules'
export { useSrgs } from './useSrgs'
export { useStigs } from './useStigs'
// Toast composable
export { useAppToast } from './useToast'
export type { ToastOptions } from './useToast'
export { useUsers } from './useUsers'
