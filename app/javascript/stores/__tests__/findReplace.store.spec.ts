/**
 * Find & Replace Store Unit Tests
 */

import type { FindResponse } from '@/apis/findReplace.api'
import { beforeEach, describe, expect, it, vi } from 'vitest'
// Import mocked functions for test setup
import * as findReplaceApi from '@/apis/findReplace.api'

import { useFindReplaceStore } from '../findReplace.store'

// Mock the API module
vi.mock('@/apis/findReplace.api', () => ({
  find: vi.fn(),
  replaceInstance: vi.fn(),
  replaceField: vi.fn(),
  replaceAll: vi.fn(),
  undo: vi.fn(),
}))

// Sample match data for tests
const mockFindResponse: FindResponse = {
  total_matches: 5,
  total_rules: 2,
  matches: [
    {
      rule_id: 1,
      rule_identifier: 'SV-001',
      match_count: 3,
      instances: [
        {
          field: 'fixtext',
          instances: [
            { index: 10, length: 4, text: 'sshd', context: '...configure sshd to...' },
            { index: 50, length: 4, text: 'sshd', context: '...restart sshd service...' },
          ],
        },
        {
          field: 'title',
          instances: [
            { index: 5, length: 4, text: 'sshd', context: 'The sshd service' },
          ],
        },
      ],
    },
    {
      rule_id: 2,
      rule_identifier: 'SV-002',
      match_count: 2,
      instances: [
        {
          field: 'fixtext',
          instances: [
            { index: 0, length: 4, text: 'sshd', context: 'sshd configuration...' },
            { index: 30, length: 4, text: 'sshd', context: '...use sshd key...' },
          ],
        },
      ],
    },
  ],
}

describe('findReplace Store', () => {
  let store: ReturnType<typeof useFindReplaceStore>

  beforeEach(() => {
    vi.clearAllMocks()
    store = useFindReplaceStore()
    store.resetAll()
  })

  describe('initial state', () => {
    it('has empty search text', () => {
      expect(store.searchText).toBe('')
    })

    it('has empty replace text', () => {
      expect(store.replaceText).toBe('')
    })

    it('has case sensitive false', () => {
      expect(store.caseSensitive).toBe(false)
    })

    it('has empty matches array', () => {
      expect(store.matches).toEqual([])
    })

    it('has currentIndex at 0', () => {
      expect(store.currentIndex).toBe(0)
    })

    it('has loop enabled', () => {
      expect(store.loop).toBe(true)
    })

    it('is not searching', () => {
      expect(store.isSearching).toBe(false)
    })

    it('is not replacing', () => {
      expect(store.isReplacing).toBe(false)
    })

    it('modal is closed', () => {
      expect(store.isOpen).toBe(false)
    })
  })

  describe('getters', () => {
    it('currentMatch returns null when no matches', () => {
      expect(store.currentMatch).toBeNull()
    })

    it('hasNext returns false when no matches', () => {
      expect(store.hasNext).toBe(false)
    })

    it('hasPrev returns false when no matches', () => {
      expect(store.hasPrev).toBe(false)
    })

    it('progress returns "0 of 0" when no matches', () => {
      expect(store.progress).toBe('0 of 0')
    })

    it('summary returns "No matches" when empty', () => {
      expect(store.summary).toBe('No matches')
    })

    it('canUndo returns false when undoStack is empty', () => {
      expect(store.canUndo).toBe(false)
    })

    it('hasResults returns false when no matches', () => {
      expect(store.hasResults).toBe(false)
    })

    it('isLoading returns false when not searching or replacing', () => {
      expect(store.isLoading).toBe(false)
    })
  })

  describe('search action', () => {
    it('calls API and flattens matches', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)

      store.setSearchText('sshd')
      await store.search(123)

      expect(findReplaceApi.find).toHaveBeenCalledWith(123, {
        search: 'sshd',
        caseSensitive: false,
        fields: undefined,
      })

      // Should have 5 flattened matches
      expect(store.matches).toHaveLength(5)
      expect(store.totalMatches).toBe(5)
      expect(store.totalRules).toBe(2)
    })

    it('resets when search text is too short', async () => {
      store.setSearchText('a')
      await store.search(123)

      expect(findReplaceApi.find).not.toHaveBeenCalled()
      expect(store.matches).toEqual([])
    })

    it('flattens matches correctly', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)

      store.setSearchText('sshd')
      await store.search(123)

      // Check first flattened match
      expect(store.matches[0]).toEqual({
        ruleId: 1,
        ruleIdentifier: 'SV-001',
        field: 'fixtext',
        index: 10,
        length: 4,
        text: 'sshd',
        context: '...configure sshd to...',
        instanceIndex: 0,
      })
    })

    it('sets isSearching during search', async () => {
      let searchingDuringCall = false
      vi.mocked(findReplaceApi.find).mockImplementation(async () => {
        searchingDuringCall = store.isSearching
        return mockFindResponse
      })

      store.setSearchText('sshd')
      await store.search(123)

      expect(searchingDuringCall).toBe(true)
      expect(store.isSearching).toBe(false)
    })

    it('passes selectedFields to API when fields are selected', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)

      store.setSearchText('sshd')
      store.setSelectedFields(['title', 'fixtext'])
      await store.search(123)

      expect(findReplaceApi.find).toHaveBeenCalledWith(123, {
        search: 'sshd',
        caseSensitive: false,
        fields: ['title', 'fixtext'],
      })
    })

    it('passes undefined fields to API when selectedFields is empty', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)

      store.setSearchText('sshd')
      store.setSelectedFields([]) // Explicitly empty
      await store.search(123)

      expect(findReplaceApi.find).toHaveBeenCalledWith(123, {
        search: 'sshd',
        caseSensitive: false,
        fields: undefined,
      })
    })

    it('passes caseSensitive true to API when enabled', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)

      store.setSearchText('sshd')
      store.toggleCaseSensitive() // Enable case sensitive
      await store.search(123)

      expect(findReplaceApi.find).toHaveBeenCalledWith(123, {
        search: 'sshd',
        caseSensitive: true,
        fields: undefined,
      })
    })
  })

  describe('navigation actions', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      await store.search(123)
    })

    it('nextMatch advances currentIndex', () => {
      expect(store.currentIndex).toBe(0)
      store.nextMatch()
      expect(store.currentIndex).toBe(1)
    })

    it('nextMatch wraps around when loop is true', () => {
      store.goToMatch(4) // Last match
      store.nextMatch()
      expect(store.currentIndex).toBe(0)
    })

    it('nextMatch stays at end when loop is false', () => {
      store.toggleLoop() // Disable loop
      store.goToMatch(4)
      store.nextMatch()
      expect(store.currentIndex).toBe(4)
    })

    it('prevMatch decreases currentIndex', () => {
      store.goToMatch(2)
      store.prevMatch()
      expect(store.currentIndex).toBe(1)
    })

    it('prevMatch wraps around when loop is true', () => {
      expect(store.currentIndex).toBe(0)
      store.prevMatch()
      expect(store.currentIndex).toBe(4)
    })

    it('prevMatch stays at 0 when loop is false', () => {
      store.toggleLoop()
      store.prevMatch()
      expect(store.currentIndex).toBe(0)
    })

    it('goToMatch sets currentIndex', () => {
      store.goToMatch(3)
      expect(store.currentIndex).toBe(3)
    })

    it('goToMatch ignores out of bounds', () => {
      store.goToMatch(100)
      expect(store.currentIndex).toBe(0)
    })

    it('skip advances like nextMatch', () => {
      store.skip()
      expect(store.currentIndex).toBe(1)
    })

    it('firstMatch jumps to index 0', () => {
      store.goToMatch(3)
      expect(store.currentIndex).toBe(3)
      store.firstMatch()
      expect(store.currentIndex).toBe(0)
    })

    it('firstMatch does nothing when no matches', () => {
      store.reset()
      store.firstMatch()
      expect(store.currentIndex).toBe(0)
    })

    it('lastMatch jumps to last index', () => {
      expect(store.currentIndex).toBe(0)
      store.lastMatch()
      expect(store.currentIndex).toBe(4) // 5 matches, last index is 4
    })

    it('lastMatch does nothing when no matches', () => {
      store.reset()
      store.lastMatch()
      expect(store.currentIndex).toBe(0)
    })
  })

  describe('computed getters with matches', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      await store.search(123)
    })

    it('currentMatch returns match at currentIndex', () => {
      expect(store.currentMatch?.ruleIdentifier).toBe('SV-001')
      expect(store.currentMatch?.field).toBe('fixtext')
    })

    it('hasNext returns true when more matches exist', () => {
      expect(store.hasNext).toBe(true)
    })

    it('hasPrev returns true when loop is enabled', () => {
      expect(store.hasPrev).toBe(true)
    })

    it('progress shows correct position', () => {
      expect(store.progress).toBe('1 of 5')
      store.nextMatch()
      expect(store.progress).toBe('2 of 5')
    })

    it('summary shows correct counts', () => {
      expect(store.summary).toBe('5 matches in 2 rules')
    })

    it('hasResults returns true', () => {
      expect(store.hasResults).toBe(true)
    })
  })

  describe('replace actions', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      vi.mocked(findReplaceApi.replaceInstance).mockResolvedValue({
        success: true,
        rule: { id: 1 } as any,
      })

      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)
    })

    it('replaceOne calls API with correct params', async () => {
      await store.replaceOne(123)

      expect(findReplaceApi.replaceInstance).toHaveBeenCalledWith(123, {
        search: 'sshd',
        ruleId: 1,
        field: 'fixtext',
        instanceIndex: 0,
        replacement: 'openssh',
        caseSensitive: false,
        auditComment: 'Find & Replace: "sshd" → "openssh"',
      })
    })

    it('replaceOne adds to undoStack', async () => {
      expect(store.undoStack).toHaveLength(0)
      await store.replaceOne(123)
      expect(store.undoStack).toHaveLength(1)
    })

    it('replaceOneWithCustom uses custom text', async () => {
      await store.replaceOneWithCustom(123, 'custom-daemon')

      expect(findReplaceApi.replaceInstance).toHaveBeenCalledWith(
        123,
        expect.objectContaining({
          replacement: 'custom-daemon',
        }),
      )
    })

    it('replaceAllMatches calls API correctly', async () => {
      vi.mocked(findReplaceApi.replaceAll).mockResolvedValue({
        success: true,
        rules_updated: 2,
        matches_replaced: 5,
      })

      const result = await store.replaceAllMatches(123, 'Bulk replace')

      expect(findReplaceApi.replaceAll).toHaveBeenCalledWith(123, {
        search: 'sshd',
        replacement: 'openssh',
        caseSensitive: false,
        fields: undefined,
        auditComment: 'Bulk replace',
      })

      expect(result.rulesUpdated).toBe(2)
      expect(result.matchesReplaced).toBe(5)
    })
  })

  describe('undo action', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      vi.mocked(findReplaceApi.replaceInstance).mockResolvedValue({
        success: true,
        rule: { id: 1 } as any,
      })
      vi.mocked(findReplaceApi.undo).mockResolvedValue({
        success: true,
        rule: { id: 1 } as any,
        reverted_fields: ['fixtext'],
      })

      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)
      await store.replaceOne(123)
    })

    it('undoLast calls API and pops from stack', async () => {
      expect(store.undoStack).toHaveLength(1)

      await store.undoLast(123)

      expect(findReplaceApi.undo).toHaveBeenCalledWith(123, 1)
      expect(store.undoStack).toHaveLength(0)
    })

    it('canUndo reflects undoStack state', async () => {
      expect(store.canUndo).toBe(true)
      await store.undoLast(123)
      expect(store.canUndo).toBe(false)
    })
  })

  describe('modal actions', () => {
    it('open sets isOpen to true', () => {
      store.open()
      expect(store.isOpen).toBe(true)
    })

    it('close sets isOpen to false', () => {
      store.open()
      store.close()
      expect(store.isOpen).toBe(false)
    })

    it('toggle flips isOpen', () => {
      expect(store.isOpen).toBe(false)
      store.toggle()
      expect(store.isOpen).toBe(true)
      store.toggle()
      expect(store.isOpen).toBe(false)
    })
  })

  describe('state management actions', () => {
    it('setSearchText updates searchText', () => {
      store.setSearchText('test')
      expect(store.searchText).toBe('test')
    })

    it('setReplaceText updates replaceText', () => {
      store.setReplaceText('replacement')
      expect(store.replaceText).toBe('replacement')
    })

    it('toggleCaseSensitive flips caseSensitive', () => {
      expect(store.caseSensitive).toBe(false)
      store.toggleCaseSensitive()
      expect(store.caseSensitive).toBe(true)
    })

    it('setSelectedFields updates selectedFields', () => {
      store.setSelectedFields(['title', 'fixtext'])
      expect(store.selectedFields).toEqual(['title', 'fixtext'])
    })

    it('toggleLoop flips loop', () => {
      expect(store.loop).toBe(true)
      store.toggleLoop()
      expect(store.loop).toBe(false)
    })

    it('reset clears results but keeps search params', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      await store.search(123)

      store.reset()

      expect(store.matches).toEqual([])
      expect(store.totalMatches).toBe(0)
      expect(store.searchText).toBe('sshd') // Preserved
    })

    it('resetAll clears everything', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)

      store.resetAll()

      expect(store.matches).toEqual([])
      expect(store.searchText).toBe('')
      expect(store.replaceText).toBe('')
      expect(store.undoStack).toEqual([])
    })
  })
})
