/**
 * useGlobalSearch - Global search composable for Command Palette
 *
 * Provides fuzzy search across projects, components, and rules
 * using Fuse.js with debounced API calls.
 *
 * Inspired by Nuxt UI CommandPalette patterns.
 */

import Fuse from 'fuse.js'
import { computed, ref, watch } from 'vue'
import { useDebounceFn } from '@vueuse/core'

// Types for search results
export interface ISearchItem {
  id: number | string
  type: 'project' | 'component' | 'rule' | 'user' | 'action'
  label: string
  description?: string
  icon?: string
  href?: string
  meta?: Record<string, any>
}

export interface ISearchGroup {
  id: string
  label: string
  icon?: string
  items: ISearchItem[]
}

// Quick actions that don't require API calls
const QUICK_ACTIONS: ISearchItem[] = [
  {
    id: 'new-project',
    type: 'action',
    label: 'New Project',
    description: 'Create a new project',
    icon: 'bi-plus-circle',
    href: '/projects/new',
  },
  {
    id: 'view-projects',
    type: 'action',
    label: 'View All Projects',
    description: 'Browse all projects',
    icon: 'bi-folder',
    href: '/projects',
  },
  {
    id: 'view-components',
    type: 'action',
    label: 'View All Components',
    description: 'Browse all components',
    icon: 'bi-box',
    href: '/components',
  },
  {
    id: 'view-stigs',
    type: 'action',
    label: 'Browse STIGs',
    description: 'View published STIGs',
    icon: 'bi-file-earmark-text',
    href: '/stigs',
  },
  {
    id: 'view-srgs',
    type: 'action',
    label: 'Browse SRGs',
    description: 'View Security Requirements Guides',
    icon: 'bi-shield-check',
    href: '/srgs',
  },
]

// Fuse.js options for fuzzy matching
const FUSE_OPTIONS: Fuse.IFuseOptions<ISearchItem> = {
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

export function useGlobalSearch() {
  const searchTerm = ref('')
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Cached data from API
  const projects = ref<ISearchItem[]>([])
  const components = ref<ISearchItem[]>([])
  const rules = ref<ISearchItem[]>([])

  // Recent items from localStorage
  const recentItems = ref<ISearchItem[]>(loadRecentItems())

  // Fuse instances for each category
  const actionsFuse = new Fuse(QUICK_ACTIONS, FUSE_OPTIONS)
  const projectsFuse = computed(() => new Fuse(projects.value, FUSE_OPTIONS))
  const componentsFuse = computed(() => new Fuse(components.value, FUSE_OPTIONS))
  const rulesFuse = computed(() => new Fuse(rules.value, FUSE_OPTIONS))

  // Filtered results based on search term
  const filteredActions = computed(() => {
    if (!searchTerm.value.trim()) return QUICK_ACTIONS.slice(0, 3)
    return actionsFuse.search(searchTerm.value).map(r => r.item).slice(0, 5)
  })

  const filteredProjects = computed(() => {
    if (!searchTerm.value.trim()) return []
    if (!projects.value.length) return []
    return projectsFuse.value.search(searchTerm.value).map(r => r.item).slice(0, 5)
  })

  const filteredComponents = computed(() => {
    if (!searchTerm.value.trim()) return []
    if (!components.value.length) return []
    return componentsFuse.value.search(searchTerm.value).map(r => r.item).slice(0, 5)
  })

  const filteredRules = computed(() => {
    if (!searchTerm.value.trim()) return []
    if (!rules.value.length) return []
    return rulesFuse.value.search(searchTerm.value).map(r => r.item).slice(0, 5)
  })

  // Grouped results for display
  const groups = computed<ISearchGroup[]>(() => {
    const result: ISearchGroup[] = []

    // Show recent items when no search term
    if (!searchTerm.value.trim() && recentItems.value.length > 0) {
      result.push({
        id: 'recent',
        label: 'Recent',
        icon: 'bi-clock-history',
        items: recentItems.value,
      })
    }

    // Quick actions
    if (filteredActions.value.length > 0) {
      result.push({
        id: 'actions',
        label: 'Quick Actions',
        icon: 'bi-lightning',
        items: filteredActions.value,
      })
    }

    // Projects
    if (filteredProjects.value.length > 0) {
      result.push({
        id: 'projects',
        label: 'Projects',
        icon: 'bi-folder',
        items: filteredProjects.value,
      })
    }

    // Components
    if (filteredComponents.value.length > 0) {
      result.push({
        id: 'components',
        label: 'Components',
        icon: 'bi-box',
        items: filteredComponents.value,
      })
    }

    // Rules (only show if searching)
    if (filteredRules.value.length > 0) {
      result.push({
        id: 'rules',
        label: 'Requirements',
        icon: 'bi-list-check',
        items: filteredRules.value,
      })
    }

    return result
  })

  // Total result count
  const totalResults = computed(() => {
    return groups.value.reduce((sum, g) => sum + g.items.length, 0)
  })

  // Debounced API fetch
  const fetchSearchData = useDebounceFn(async () => {
    if (!searchTerm.value.trim() || searchTerm.value.length < 2) {
      return
    }

    loading.value = true
    error.value = null

    try {
      const response = await fetch(`/api/search/global?q=${encodeURIComponent(searchTerm.value)}&limit=10`)
      if (!response.ok) throw new Error('Search failed')

      const data = await response.json()

      // Transform API response to search items
      projects.value = (data.projects || []).map((p: any) => ({
        id: p.id,
        type: 'project',
        label: p.name,
        description: p.description || `${p.components_count || 0} components`,
        icon: 'bi-folder',
        href: `/projects/${p.id}`,
        meta: p,
      }))

      components.value = (data.components || []).map((c: any) => ({
        id: c.id,
        type: 'component',
        label: c.name,
        description: c.version ? `V${c.version}R${c.release || '0'}` : c.project_name,
        icon: 'bi-box',
        href: `/components/${c.id}`,
        meta: c,
      }))

      rules.value = (data.rules || []).map((r: any) => ({
        id: r.id,
        type: 'rule',
        label: `${r.rule_id}: ${r.title}`,
        description: r.status,
        icon: 'bi-check-circle',
        href: `/components/${r.component_id}/controls?rule=${r.id}`,
        meta: r,
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
  watch(searchTerm, () => {
    if (searchTerm.value.trim().length >= 2) {
      fetchSearchData()
    }
  })

  // Add item to recent searches
  function addToRecent(item: ISearchItem) {
    const filtered = recentItems.value.filter(r => !(r.id === item.id && r.type === item.type))
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
    searchTerm.value = ''
    projects.value = []
    components.value = []
    rules.value = []
    error.value = null
  }

  return {
    searchTerm,
    loading,
    error,
    groups,
    totalResults,
    recentItems,
    addToRecent,
    clearRecent,
    reset,
  }
}

// Helper functions for localStorage
function loadRecentItems(): ISearchItem[] {
  try {
    const stored = localStorage.getItem(RECENT_ITEMS_KEY)
    return stored ? JSON.parse(stored) : []
  }
  catch {
    return []
  }
}

function saveRecentItems(items: ISearchItem[]) {
  try {
    localStorage.setItem(RECENT_ITEMS_KEY, JSON.stringify(items))
  }
  catch {
    // Ignore storage errors
  }
}
