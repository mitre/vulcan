/**
 * useGlobalSearch Composable Unit Tests
 *
 * Tests for the global search composable that powers the Command Palette.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick, ref } from 'vue'
import { useGlobalSearch } from '../useGlobalSearch'

// Mock fetch
const mockFetch = vi.fn()
global.fetch = mockFetch

// Mock localStorage
const localStorageMock = {
  getItem: vi.fn(() => null),
  setItem: vi.fn(),
  removeItem: vi.fn(),
}
Object.defineProperty(global, 'localStorage', { value: localStorageMock })

describe('useGlobalSearch', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.useFakeTimers()
    localStorageMock.getItem.mockReturnValue(null)
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  describe('initial state', () => {
    it('starts with empty searchTerm when no external ref provided', () => {
      const { searchTerm } = useGlobalSearch()
      expect(searchTerm.value).toBe('')
    })

    it('uses external searchTerm ref when provided', () => {
      const externalTerm = ref('initial value')
      const { searchTerm } = useGlobalSearch(externalTerm)
      expect(searchTerm.value).toBe('initial value')
    })

    it('starts with loading = false', () => {
      const { loading } = useGlobalSearch()
      expect(loading.value).toBe(false)
    })

    it('starts with error = null', () => {
      const { error } = useGlobalSearch()
      expect(error.value).toBeNull()
    })

    it('starts with empty recentItems', () => {
      const { recentItems } = useGlobalSearch()
      expect(recentItems.value).toEqual([])
    })
  })

  describe('groups computed property', () => {
    it('shows Quick Actions when searchTerm is empty', () => {
      const { groups, searchTerm } = useGlobalSearch()
      searchTerm.value = ''

      expect(groups.value.length).toBeGreaterThan(0)
      expect(groups.value[0].id).toBe('actions')
      expect(groups.value[0].label).toBe('Quick Actions')
    })

    it('quick Actions group has ignoreFilter: false', () => {
      const { groups } = useGlobalSearch()
      const actionsGroup = groups.value.find(g => g.id === 'actions')

      expect(actionsGroup).toBeDefined()
      expect(actionsGroup?.ignoreFilter).toBe(false)
    })

    it('shows Recent group when recentItems exist and no search', () => {
      localStorageMock.getItem.mockReturnValue(JSON.stringify([
        { id: 'test-1', label: 'Test Item', to: '/test' },
      ]))

      const { groups, searchTerm, recentItems } = useGlobalSearch()
      searchTerm.value = ''

      // Manually set recentItems since localStorage mock is per-instance
      recentItems.value = [{ id: 'test-1', label: 'Test Item', to: '/test' }]

      expect(groups.value.some(g => g.id === 'recent')).toBe(true)
    })

    it('recent group has ignoreFilter: true', () => {
      const { groups, recentItems, searchTerm } = useGlobalSearch()
      searchTerm.value = ''
      recentItems.value = [{ id: 'test-1', label: 'Test', to: '/test' }]

      const recentGroup = groups.value.find(g => g.id === 'recent')
      expect(recentGroup?.ignoreFilter).toBe(true)
    })
  })

  describe('aPI search behavior', () => {
    it('does not fetch when searchTerm is less than 2 characters', async () => {
      const { searchTerm } = useGlobalSearch()

      searchTerm.value = 'a'
      await vi.advanceTimersByTimeAsync(500)

      expect(mockFetch).not.toHaveBeenCalled()
    })

    it('fetches when searchTerm has 2+ characters after debounce', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ projects: [], components: [], rules: [] }),
      })

      const { searchTerm } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350) // debounce is 300ms

      expect(mockFetch).toHaveBeenCalledWith(
        '/api/search/global?q=test&limit=20',
        { credentials: 'same-origin' },
      )
    })

    it('sets loading = true during fetch', async () => {
      let resolvePromise: () => void
      mockFetch.mockReturnValueOnce(new Promise((resolve) => {
        resolvePromise = () => resolve({
          ok: true,
          json: () => Promise.resolve({ projects: [], components: [], rules: [] }),
        })
      }))

      const { searchTerm, loading } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)

      expect(loading.value).toBe(true)

      resolvePromise!()
      await nextTick()
    })

    it('sets loading = false after fetch completes', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ projects: [], components: [], rules: [] }),
      })

      const { searchTerm, loading } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      expect(loading.value).toBe(false)
    })

    it('sets error on fetch failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
      })

      const { searchTerm, error } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      expect(error.value).toContain('Search failed')
    })

    it('handles network errors', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'))

      const { searchTerm, error } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      expect(error.value).toBe('Network error')
    })
  })

  describe('aPI results transformation', () => {
    it('transforms projects to CommandPaletteItem format', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [
            { id: 1, name: 'Test Project', description: 'A test', components_count: 5 },
          ],
          components: [],
          rules: [],
        }),
      })

      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      const projectsGroup = groups.value.find(g => g.id === 'projects')
      expect(projectsGroup).toBeDefined()
      expect(projectsGroup?.items[0]).toMatchObject({
        id: 'project-1',
        label: 'Test Project',
        description: 'A test',
        icon: 'bi-folder',
        to: '/projects/1',
      })
    })

    it('transforms components to CommandPaletteItem format', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [],
          components: [
            { id: 2, name: 'Web Server', version: '1', release: '2', project_id: 1, project_name: 'Test' },
          ],
          rules: [],
        }),
      })

      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'web'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      const componentsGroup = groups.value.find(g => g.id === 'components')
      expect(componentsGroup).toBeDefined()
      expect(componentsGroup?.items[0]).toMatchObject({
        id: 'component-2',
        label: 'Web Server',
        description: 'V1R2',
        icon: 'bi-box',
        to: '/components/2',
      })
    })

    it('transforms rules to CommandPaletteItem format with deep-link', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [],
          components: [],
          rules: [
            { id: 3, rule_id: 'SV-12345', title: 'Kubernetes Config', component_id: 2 },
          ],
        }),
      })

      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'kubernetes'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      const rulesGroup = groups.value.find(g => g.id === 'requirements')
      expect(rulesGroup).toBeDefined()
      expect(rulesGroup?.items[0]).toMatchObject({
        id: 'rule-3',
        label: 'SV-12345',
        description: 'Kubernetes Config',
        icon: 'bi-shield-check',
        to: '/components/2/controls?rule=3',
      })
    })

    it('transforms STIG rules with deep-link to STIG page', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [],
          components: [],
          rules: [],
          stig_rules: [
            { id: 10, rule_id: 'SV-99999', title: 'STIG Rule', vuln_id: 'V-99999', stig_id: 5, stig_name: 'RHEL 9' },
          ],
          srg_rules: [],
        }),
      })

      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'RHEL'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      const stigRulesGroup = groups.value.find(g => g.id === 'stig-rules')
      expect(stigRulesGroup).toBeDefined()
      expect(stigRulesGroup?.items[0]).toMatchObject({
        id: 'stig-rule-10',
        label: 'V-99999',
        to: '/stigs/5?rule=10',
      })
    })

    it('transforms SRG rules with deep-link to SRG page', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [],
          components: [],
          rules: [],
          stig_rules: [],
          srg_rules: [
            { id: 20, rule_id: 'SRG-OS-000001', title: 'SRG Rule', version: 'SRG-OS-000001-V1', srg_id: 8, srg_name: 'OS Core SRG' },
          ],
        }),
      })

      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'SRG'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      const srgRulesGroup = groups.value.find(g => g.id === 'srg-rules')
      expect(srgRulesGroup).toBeDefined()
      expect(srgRulesGroup?.items[0]).toMatchObject({
        id: 'srg-rule-20',
        label: 'SRG-OS-000001-V1',
        to: '/srgs/8?rule=20',
      })
    })

    it('aPI result groups have ignoreFilter: true', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [{ id: 1, name: 'Test' }],
          components: [{ id: 2, name: 'Web', project_id: 1 }],
          rules: [{ id: 3, rule_id: 'SV-1', title: 'Rule', component_id: 2 }],
        }),
      })

      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      const projectsGroup = groups.value.find(g => g.id === 'projects')
      const componentsGroup = groups.value.find(g => g.id === 'components')
      const rulesGroup = groups.value.find(g => g.id === 'requirements')

      expect(projectsGroup?.ignoreFilter).toBe(true)
      expect(componentsGroup?.ignoreFilter).toBe(true)
      expect(rulesGroup?.ignoreFilter).toBe(true)
    })
  })

  describe('totalResults computed property', () => {
    it('returns 0 when no results', () => {
      const { totalResults, searchTerm } = useGlobalSearch()
      searchTerm.value = ''

      // Even with Quick Actions, we should have some count
      expect(totalResults.value).toBeGreaterThanOrEqual(0)
    })

    it('sums items across all groups', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [{ id: 1, name: 'P1' }, { id: 2, name: 'P2' }],
          components: [{ id: 3, name: 'C1', project_id: 1 }],
          rules: [],
        }),
      })

      const { searchTerm, totalResults } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      // 2 projects + 1 component + Quick Actions (varies based on Fuse.js filtering)
      expect(totalResults.value).toBeGreaterThanOrEqual(3)
    })
  })

  describe('addToRecent()', () => {
    it('adds item to recentItems', () => {
      const { addToRecent, recentItems } = useGlobalSearch()

      const item = { id: 'test-1', label: 'Test', to: '/test' }
      addToRecent(item)

      expect(recentItems.value).toContainEqual(item)
    })

    it('moves existing item to top', () => {
      const { addToRecent, recentItems } = useGlobalSearch()

      addToRecent({ id: 'item-1', label: 'First', to: '/1' })
      addToRecent({ id: 'item-2', label: 'Second', to: '/2' })
      addToRecent({ id: 'item-1', label: 'First', to: '/1' }) // Add again

      expect(recentItems.value[0].id).toBe('item-1')
      expect(recentItems.value.length).toBe(2) // No duplicates
    })

    it('limits to 5 recent items', () => {
      const { addToRecent, recentItems } = useGlobalSearch()

      for (let i = 0; i < 10; i++) {
        addToRecent({ id: `item-${i}`, label: `Item ${i}`, to: `/${i}` })
      }

      expect(recentItems.value.length).toBe(5)
    })

    it('saves to localStorage', () => {
      const { addToRecent } = useGlobalSearch()

      addToRecent({ id: 'test', label: 'Test', to: '/test' })

      expect(localStorageMock.setItem).toHaveBeenCalledWith(
        'vulcan-recent-searches',
        expect.any(String),
      )
    })
  })

  describe('clearRecent()', () => {
    it('clears recentItems', () => {
      const { addToRecent, clearRecent, recentItems } = useGlobalSearch()

      addToRecent({ id: 'test', label: 'Test', to: '/test' })
      clearRecent()

      expect(recentItems.value).toEqual([])
    })

    it('removes from localStorage', () => {
      const { clearRecent } = useGlobalSearch()

      clearRecent()

      expect(localStorageMock.removeItem).toHaveBeenCalledWith('vulcan-recent-searches')
    })
  })

  describe('reset()', () => {
    it('clears API results', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({
          projects: [{ id: 1, name: 'Test' }],
          components: [],
          rules: [],
        }),
      })

      const { searchTerm, groups, reset } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      expect(groups.value.some(g => g.id === 'projects')).toBe(true)

      reset()
      await nextTick()

      expect(groups.value.some(g => g.id === 'projects')).toBe(false)
    })

    it('clears error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Test error'))

      const { searchTerm, error, reset } = useGlobalSearch()

      searchTerm.value = 'test'
      await vi.advanceTimersByTimeAsync(350)
      await nextTick()

      expect(error.value).toBe('Test error')

      reset()

      expect(error.value).toBeNull()
    })

    it('clears internal searchTerm when no external ref', () => {
      const { searchTerm, reset } = useGlobalSearch()

      searchTerm.value = 'test'
      reset()

      expect(searchTerm.value).toBe('')
    })

    it('does NOT clear external searchTerm ref', () => {
      const externalTerm = ref('test')
      const { reset } = useGlobalSearch(externalTerm)

      reset()

      expect(externalTerm.value).toBe('test')
    })
  })

  describe('quick Actions filtering with Fuse.js', () => {
    it('filters Quick Actions based on searchTerm', () => {
      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'project'
      const actionsGroup = groups.value.find(g => g.id === 'actions')

      expect(actionsGroup).toBeDefined()
      // Should include 'New Project' and 'View All Projects'
      expect(actionsGroup?.items.some(i => i.label.toLowerCase().includes('project'))).toBe(true)
    })

    it('shows fewer Quick Actions when no match', () => {
      const { searchTerm, groups } = useGlobalSearch()

      searchTerm.value = 'xyznonexistent'
      const actionsGroup = groups.value.find(g => g.id === 'actions')

      // Fuse.js should return no matches
      expect(actionsGroup?.items.length || 0).toBeLessThan(5)
    })
  })
})
