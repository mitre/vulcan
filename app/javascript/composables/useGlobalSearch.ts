/**
 * useGlobalSearch - Global search composable for Command Palette
 *
 * Provides search across projects, components, and rules using:
 * - Fuse.js for quick actions (client-side filtering)
 * - pg_search for API results (server-side filtering)
 *
 * Based on Nuxt UI v4 CommandPalette patterns.
 */

import type { Ref } from 'vue'
import type { CommandPaletteGroup, CommandPaletteItem } from '@/types/command-palette'
import { useDebounceFn } from '@vueuse/core'
import Fuse from 'fuse.js'
import { computed, ref, watch } from 'vue'
import { getQuickActions } from '@/config/command-palette.config'
import { useAuthStore } from '@/stores'

// Fuse.js options for fuzzy matching quick actions
const FUSE_OPTIONS: Fuse.IFuseOptions<CommandPaletteItem> = {
  keys: [
    { name: 'label', weight: 0.7 },
    { name: 'description', weight: 0.3 },
  ],
  threshold: 0.4,
  includeScore: true,
  includeMatches: true,
  minMatchCharLength: 2,
}

// Recent items storage key
const RECENT_ITEMS_KEY = 'vulcan-recent-searches'
const MAX_RECENT_ITEMS = 5

/**
 * Global search composable for Command Palette.
 *
 * @param externalSearchTerm - Optional external ref for search term.
 *   If provided, the composable watches this ref.
 *   If not provided, creates internal searchTerm ref.
 *
 * @example
 * ```typescript
 * // With external search term (recommended for Command Palette)
 * const searchTerm = ref('')
 * const { groups, loading } = useGlobalSearch(searchTerm)
 *
 * // With internal search term
 * const { searchTerm, groups, loading } = useGlobalSearch()
 * ```
 */
export function useGlobalSearch(externalSearchTerm?: Ref<string>) {
  // Use external or internal searchTerm
  const internalSearchTerm = ref('')
  const searchTerm = externalSearchTerm ?? internalSearchTerm

  const loading = ref(false)
  const error = ref<string | null>(null)

  // Get auth store for admin status
  const authStore = useAuthStore()

  // Cached data from API
  // Parent objects (containers)
  const projects = ref<CommandPaletteItem[]>([])
  const components = ref<CommandPaletteItem[]>([])
  const stigs = ref<CommandPaletteItem[]>([])
  const srgs = ref<CommandPaletteItem[]>([])
  // Child objects (content within containers)
  const rules = ref<CommandPaletteItem[]>([])
  const stigRules = ref<CommandPaletteItem[]>([])
  const srgRules = ref<CommandPaletteItem[]>([])

  // Recent items from localStorage
  const recentItems = ref<CommandPaletteItem[]>(loadRecentItems())

  // Quick actions based on user role (includes admin actions for admins)
  const quickActions = computed(() => getQuickActions(authStore.isAdmin))

  // Fuse instance for quick actions - recreate when actions change
  const actionsFuse = computed(() => new Fuse(quickActions.value, FUSE_OPTIONS))

  // Filtered quick actions (Fuse.js client-side)
  const filteredActions = computed(() => {
    if (!searchTerm.value.trim()) return quickActions.value.slice(0, 3)
    return actionsFuse.value.search(searchTerm.value).map(r => r.item).slice(0, 5)
  })

  // Grouped results for display
  // Each group has ignoreFilter to indicate filtering behavior
  const groups = computed<CommandPaletteGroup[]>(() => {
    const result: CommandPaletteGroup[] = []

    // Show recent items when no search term
    if (!searchTerm.value.trim() && recentItems.value.length > 0) {
      result.push({
        id: 'recent',
        label: 'Recent',
        icon: 'bi-clock-history',
        items: recentItems.value,
        ignoreFilter: true, // Already selected items, no filtering
      })
    }

    // Quick actions - Fuse.js filters these
    if (filteredActions.value.length > 0) {
      result.push({
        id: 'actions',
        label: 'Quick Actions',
        icon: 'bi-lightning',
        items: filteredActions.value,
        ignoreFilter: false, // Fuse.js filters these client-side
      })
    }

    // API results - only show when searching (length >= 2)
    if (searchTerm.value.trim().length >= 2) {
      // ===== PARENT OBJECTS (containers) - show first, limit 5 =====

      // Projects
      if (projects.value.length > 0) {
        result.push({
          id: 'projects',
          label: 'Projects',
          icon: 'bi-folder',
          items: projects.value.slice(0, 5),
          ignoreFilter: true,
        })
      }

      // Components (STIGs in progress)
      if (components.value.length > 0) {
        result.push({
          id: 'components',
          label: 'Components',
          icon: 'bi-box',
          items: components.value.slice(0, 5),
          ignoreFilter: true,
        })
      }

      // STIGs (published STIG documents)
      if (stigs.value.length > 0) {
        result.push({
          id: 'stigs',
          label: 'STIGs',
          icon: 'bi-file-earmark-lock',
          items: stigs.value.slice(0, 5),
          ignoreFilter: true,
        })
      }

      // SRGs (Security Requirements Guide documents)
      if (srgs.value.length > 0) {
        result.push({
          id: 'srgs',
          label: 'SRGs',
          icon: 'bi-file-earmark-text',
          items: srgs.value.slice(0, 5),
          ignoreFilter: true,
        })
      }

      // ===== CHILD OBJECTS (content within containers) =====

      // Requirements (rules within components)
      if (rules.value.length > 0) {
        result.push({
          id: 'requirements',
          label: 'Requirements',
          icon: 'bi-shield-check',
          items: rules.value,
          ignoreFilter: true,
        })
      }

      // STIG Requirements (rules within STIGs)
      if (stigRules.value.length > 0) {
        result.push({
          id: 'stig-rules',
          label: 'STIG Requirements',
          icon: 'bi-list-check',
          items: stigRules.value,
          ignoreFilter: true,
        })
      }

      // SRG Requirements (rules within SRGs)
      if (srgRules.value.length > 0) {
        result.push({
          id: 'srg-rules',
          label: 'SRG Requirements',
          icon: 'bi-list-ul',
          items: srgRules.value,
          ignoreFilter: true,
        })
      }
    }

    return result
  })

  // Total result count
  const totalResults = computed(() => {
    return groups.value.reduce((sum, g) => sum + g.items.length, 0)
  })

  // Debounced API fetch
  const fetchSearchData = useDebounceFn(async () => {
    const query = searchTerm.value.trim()
    if (!query || query.length < 2) {
      // Clear results if query is too short
      projects.value = []
      components.value = []
      rules.value = []
      return
    }

    loading.value = true
    error.value = null

    try {
      const response = await fetch(`/api/search/global?q=${encodeURIComponent(query)}&limit=20`, {
        credentials: 'same-origin', // Include session cookie for authentication
      })

      if (!response.ok) {
        throw new Error(`Search failed: ${response.status}`)
      }

      const data = await response.json()

      // Transform API response to CommandPaletteItem format
      projects.value = (data.projects || []).map((p: any) => ({
        id: `project-${p.id}`,
        label: p.name,
        description: p.description || `${p.components_count || 0} components`,
        icon: 'bi-folder',
        to: `/projects/${p.id}`,
        meta: { type: 'project', ...p },
      }))

      components.value = (data.components || []).map((c: any) => ({
        id: `component-${c.id}`,
        label: c.name,
        description: c.version ? `V${c.version}R${c.release || '0'}` : c.project_name,
        icon: 'bi-box',
        to: `/components/${c.id}`,
        meta: { type: 'component', ...c },
      }))

      // ===== PARENT OBJECTS (containers) =====

      // STIGs - published STIG documents
      stigs.value = (data.stigs || []).map((s: any) => ({
        id: `stig-${s.id}`,
        label: s.name,
        description: `${s.title} (${s.rules_count} rules)`,
        icon: 'bi-file-earmark-lock',
        to: `/stigs/${s.id}`,
        meta: { type: 'stig', ...s },
      }))

      // SRGs - Security Requirements Guide documents
      srgs.value = (data.srgs || []).map((s: any) => ({
        id: `srg-${s.id}`,
        label: s.name,
        description: `${s.title} (${s.rules_count} rules)`,
        icon: 'bi-file-earmark-text',
        to: `/srgs/${s.id}`,
        meta: { type: 'srg', ...s },
      }))

      // ===== CHILD OBJECTS (content within containers) =====

      // Requirements - rules within components
      // Use snippet if available (shows context around match), fallback to title
      rules.value = (data.rules || []).map((r: any) => ({
        id: `rule-${r.id}`,
        label: r.rule_id,
        description: r.snippet || r.title,
        icon: 'bi-shield-check',
        to: `/components/${r.component_id}/controls?rule=${r.id}`,
        meta: { type: 'rule', ...r },
      }))

      // STIG Requirements - rules within STIGs
      stigRules.value = (data.stig_rules || []).map((r: any) => ({
        id: `stig-rule-${r.id}`,
        label: r.vuln_id || r.rule_id,
        description: r.snippet || r.title,
        suffix: r.stig_name ? `In: ${r.stig_name}` : undefined,
        icon: 'bi-list-check',
        to: `/stigs/${r.stig_id}?rule=${r.id}`,
        meta: { type: 'stig_rule', ...r },
      }))

      // SRG Requirements - rules within SRGs
      srgRules.value = (data.srg_rules || []).map((r: any) => ({
        id: `srg-rule-${r.id}`,
        label: r.version || r.rule_id,
        description: r.snippet || r.title,
        suffix: r.srg_name ? `In: ${r.srg_name}` : undefined,
        icon: 'bi-list-ul',
        to: `/srgs/${r.srg_id}?rule=${r.id}`,
        meta: { type: 'srg_rule', ...r },
      }))
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Search failed'
      console.error('Global search error:', err)
    }
    finally {
      loading.value = false
    }
  }, 300)

  // Watch search term and trigger fetch
  watch(searchTerm, (newValue) => {
    if (newValue.trim().length >= 2) {
      fetchSearchData()
    }
    else {
      // Clear results when query is cleared
      projects.value = []
      components.value = []
      stigs.value = []
      srgs.value = []
      rules.value = []
      stigRules.value = []
      srgRules.value = []
    }
  })

  // Add item to recent searches
  function addToRecent(item: CommandPaletteItem) {
    const filtered = recentItems.value.filter(r => r.id !== item.id)
    recentItems.value = [item, ...filtered].slice(0, MAX_RECENT_ITEMS)
    saveRecentItems(recentItems.value)
  }

  // Clear recent searches
  function clearRecent() {
    recentItems.value = []
    localStorage.removeItem(RECENT_ITEMS_KEY)
  }

  // Reset search state
  function reset() {
    if (!externalSearchTerm) {
      internalSearchTerm.value = ''
    }
    // Parent objects
    projects.value = []
    components.value = []
    stigs.value = []
    srgs.value = []
    // Child objects
    rules.value = []
    stigRules.value = []
    srgRules.value = []
    error.value = null
  }

  return {
    /** Search term (ref) */
    searchTerm,
    /** Loading state */
    loading,
    /** Error message if any */
    error,
    /** Grouped search results with ignoreFilter property */
    groups,
    /** Total number of results across all groups */
    totalResults,
    /** Recently selected items */
    recentItems,
    /** Add an item to recent searches */
    addToRecent,
    /** Clear recent searches */
    clearRecent,
    /** Reset search state */
    reset,
  }
}

// Helper functions for localStorage
function loadRecentItems(): CommandPaletteItem[] {
  try {
    const stored = localStorage.getItem(RECENT_ITEMS_KEY)
    return stored ? JSON.parse(stored) : []
  }
  catch {
    return []
  }
}

function saveRecentItems(items: CommandPaletteItem[]) {
  try {
    localStorage.setItem(RECENT_ITEMS_KEY, JSON.stringify(items))
  }
  catch {
    // Ignore storage errors
  }
}

// Re-export types for backward compatibility
export type { CommandPaletteGroup, CommandPaletteItem }
