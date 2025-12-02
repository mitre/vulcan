/**
 * Store Helper Utilities Tests
 */

import { describe, expect, it } from 'vitest'
import { ref } from 'vue'
import {
  extractErrorMessage,
  findItemById,
  removeItemFromList,
  resetStoreState,
  updateItemInList,
  withAsyncAction,
  withStoreAction,
} from '../store-helpers'

describe('store Helpers', () => {
  describe('extractErrorMessage', () => {
    it('extracts message from Error instance', () => {
      const error = new Error('Test error message')
      expect(extractErrorMessage(error, 'fallback')).toBe('Test error message')
    })

    it('returns string error as-is', () => {
      expect(extractErrorMessage('String error', 'fallback')).toBe('String error')
    })

    it('extracts from axios-style error response', () => {
      const axiosError = {
        response: {
          data: { error: 'API error message' },
        },
      }
      expect(extractErrorMessage(axiosError, 'fallback')).toBe('API error message')
    })

    it('extracts first error from errors array', () => {
      const axiosError = {
        response: {
          data: { errors: ['First error', 'Second error'] },
        },
      }
      expect(extractErrorMessage(axiosError, 'fallback')).toBe('First error')
    })

    it('falls back to message property', () => {
      const error = { message: 'Object message' }
      expect(extractErrorMessage(error, 'fallback')).toBe('Object message')
    })

    it('returns fallback for unknown error types', () => {
      expect(extractErrorMessage(null, 'fallback')).toBe('fallback')
      expect(extractErrorMessage(undefined, 'fallback')).toBe('fallback')
      expect(extractErrorMessage(123, 'fallback')).toBe('fallback')
      expect(extractErrorMessage({}, 'fallback')).toBe('fallback')
    })
  })

  describe('withStoreAction', () => {
    it('sets loading to true during action', async () => {
      const store = { loading: false, error: null }
      let loadingDuringAction = false

      await withStoreAction(store, 'error', async () => {
        loadingDuringAction = store.loading
        return 'result'
      })

      expect(loadingDuringAction).toBe(true)
      expect(store.loading).toBe(false) // Reset after
    })

    it('clears error before action', async () => {
      const store = { loading: false, error: 'previous error' }

      await withStoreAction(store, 'error', async () => 'result')

      expect(store.error).toBeNull()
    })

    it('returns action result on success', async () => {
      const store = { loading: false, error: null }

      const result = await withStoreAction(store, 'error', async () => 'success result')

      expect(result).toBe('success result')
    })

    it('sets error and rethrows on failure', async () => {
      const store = { loading: false, error: null }

      await expect(
        withStoreAction(store, 'Failed to do action', async () => {
          throw new Error('Action failed')
        }),
      ).rejects.toThrow('Action failed')

      expect(store.error).toBe('Action failed')
      expect(store.loading).toBe(false)
    })

    it('uses fallback message for non-Error throws', async () => {
      const store = { loading: false, error: null }

      await expect(
        withStoreAction(store, 'Fallback message', async () => {
          // eslint-disable-next-line no-throw-literal -- Testing string error handling
          throw 'string error'
        }),
      ).rejects.toBe('string error')

      expect(store.error).toBe('string error')
    })
  })

  describe('resetStoreState', () => {
    it('resets store to initial state', () => {
      const initialState = { items: [], loading: false, error: null }
      const store = { items: [1, 2, 3], loading: true, error: 'some error' }

      resetStoreState(store, initialState)

      expect(store.items).toEqual([])
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })

  describe('updateItemInList', () => {
    const items = [
      { id: 1, name: 'Item 1' },
      { id: 2, name: 'Item 2' },
      { id: 3, name: 'Item 3' },
    ]

    it('updates matching item', () => {
      const result = updateItemInList(items, 2, { name: 'Updated Item 2' })

      expect(result[1]).toEqual({ id: 2, name: 'Updated Item 2' })
      expect(result[0]).toEqual(items[0]) // Others unchanged
      expect(result[2]).toEqual(items[2])
    })

    it('returns new array (immutable)', () => {
      const result = updateItemInList(items, 2, { name: 'Updated' })

      expect(result).not.toBe(items)
    })

    it('leaves list unchanged if ID not found', () => {
      const result = updateItemInList(items, 99, { name: 'Updated' })

      expect(result).toEqual(items)
    })
  })

  describe('removeItemFromList', () => {
    const items = [
      { id: 1, name: 'Item 1' },
      { id: 2, name: 'Item 2' },
      { id: 3, name: 'Item 3' },
    ]

    it('removes matching item', () => {
      const result = removeItemFromList(items, 2)

      expect(result).toHaveLength(2)
      expect(result.find(i => i.id === 2)).toBeUndefined()
    })

    it('returns new array (immutable)', () => {
      const result = removeItemFromList(items, 2)

      expect(result).not.toBe(items)
    })

    it('leaves list unchanged if ID not found', () => {
      const result = removeItemFromList(items, 99)

      expect(result).toHaveLength(3)
    })
  })

  describe('findItemById', () => {
    const items = [
      { id: 1, name: 'Item 1' },
      { id: 2, name: 'Item 2' },
    ]

    it('finds item by ID', () => {
      const result = findItemById(items, 2)

      expect(result).toEqual({ id: 2, name: 'Item 2' })
    })

    it('returns undefined if not found', () => {
      const result = findItemById(items, 99)

      expect(result).toBeUndefined()
    })
  })

  describe('withAsyncAction (Composition API)', () => {
    it('sets loading ref to true during action', async () => {
      const loading = ref(false)
      const error = ref<string | null>(null)
      let loadingDuringAction = false

      await withAsyncAction(loading, error, 'error', async () => {
        loadingDuringAction = loading.value
        return 'result'
      })

      expect(loadingDuringAction).toBe(true)
      expect(loading.value).toBe(false) // Reset after
    })

    it('clears error ref before action', async () => {
      const loading = ref(false)
      const error = ref<string | null>('previous error')

      await withAsyncAction(loading, error, 'error', async () => 'result')

      expect(error.value).toBeNull()
    })

    it('returns action result on success', async () => {
      const loading = ref(false)
      const error = ref<string | null>(null)

      const result = await withAsyncAction(loading, error, 'error', async () => 'success result')

      expect(result).toBe('success result')
    })

    it('sets error ref and rethrows on failure', async () => {
      const loading = ref(false)
      const error = ref<string | null>(null)

      await expect(
        withAsyncAction(loading, error, 'Failed to do action', async () => {
          throw new Error('Action failed')
        }),
      ).rejects.toThrow('Action failed')

      expect(error.value).toBe('Action failed')
      expect(loading.value).toBe(false)
    })

    it('uses fallback message for non-Error throws', async () => {
      const loading = ref(false)
      const error = ref<string | null>(null)

      await expect(
        withAsyncAction(loading, error, 'Fallback message', async () => {
          // eslint-disable-next-line no-throw-literal -- Testing string error handling
          throw 'string error'
        }),
      ).rejects.toBe('string error')

      expect(error.value).toBe('string error')
    })
  })
})
