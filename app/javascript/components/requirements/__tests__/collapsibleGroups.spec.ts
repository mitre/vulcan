/**
 * Tests for collapsible status groups functionality in RequirementsTable
 *
 * The collapsible groups feature allows users to collapse/expand status groups
 * in the grouped view, with state persisted to localStorage.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => {
      store[key] = value
    }),
    removeItem: vi.fn((key: string) => {
      delete store[key]
    }),
    clear: vi.fn(() => {
      store = {}
    }),
    get store() {
      return store
    },
  }
})()

Object.defineProperty(window, 'localStorage', { value: localStorageMock })

// Constants matching RequirementsTable.vue
const COLLAPSED_GROUPS_KEY = 'vulcan-collapsed-status-groups'

describe('collapsible Status Groups', () => {
  beforeEach(() => {
    localStorageMock.clear()
    vi.clearAllMocks()
  })

  describe('localStorage persistence', () => {
    it('stores collapsed groups as JSON array', () => {
      const collapsedGroups = ['Not Yet Determined', 'Not Applicable']
      localStorage.setItem(COLLAPSED_GROUPS_KEY, JSON.stringify(collapsedGroups))

      const saved = localStorage.getItem(COLLAPSED_GROUPS_KEY)
      expect(saved).not.toBeNull()
      expect(JSON.parse(saved!)).toEqual(collapsedGroups)
    })

    it('handles empty collapsed groups', () => {
      localStorage.setItem(COLLAPSED_GROUPS_KEY, JSON.stringify([]))

      const saved = localStorage.getItem(COLLAPSED_GROUPS_KEY)
      expect(JSON.parse(saved!)).toEqual([])
    })

    it('returns null when no saved state exists', () => {
      const saved = localStorage.getItem(COLLAPSED_GROUPS_KEY)
      expect(saved).toBeNull()
    })
  })

  describe('collapsible group logic', () => {
    // Simulating the component logic
    function createCollapsibleGroupState() {
      let collapsedGroups = new Set<string>()

      function loadCollapsedGroups() {
        try {
          const saved = localStorage.getItem(COLLAPSED_GROUPS_KEY)
          if (saved) {
            collapsedGroups = new Set(JSON.parse(saved))
          }
        }
        catch {
          // Ignore parse errors
        }
      }

      function saveCollapsedGroups() {
        localStorage.setItem(COLLAPSED_GROUPS_KEY, JSON.stringify([...collapsedGroups]))
      }

      function toggleGroupCollapsed(status: string) {
        if (collapsedGroups.has(status)) {
          collapsedGroups.delete(status)
        }
        else {
          collapsedGroups.add(status)
        }
        collapsedGroups = new Set(collapsedGroups)
        saveCollapsedGroups()
      }

      function isGroupCollapsed(status: string): boolean {
        return collapsedGroups.has(status)
      }

      return {
        get collapsedGroups() {
          return collapsedGroups
        },
        loadCollapsedGroups,
        saveCollapsedGroups,
        toggleGroupCollapsed,
        isGroupCollapsed,
      }
    }

    it('starts with no collapsed groups', () => {
      const state = createCollapsibleGroupState()
      expect(state.collapsedGroups.size).toBe(0)
    })

    it('toggles a group to collapsed state', () => {
      const state = createCollapsibleGroupState()

      state.toggleGroupCollapsed('Not Yet Determined')

      expect(state.isGroupCollapsed('Not Yet Determined')).toBe(true)
      expect(state.collapsedGroups.size).toBe(1)
    })

    it('toggles a collapsed group back to expanded', () => {
      const state = createCollapsibleGroupState()

      state.toggleGroupCollapsed('Not Yet Determined')
      expect(state.isGroupCollapsed('Not Yet Determined')).toBe(true)

      state.toggleGroupCollapsed('Not Yet Determined')
      expect(state.isGroupCollapsed('Not Yet Determined')).toBe(false)
    })

    it('can collapse multiple groups independently', () => {
      const state = createCollapsibleGroupState()

      state.toggleGroupCollapsed('Not Yet Determined')
      state.toggleGroupCollapsed('Not Applicable')

      expect(state.isGroupCollapsed('Not Yet Determined')).toBe(true)
      expect(state.isGroupCollapsed('Not Applicable')).toBe(true)
      expect(state.isGroupCollapsed('Applicable - Configurable')).toBe(false)
    })

    it('saves to localStorage on toggle', () => {
      const state = createCollapsibleGroupState()

      state.toggleGroupCollapsed('Not Yet Determined')

      expect(localStorageMock.setItem).toHaveBeenCalledWith(
        COLLAPSED_GROUPS_KEY,
        JSON.stringify(['Not Yet Determined']),
      )
    })

    it('loads collapsed state from localStorage', () => {
      // Pre-populate localStorage
      localStorage.setItem(COLLAPSED_GROUPS_KEY, JSON.stringify(['Not Applicable', 'Not Yet Determined']))

      const state = createCollapsibleGroupState()
      state.loadCollapsedGroups()

      expect(state.isGroupCollapsed('Not Applicable')).toBe(true)
      expect(state.isGroupCollapsed('Not Yet Determined')).toBe(true)
      expect(state.isGroupCollapsed('Applicable - Configurable')).toBe(false)
    })

    it('handles invalid JSON in localStorage gracefully', () => {
      localStorage.setItem(COLLAPSED_GROUPS_KEY, 'not valid json')

      const state = createCollapsibleGroupState()
      // Should not throw
      expect(() => state.loadCollapsedGroups()).not.toThrow()
      expect(state.collapsedGroups.size).toBe(0)
    })

    it('persists state across multiple toggles', () => {
      const state = createCollapsibleGroupState()

      state.toggleGroupCollapsed('Not Yet Determined')
      state.toggleGroupCollapsed('Not Applicable')
      state.toggleGroupCollapsed('Not Yet Determined') // Toggle back off

      const saved = JSON.parse(localStorage.getItem(COLLAPSED_GROUPS_KEY)!)
      expect(saved).toEqual(['Not Applicable'])
    })
  })

  describe('status group values', () => {
    const RULE_STATUSES = [
      'Not Yet Determined',
      'Applicable - Configurable',
      'Applicable - Inherently Meets',
      'Applicable - Does Not Meet',
      'Not Applicable',
    ]

    it('handles all valid status values', () => {
      const collapsedGroups = new Set<string>()

      for (const status of RULE_STATUSES) {
        collapsedGroups.add(status)
      }

      expect(collapsedGroups.size).toBe(5)
      for (const status of RULE_STATUSES) {
        expect(collapsedGroups.has(status)).toBe(true)
      }
    })
  })
})
