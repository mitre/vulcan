/**
 * Navigation Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useNavigationStore } from '../navigation.store'

// Mock the API module
vi.mock('@/apis/navigation.api', () => ({
  getNavigation: vi.fn(),
}))

describe('navigation Store', () => {
  let store: ReturnType<typeof useNavigationStore>

  beforeEach(() => {
    store = useNavigationStore()
  })

  describe('initial state', () => {
    it('has empty links array', () => {
      expect(store.links).toEqual([])
    })

    it('has empty accessRequests array', () => {
      expect(store.accessRequests).toEqual([])
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })
  })

  describe('getters', () => {
    it('hasAccessRequests returns false when empty', () => {
      expect(store.hasAccessRequests).toBe(false)
    })

    it('hasAccessRequests returns true when requests exist', () => {
      store.$patch({ accessRequests: [{ id: 1 }] as any })
      expect(store.hasAccessRequests).toBe(true)
    })

    it('accessRequestCount returns count', () => {
      expect(store.accessRequestCount).toBe(0)
      store.$patch({ accessRequests: [{ id: 1 }, { id: 2 }] as any })
      expect(store.accessRequestCount).toBe(2)
    })
  })

  describe('actions', () => {
    it('removeAccessRequest removes request by id', () => {
      store.$patch({
        accessRequests: [
          { id: 1, name: 'Request 1' },
          { id: 2, name: 'Request 2' },
          { id: 3, name: 'Request 3' },
        ] as any,
      })

      store.removeAccessRequest(2)

      expect(store.accessRequests).toHaveLength(2)
      expect(store.accessRequests.map(r => r.id)).toEqual([1, 3])
    })

    it('reset clears all state', () => {
      store.$patch({
        links: [{ name: 'Test' }] as any,
        accessRequests: [{ id: 1 }] as any,
        loading: true,
      })

      store.reset()

      expect(store.links).toEqual([])
      expect(store.accessRequests).toEqual([])
      expect(store.loading).toBe(false)
    })
  })
})
