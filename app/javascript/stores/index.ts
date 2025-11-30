/**
 * Pinia Store Configuration
 * Central export for all stores
 */

import { createPinia } from 'pinia'

export const pinia = createPinia()

// Disable dev notifications
pinia.use(() => {}) // Empty plugin to suppress install messages

// Re-export all stores for convenient imports
export { useAuthStore } from './auth.store'
export { useComponentsStore } from './components.store'
export { useFindReplaceStore } from './findReplace.store'
export type { FlatMatch, UndoEntry } from './findReplace.store'
export { useNavigationStore } from './navigation.store'
export { useProjectsStore } from './projects.store'
export { RULE_SEVERITIES, RULE_STATUSES, SEVERITY_MAP, useRulesStore } from './rules.store'
export { useSrgsStore } from './srgs.store'
export { useStigsStore } from './stigs.store'
export { useUsersStore } from './users.store'
