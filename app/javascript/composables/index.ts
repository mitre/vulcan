/**
 * Composables Index
 * Central export for all composables
 *
 * Composables are the bridge between components and stores.
 * Pattern: Component → Composable → Store → API
 */

// Domain composables
export { useAuth } from './useAuth'
export { useBenchmarks } from './useBenchmarks'
export { useComponents } from './useComponents'
export { formatDate, formatDateTime, formatRelative, useDateTime } from './useDateTime'
export { useNavigation } from './useNavigation'
// Utility composables
export { hasPermission, isAdmin, isAuthor, isReviewer, isViewer, usePermissions } from './usePermissions'
export { useProjects } from './useProjects'
// Requirements composables (hierarchical)
export {
  useRequirementFields,
  useRequirementFieldsFromRule,
  useRequirementEditor,
  useRequirementProgress,
} from './requirements'
export { useRules, RULE_STATUSES, RULE_SEVERITIES, SEVERITY_MAP } from './useRules'
export { useSrgs } from './useSrgs'
export { useStigs } from './useStigs'
// Toast composable
export { useAppToast } from './useToast'
export type { ToastOptions } from './useToast'

// UI composables
export { useColorMode } from './useColorMode'
export type { ColorMode } from './useColorMode'

export { useUsers } from './useUsers'
