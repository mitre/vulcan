/**
 * STIGs Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useStigsStore } from '../stigs.store'

// Mock the API module
vi.mock('@/apis/stigs.api', () => ({
  getStigs: vi.fn(),
  getStig: vi.fn(),
  uploadStig: vi.fn(),
  deleteStig: vi.fn(),
}))

describe('stigs Store', () => {
  let store: ReturnType<typeof useStigsStore>

  beforeEach(() => {
    store = useStigsStore()
  })

  describe('initial state', () => {
    it('has empty stigs array', () => {
      expect(store.stigs).toEqual([])
    })

    it('has null currentStig', () => {
      expect(store.currentStig).toBeNull()
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })

    it('has error null', () => {
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    it('stigCount returns stigs length', () => {
      expect(store.stigCount).toBe(0)
      store.$patch({ stigs: [{ id: 1 }, { id: 2 }] as any })
      expect(store.stigCount).toBe(2)
    })

    it('getStigById finds stig by id', () => {
      const mockStig = { id: 42, title: 'Test STIG' }
      store.$patch({ stigs: [mockStig] as any })
      expect(store.getStigById(42)).toEqual(mockStig)
      expect(store.getStigById(999)).toBeUndefined()
    })
  })

  describe('actions', () => {
    it('setCurrentStig updates currentStig', () => {
      const mockStig = { id: 1, title: 'Test' } as any
      store.setCurrentStig(mockStig)
      expect(store.currentStig).toEqual(mockStig)

      store.setCurrentStig(null)
      expect(store.currentStig).toBeNull()
    })

    it('reset clears all state', () => {
      store.$patch({
        stigs: [{ id: 1 }] as any,
        currentStig: { id: 1 } as any,
        loading: true,
        error: 'some error',
      })

      store.reset()

      expect(store.stigs).toEqual([])
      expect(store.currentStig).toBeNull()
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })
})
