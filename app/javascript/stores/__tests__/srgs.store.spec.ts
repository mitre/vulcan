/**
 * SRGs Store Unit Tests
 *
 * Example store test demonstrating Pinia testing patterns.
 * Tests store initialization, getters, and actions.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useSrgsStore } from '../srgs.store'

// Mock the API module
vi.mock('@/apis/srgs.api', () => ({
  getSrgs: vi.fn(),
  getLatestSrgs: vi.fn(),
  getSrg: vi.fn(),
  uploadSrg: vi.fn(),
  deleteSrg: vi.fn(),
}))

describe('srgs Store', () => {
  let store: ReturnType<typeof useSrgsStore>

  beforeEach(() => {
    // Pinia is auto-initialized by vitest.setup.ts
    store = useSrgsStore()
  })

  describe('initial state', () => {
    it('has empty srgs array', () => {
      expect(store.srgs).toEqual([])
    })

    it('has empty latestSrgs array', () => {
      expect(store.latestSrgs).toEqual([])
    })

    it('has null currentSrg', () => {
      expect(store.currentSrg).toBeNull()
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })

    it('has error null', () => {
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    it('srgCount returns srgs length', () => {
      expect(store.srgCount).toBe(0)

      // Directly mutate state for testing
      store.$patch({
        srgs: [
          { id: 1, title: 'SRG 1' },
          { id: 2, title: 'SRG 2' },
        ] as any,
      })

      expect(store.srgCount).toBe(2)
    })

    it('getSrgById finds srg by id', () => {
      const mockSrg = { id: 42, title: 'Test SRG' }
      store.$patch({ srgs: [mockSrg] as any })

      expect(store.getSrgById(42)).toEqual(mockSrg)
      expect(store.getSrgById(999)).toBeUndefined()
    })
  })

  describe('actions', () => {
    it('setCurrentSrg updates currentSrg', () => {
      const mockSrg = { id: 1, title: 'Current SRG' } as any

      store.setCurrentSrg(mockSrg)
      expect(store.currentSrg).toEqual(mockSrg)

      store.setCurrentSrg(null)
      expect(store.currentSrg).toBeNull()
    })

    it('reset clears all state', () => {
      // Setup some state
      store.$patch({
        srgs: [{ id: 1 }] as any,
        loading: true,
        error: 'some error',
      })

      store.reset()

      expect(store.srgs).toEqual([])
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })
})
