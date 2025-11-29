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
export { useNavigationStore } from './navigation.store'
export { useProjectsStore } from './projects.store'
export { useRulesStore, RULE_STATUSES, RULE_SEVERITIES, SEVERITY_MAP } from './rules.store'
export { useSrgsStore } from './srgs.store'
export { useStigsStore } from './stigs.store'
export { useUsersStore } from './users.store'
