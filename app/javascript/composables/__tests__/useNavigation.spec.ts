/**
 * useNavigation Composable Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useNavigationStore } from '@/stores'
import { useNavigation } from '../useNavigation'

// Mock the API module
vi.mock('@/apis/navigation.api', () => ({
  getNavigation: vi.fn(),
}))

describe('useNavigation', () => {
  let composable: ReturnType<typeof useNavigation>
  let store: ReturnType<typeof useNavigationStore>

  beforeEach(() => {
    store = useNavigationStore()
    composable = useNavigation()
  })

  describe('reactive state', () => {
    it('exposes links as reactive ref', () => {
      expect(composable.links.value).toEqual([])

      store.$patch({ links: [{ name: 'Test', link: '/test' }] as any })
      expect(composable.links.value).toHaveLength(1)
    })

    it('exposes accessRequests as reactive ref', () => {
      expect(composable.accessRequests.value).toEqual([])

      store.$patch({ accessRequests: [{ id: 1 }] as any })
      expect(composable.accessRequests.value).toHaveLength(1)
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })
  })

  describe('computed properties', () => {
    it('hasAccessRequests returns false when empty', () => {
      expect(composable.hasAccessRequests.value).toBe(false)
    })

    it('hasAccessRequests returns true when requests exist', () => {
      store.$patch({ accessRequests: [{ id: 1 }] as any })
      expect(composable.hasAccessRequests.value).toBe(true)
    })

    it('accessRequestCount returns count', () => {
      expect(composable.accessRequestCount.value).toBe(0)

      store.$patch({ accessRequests: [{ id: 1 }, { id: 2 }] as any })
      expect(composable.accessRequestCount.value).toBe(2)
    })
  })

  describe('actions', () => {
    it('removeAccessRequest delegates to store', () => {
      store.$patch({
        accessRequests: [
          { id: 1 },
          { id: 2 },
          { id: 3 },
        ] as any,
      })

      composable.removeAccessRequest(2)

      expect(composable.accessRequests.value).toHaveLength(2)
      expect(composable.accessRequests.value.map(r => r.id)).toEqual([1, 3])
    })

    it('reset clears store state', () => {
      store.$patch({
        links: [{ name: 'Test' }] as any,
        accessRequests: [{ id: 1 }] as any,
        loading: true,
      })

      composable.reset()

      expect(composable.links.value).toEqual([])
      expect(composable.accessRequests.value).toEqual([])
      expect(composable.loading.value).toBe(false)
    })
  })
})
