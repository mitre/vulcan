/**
 * useFindReplace Composable Unit Tests
 */

import type { FindResponse } from '@/apis/findReplace.api'
import { beforeEach, describe, expect, it, vi } from 'vitest'
// Import mocked modules
import * as findReplaceApi from '@/apis/findReplace.api'

import { useFindReplaceStore } from '@/stores'
import { FIELD_LABELS, FIND_REPLACE_FIELDS, useFindReplace } from '../useFindReplace'

// Mock the API module
vi.mock('@/apis/findReplace.api', () => ({
  find: vi.fn(),
  replaceInstance: vi.fn(),
  replaceField: vi.fn(),
  replaceAll: vi.fn(),
  undo: vi.fn(),
}))

// Shared mock toast object (persists across calls)
const mockToast = {
  success: vi.fn(),
  error: vi.fn(),
  warning: vi.fn(),
  info: vi.fn(),
}

// Mock the toast module - returns the same shared object each time
vi.mock('../useToast', () => ({
  useAppToast: () => mockToast,
}))

// Sample mock data
const mockFindResponse: FindResponse = {
  total_matches: 3,
  total_rules: 1,
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
            { index: 50, length: 4, text: 'sshd', context: '...restart sshd...' },
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
  ],
}

describe('useFindReplace', () => {
  let composable: ReturnType<typeof useFindReplace>
  let store: ReturnType<typeof useFindReplaceStore>

  beforeEach(() => {
    vi.clearAllMocks()
    // Clear the shared mock toast
    mockToast.success.mockClear()
    mockToast.error.mockClear()
    mockToast.warning.mockClear()
    mockToast.info.mockClear()

    store = useFindReplaceStore()
    store.resetAll()
    composable = useFindReplace()
  })

  describe('constants', () => {
    it('exports FIND_REPLACE_FIELDS', () => {
      expect(FIND_REPLACE_FIELDS).toContain('title')
      expect(FIND_REPLACE_FIELDS).toContain('fixtext')
      expect(FIND_REPLACE_FIELDS).toContain('check')
      expect(FIND_REPLACE_FIELDS).toHaveLength(8)
    })

    it('exports FIELD_LABELS for all fields', () => {
      FIND_REPLACE_FIELDS.forEach((field) => {
        expect(FIELD_LABELS[field]).toBeDefined()
        expect(typeof FIELD_LABELS[field]).toBe('string')
      })
    })

    it('has human-readable labels', () => {
      expect(FIELD_LABELS.title).toBe('Title')
      expect(FIELD_LABELS.fixtext).toBe('Fix')
      expect(FIELD_LABELS.vuln_discussion).toBe('Vulnerability Discussion')
    })
  })

  describe('reactive state', () => {
    it('exposes searchText as reactive ref', () => {
      expect(composable.searchText.value).toBe('')

      store.setSearchText('test')
      expect(composable.searchText.value).toBe('test')
    })

    it('exposes replaceText as reactive ref', () => {
      expect(composable.replaceText.value).toBe('')

      store.setReplaceText('replacement')
      expect(composable.replaceText.value).toBe('replacement')
    })

    it('exposes caseSensitive as reactive ref', () => {
      expect(composable.caseSensitive.value).toBe(false)

      store.toggleCaseSensitive()
      expect(composable.caseSensitive.value).toBe(true)
    })

    it('exposes matches as reactive ref', () => {
      expect(composable.matches.value).toEqual([])
    })

    it('exposes isOpen as reactive ref', () => {
      expect(composable.isOpen.value).toBe(false)

      store.open()
      expect(composable.isOpen.value).toBe(true)
    })
  })

  describe('backwards compatibility aliases', () => {
    it('provides findText alias for searchText', () => {
      store.setSearchText('test')
      expect(composable.findText.value).toBe('test')
    })

    it('provides matchCase alias for caseSensitive', () => {
      store.toggleCaseSensitive()
      expect(composable.matchCase.value).toBe(true)
    })

    it('provides loading alias for isLoading', () => {
      expect(composable.loading.value).toBe(false)
    })
  })

  describe('computed properties', () => {
    it('currentMatch returns null when no matches', () => {
      expect(composable.currentMatch.value).toBeNull()
    })

    it('progress shows "0 of 0" when no matches', () => {
      expect(composable.progress.value).toBe('0 of 0')
    })

    it('summary shows "No matches" when empty', () => {
      expect(composable.summary.value).toBe('No matches')
    })

    it('canUndo returns false when undoStack is empty', () => {
      expect(composable.canUndo.value).toBe(false)
    })

    it('hasResults returns false when no matches', () => {
      expect(composable.hasResults.value).toBe(false)
    })
  })

  describe('navigation actions', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      await store.search(123)
    })

    it('nextMatch advances currentIndex', () => {
      expect(composable.currentIndex.value).toBe(0)
      composable.nextMatch()
      expect(composable.currentIndex.value).toBe(1)
    })

    it('prevMatch decreases currentIndex', () => {
      composable.nextMatch()
      composable.prevMatch()
      expect(composable.currentIndex.value).toBe(0)
    })

    it('goToMatch sets currentIndex', () => {
      composable.goToMatch(2)
      expect(composable.currentIndex.value).toBe(2)
    })

    it('skip advances like nextMatch', () => {
      composable.skip()
      expect(composable.currentIndex.value).toBe(1)
    })

    it('firstMatch jumps to index 0', () => {
      composable.goToMatch(2)
      expect(composable.currentIndex.value).toBe(2)
      composable.firstMatch()
      expect(composable.currentIndex.value).toBe(0)
    })

    it('lastMatch jumps to last index', () => {
      expect(composable.currentIndex.value).toBe(0)
      composable.lastMatch()
      expect(composable.currentIndex.value).toBe(2) // 3 matches in mock data
    })
  })

  describe('modal actions', () => {
    it('open sets isOpen to true', () => {
      composable.open()
      expect(composable.isOpen.value).toBe(true)
    })

    it('close sets isOpen to false', () => {
      composable.open()
      composable.close()
      expect(composable.isOpen.value).toBe(false)
    })

    it('toggle flips isOpen', () => {
      composable.toggle()
      expect(composable.isOpen.value).toBe(true)
      composable.toggle()
      expect(composable.isOpen.value).toBe(false)
    })
  })

  describe('state management actions', () => {
    it('setSearchText updates searchText', () => {
      composable.setSearchText('test')
      expect(composable.searchText.value).toBe('test')
    })

    it('setReplaceText updates replaceText', () => {
      composable.setReplaceText('replacement')
      expect(composable.replaceText.value).toBe('replacement')
    })

    it('toggleCaseSensitive flips caseSensitive', () => {
      composable.toggleCaseSensitive()
      expect(composable.caseSensitive.value).toBe(true)
    })

    it('setSelectedFields updates selectedFields', () => {
      composable.setSelectedFields(['title', 'fixtext'])
      expect(composable.selectedFields.value).toEqual(['title', 'fixtext'])
    })

    it('toggleLoop flips loop', () => {
      expect(composable.loop.value).toBe(true)
      composable.toggleLoop()
      expect(composable.loop.value).toBe(false)
    })

    it('reset clears results', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      await store.search(123)

      composable.reset()

      expect(composable.matches.value).toEqual([])
      expect(composable.searchText.value).toBe('sshd') // Preserved
    })

    it('resetAll clears everything', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)

      composable.resetAll()

      expect(composable.matches.value).toEqual([])
      expect(composable.searchText.value).toBe('')
      expect(composable.replaceText.value).toBe('')
    })
  })

  describe('executeSearch with toast', () => {
    it('shows warning for short search text', async () => {
      composable.setSearchText('a')

      await composable.executeSearch(123)

      expect(mockToast.warning).toHaveBeenCalledWith(
        'Please enter at least 2 characters to search',
      )
    })

    it('shows info toast when no matches found', async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue({
        total_matches: 0,
        total_rules: 0,
        matches: [],
      })

      composable.setSearchText('notfound')
      await composable.executeSearch(123)

      expect(mockToast.info).toHaveBeenCalledWith('No matches found')
    })

    it('shows error toast on failure', async () => {
      vi.mocked(findReplaceApi.find).mockRejectedValue(new Error('API error'))

      composable.setSearchText('sshd')

      await expect(composable.executeSearch(123)).rejects.toThrow()
      expect(mockToast.error).toHaveBeenCalledWith('Search failed')
    })
  })

  describe('executeReplaceOne with toast', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)
    })

    it('shows success toast on replace', async () => {
      vi.mocked(findReplaceApi.replaceInstance).mockResolvedValue({
        success: true,
        rule: { id: 1 } as any,
      })

      await composable.executeReplaceOne(123)

      expect(mockToast.success).toHaveBeenCalledWith('Replacement successful')
    })

    it('shows error toast on failure', async () => {
      vi.mocked(findReplaceApi.replaceInstance).mockRejectedValue(
        new Error('Replace error'),
      )

      await expect(composable.executeReplaceOne(123)).rejects.toThrow()
      expect(mockToast.error).toHaveBeenCalledWith('Replace error')
    })
  })

  describe('executeReplaceAll with toast', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)
    })

    it('shows success toast with counts', async () => {
      vi.mocked(findReplaceApi.replaceAll).mockResolvedValue({
        success: true,
        rules_updated: 5,
        matches_replaced: 20,
      })

      await composable.executeReplaceAll(123)

      expect(mockToast.success).toHaveBeenCalledWith('Replaced 20 matches in 5 rules')
    })
  })

  describe('executeUndo with toast', () => {
    beforeEach(async () => {
      vi.mocked(findReplaceApi.find).mockResolvedValue(mockFindResponse)
      vi.mocked(findReplaceApi.replaceInstance).mockResolvedValue({
        success: true,
        rule: { id: 1 } as any,
      })
      store.setSearchText('sshd')
      store.setReplaceText('openssh')
      await store.search(123)
      await store.replaceOne(123)
    })

    it('shows success toast on undo', async () => {
      vi.mocked(findReplaceApi.undo).mockResolvedValue({
        success: true,
        rule: { id: 1 } as any,
        reverted_fields: ['fixtext'],
      })

      await composable.executeUndo(123)

      expect(mockToast.success).toHaveBeenCalledWith('Undo successful')
    })

    it('shows error toast on failure', async () => {
      vi.mocked(findReplaceApi.undo).mockRejectedValue(new Error('Undo error'))

      await expect(composable.executeUndo(123)).rejects.toThrow()
      expect(mockToast.error).toHaveBeenCalledWith('Undo error')
    })
  })
})
