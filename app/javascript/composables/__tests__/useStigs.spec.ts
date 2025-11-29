/**
 * useStigs Composable Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useStigsStore } from '@/stores'
import { useStigs } from '../useStigs'

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
vi.mock('@/apis/stigs.api', () => ({
  getStigs: vi.fn(),
  getStig: vi.fn(),
  uploadStig: vi.fn(),
  deleteStig: vi.fn(),
}))

describe('useStigs', () => {
  let composable: ReturnType<typeof useStigs>
  let store: ReturnType<typeof useStigsStore>

  beforeEach(() => {
    store = useStigsStore()
    composable = useStigs()
  })

  describe('reactive state', () => {
    it('exposes stigs as reactive ref', () => {
      expect(composable.stigs.value).toEqual([])

      store.$patch({ stigs: [{ id: 1, title: 'Test' }] as any })
      expect(composable.stigs.value).toHaveLength(1)
    })

    it('exposes currentStig as reactive ref', () => {
      expect(composable.currentStig.value).toBeNull()

      store.$patch({ currentStig: { id: 1, title: 'Test' } as any })
      expect(composable.currentStig.value).toEqual({ id: 1, title: 'Test' })
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
    it('count returns stigs length', () => {
      expect(composable.count.value).toBe(0)

      store.$patch({ stigs: [{ id: 1 }, { id: 2 }, { id: 3 }] as any })
      expect(composable.count.value).toBe(3)
    })

    it('isEmpty returns true when no stigs', () => {
      expect(composable.isEmpty.value).toBe(true)

      store.$patch({ stigs: [{ id: 1 }] as any })
      expect(composable.isEmpty.value).toBe(false)
    })
  })

  describe('actions', () => {
    it('findById delegates to store getter', () => {
      const mockStig = { id: 42, title: 'Test STIG' }
      store.$patch({ stigs: [mockStig] as any })

      expect(composable.findById(42)).toEqual(mockStig)
      expect(composable.findById(999)).toBeUndefined()
    })

    it('reset clears store state', () => {
      store.$patch({
        stigs: [{ id: 1 }] as any,
        loading: true,
        error: 'error',
      })

      composable.reset()

      expect(composable.stigs.value).toEqual([])
      expect(composable.loading.value).toBe(false)
      expect(composable.error.value).toBeNull()
    })
  })
})
