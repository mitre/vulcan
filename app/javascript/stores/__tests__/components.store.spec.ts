/**
 * Components Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useComponentsStore } from '../components.store'

// Mock the API module
vi.mock('@/apis/components.api', () => ({
  getComponent: vi.fn(),
  createComponent: vi.fn(),
  updateComponent: vi.fn(),
  deleteComponent: vi.fn(),
  duplicateComponent: vi.fn(),
}))

describe('components Store', () => {
  let store: ReturnType<typeof useComponentsStore>

  beforeEach(() => {
    store = useComponentsStore()
  })

  describe('initial state', () => {
    it('has empty components array', () => {
      expect(store.components).toEqual([])
    })

    it('has null currentComponent', () => {
      expect(store.currentComponent).toBeNull()
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })

    it('has error null', () => {
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    it('componentCount returns components length', () => {
      expect(store.componentCount).toBe(0)
      store.$patch({ components: [{ id: 1 }, { id: 2 }] as any })
      expect(store.componentCount).toBe(2)
    })

    it('getComponentById finds component by id', () => {
      const mockComponent = { id: 42, name: 'Test Component' }
      store.$patch({ components: [mockComponent] as any })
      expect(store.getComponentById(42)).toEqual(mockComponent)
      expect(store.getComponentById(999)).toBeUndefined()
    })

    it('releasedComponents filters by released', () => {
      store.$patch({
        components: [
          { id: 1, released: true },
          { id: 2, released: false },
          { id: 3, released: true },
        ] as any,
      })
      expect(store.releasedComponents).toHaveLength(2)
      expect(store.releasedComponents.map(c => c.id)).toEqual([1, 3])
    })
  })

  describe('actions', () => {
    it('setComponents updates components array', () => {
      const mockComponents = [{ id: 1 }, { id: 2 }] as any
      store.setComponents(mockComponents)
      expect(store.components).toEqual(mockComponents)
    })

    it('setCurrentComponent updates currentComponent', () => {
      const mockComponent = { id: 1, name: 'Test' } as any
      store.setCurrentComponent(mockComponent)
      expect(store.currentComponent).toEqual(mockComponent)

      store.setCurrentComponent(null)
      expect(store.currentComponent).toBeNull()
    })

    it('reset clears all state', () => {
      store.$patch({
        components: [{ id: 1 }] as any,
        currentComponent: { id: 1 } as any,
        loading: true,
        error: 'some error',
      })

      store.reset()

      expect(store.components).toEqual([])
      expect(store.currentComponent).toBeNull()
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })
})
