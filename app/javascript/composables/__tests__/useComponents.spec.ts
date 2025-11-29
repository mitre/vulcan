/**
 * useComponents Composable Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useComponentsStore } from '@/stores'
import { useComponents } from '../useComponents'

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
vi.mock('@/apis/components.api', () => ({
  getComponent: vi.fn(),
  createComponent: vi.fn(),
  updateComponent: vi.fn(),
  deleteComponent: vi.fn(),
  duplicateComponent: vi.fn(),
}))

describe('useComponents', () => {
  let composable: ReturnType<typeof useComponents>
  let store: ReturnType<typeof useComponentsStore>

  beforeEach(() => {
    store = useComponentsStore()
    composable = useComponents()
  })

  describe('reactive state', () => {
    it('exposes components as reactive ref', () => {
      expect(composable.components.value).toEqual([])

      store.$patch({ components: [{ id: 1, name: 'Test' }] as any })
      expect(composable.components.value).toHaveLength(1)
    })

    it('exposes currentComponent as reactive ref', () => {
      expect(composable.currentComponent.value).toBeNull()

      store.$patch({ currentComponent: { id: 1, name: 'Test' } as any })
      expect(composable.currentComponent.value).toEqual({ id: 1, name: 'Test' })
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
    it('count returns components length', () => {
      expect(composable.count.value).toBe(0)

      store.$patch({ components: [{ id: 1 }, { id: 2 }, { id: 3 }] as any })
      expect(composable.count.value).toBe(3)
    })

    it('released filters by released status', () => {
      store.$patch({
        components: [
          { id: 1, released: true },
          { id: 2, released: false },
          { id: 3, released: true },
        ] as any,
      })
      expect(composable.released.value).toHaveLength(2)
    })
  })
})
