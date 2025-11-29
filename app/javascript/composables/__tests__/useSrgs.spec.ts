/**
 * useSrgs Composable Unit Tests
 *
 * Example composable test demonstrating testing patterns for
 * composables that wrap Pinia stores.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useSrgsStore } from '@/stores'
import { useSrgs } from '../useSrgs'

// Mock the toast composable
vi.mock('../useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

// Mock the API module
vi.mock('@/apis/srgs.api', () => ({
  getSrgs: vi.fn(),
  getLatestSrgs: vi.fn(),
  getSrg: vi.fn(),
  uploadSrg: vi.fn(),
  deleteSrg: vi.fn(),
}))

describe('useSrgs', () => {
  let composable: ReturnType<typeof useSrgs>
  let store: ReturnType<typeof useSrgsStore>

  beforeEach(() => {
    // Get fresh store (Pinia auto-initialized by vitest.setup.ts)
    store = useSrgsStore()
    // Get composable instance
    composable = useSrgs()
  })

  describe('reactive state', () => {
    it('exposes srgs as reactive ref', () => {
      expect(composable.srgs.value).toEqual([])

      // Mutate store, composable should reflect change
      store.$patch({ srgs: [{ id: 1, title: 'Test' }] as any })
      expect(composable.srgs.value).toHaveLength(1)
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })

    it('exposes error as reactive ref', () => {
      expect(composable.error.value).toBeNull()

      store.$patch({ error: 'Test error' })
      expect(composable.error.value).toBe('Test error')
    })
  })

  describe('computed properties', () => {
    it('count returns srgs length', () => {
      expect(composable.count.value).toBe(0)

      store.$patch({
        srgs: [
          { id: 1 },
          { id: 2 },
          { id: 3 },
        ] as any,
      })

      expect(composable.count.value).toBe(3)
    })

    it('isEmpty returns true when no srgs', () => {
      expect(composable.isEmpty.value).toBe(true)

      store.$patch({ srgs: [{ id: 1 }] as any })
      expect(composable.isEmpty.value).toBe(false)
    })
  })

  describe('actions', () => {
    it('findById delegates to store getter', () => {
      const mockSrg = { id: 42, title: 'Test SRG' }
      store.$patch({ srgs: [mockSrg] as any })

      expect(composable.findById(42)).toEqual(mockSrg)
      expect(composable.findById(999)).toBeUndefined()
    })

    it('reset clears store state', () => {
      store.$patch({
        srgs: [{ id: 1 }] as any,
        loading: true,
        error: 'error',
      })

      composable.reset()

      expect(composable.srgs.value).toEqual([])
      expect(composable.loading.value).toBe(false)
      expect(composable.error.value).toBeNull()
    })
  })
})
