/**
 * Composable Helper Utilities Tests
 */

import { describe, expect, it, vi } from 'vitest'
import {
  createListMetrics,
  withToast,
  withToastBoolean,
} from '../composable-helpers'

describe('composable Helpers', () => {
  describe('withToast', () => {
    const createMockToast = () => ({
      success: vi.fn(),
      error: vi.fn(),
    })

    it('shows success toast and returns result on success', async () => {
      const toast = createMockToast()
      const messages = { success: 'Created!', error: 'Failed to create' }

      const result = await withToast(toast, messages, async () => ({ id: 1 }))

      expect(result).toEqual({ id: 1 })
      expect(toast.success).toHaveBeenCalledWith('Created!')
      expect(toast.error).not.toHaveBeenCalled()
    })

    it('shows error toast and returns null on failure', async () => {
      const toast = createMockToast()
      const messages = { success: 'Created!', error: 'Failed to create' }

      const result = await withToast(toast, messages, async () => {
        throw new Error('Network error')
      })

      expect(result).toBeNull()
      expect(toast.error).toHaveBeenCalledWith('Failed to create', 'Network error')
      expect(toast.success).not.toHaveBeenCalled()
    })

    it('extracts error message from different error types', async () => {
      const toast = createMockToast()
      const messages = { success: 'Success', error: 'Error' }

      // String error
      await withToast(toast, messages, async () => {
        // eslint-disable-next-line no-throw-literal -- Testing string error handling
        throw 'String error message'
      })

      expect(toast.error).toHaveBeenCalledWith('Error', 'String error message')
    })
  })

  describe('withToastBoolean', () => {
    const createMockToast = () => ({
      success: vi.fn(),
      error: vi.fn(),
    })

    it('shows success toast and returns true on success', async () => {
      const toast = createMockToast()
      const messages = { success: 'Deleted!', error: 'Failed to delete' }

      const result = await withToastBoolean(toast, messages, async () => {
        // Action doesn't need to return anything
      })

      expect(result).toBe(true)
      expect(toast.success).toHaveBeenCalledWith('Deleted!')
    })

    it('shows error toast and returns false on failure', async () => {
      const toast = createMockToast()
      const messages = { success: 'Deleted!', error: 'Failed to delete' }

      const result = await withToastBoolean(toast, messages, async () => {
        throw new Error('Cannot delete')
      })

      expect(result).toBe(false)
      expect(toast.error).toHaveBeenCalledWith('Failed to delete', 'Cannot delete')
    })
  })

  describe('createListMetrics', () => {
    it('calculates count correctly', () => {
      const items = { value: [1, 2, 3, 4, 5] }
      const metrics = createListMetrics(items)

      expect(metrics.count()).toBe(5)
    })

    it('calculates isEmpty correctly', () => {
      const emptyItems = { value: [] as number[] }
      const nonEmptyItems = { value: [1] }

      expect(createListMetrics(emptyItems).isEmpty()).toBe(true)
      expect(createListMetrics(nonEmptyItems).isEmpty()).toBe(false)
    })

    it('calculates hasItems correctly', () => {
      const emptyItems = { value: [] as number[] }
      const nonEmptyItems = { value: [1] }

      expect(createListMetrics(emptyItems).hasItems()).toBe(false)
      expect(createListMetrics(nonEmptyItems).hasItems()).toBe(true)
    })

    it('updates when items change', () => {
      const items = { value: [1, 2] }
      const metrics = createListMetrics(items)

      expect(metrics.count()).toBe(2)

      items.value = [1, 2, 3, 4]
      expect(metrics.count()).toBe(4)
    })
  })
})
