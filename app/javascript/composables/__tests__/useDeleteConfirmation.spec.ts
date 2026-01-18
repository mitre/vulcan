/**
 * Tests for useDeleteConfirmation composable
 */
import { describe, expect, it, vi } from 'vitest'
import { useDeleteConfirmation } from '@/composables/useDeleteConfirmation'

interface TestItem {
  id: number
  name: string
}

describe('useDeleteConfirmation', () => {
  const testItem: TestItem = { id: 1, name: 'Test Item' }

  describe('initial state', () => {
    it('starts with modal hidden', () => {
      const { showModal } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })
      expect(showModal.value).toBe(false)
    })

    it('starts with no item to delete', () => {
      const { itemToDelete } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })
      expect(itemToDelete.value).toBeNull()
    })

    it('starts with isDeleting false', () => {
      const { isDeleting } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })
      expect(isDeleting.value).toBe(false)
    })
  })

  describe('confirmDelete', () => {
    it('sets itemToDelete to the provided item', () => {
      const { confirmDelete, itemToDelete } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)

      expect(itemToDelete.value).toEqual(testItem)
    })

    it('shows the modal', () => {
      const { confirmDelete, showModal } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)

      expect(showModal.value).toBe(true)
    })
  })

  describe('executeDelete', () => {
    it('calls onDelete with the item', async () => {
      const onDelete = vi.fn()
      const { confirmDelete, executeDelete } = useDeleteConfirmation<TestItem>({
        onDelete,
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(onDelete).toHaveBeenCalledWith(testItem)
    })

    it('sets isDeleting to true during deletion', async () => {
      let deletingDuringCall = false
      const { confirmDelete, executeDelete, isDeleting } = useDeleteConfirmation<TestItem>({
        onDelete: () => {
          deletingDuringCall = isDeleting.value
        },
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(deletingDuringCall).toBe(true)
    })

    it('sets isDeleting to false after completion', async () => {
      const { confirmDelete, executeDelete, isDeleting } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(isDeleting.value).toBe(false)
    })

    it('hides modal after successful deletion', async () => {
      const { confirmDelete, executeDelete, showModal } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(showModal.value).toBe(false)
    })

    it('clears itemToDelete after successful deletion', async () => {
      const { confirmDelete, executeDelete, itemToDelete } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(itemToDelete.value).toBeNull()
    })

    it('calls onSuccess callback after successful deletion', async () => {
      const onSuccess = vi.fn()
      const { confirmDelete, executeDelete } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
        onSuccess,
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(onSuccess).toHaveBeenCalled()
    })

    it('does nothing if no item is set', async () => {
      const onDelete = vi.fn()
      const { executeDelete } = useDeleteConfirmation<TestItem>({
        onDelete,
      })

      await executeDelete()

      expect(onDelete).not.toHaveBeenCalled()
    })

    it('handles async onDelete functions', async () => {
      const onDelete = vi.fn().mockResolvedValue(undefined)
      const { confirmDelete, executeDelete } = useDeleteConfirmation<TestItem>({
        onDelete,
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(onDelete).toHaveBeenCalledWith(testItem)
    })

    it('calls onError callback when deletion fails', async () => {
      const error = new Error('Delete failed')
      const onError = vi.fn()
      const { confirmDelete, executeDelete } = useDeleteConfirmation<TestItem>({
        onDelete: () => {
          throw error
        },
        onError,
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(onError).toHaveBeenCalledWith(error)
    })

    it('sets isDeleting to false after error', async () => {
      const { confirmDelete, executeDelete, isDeleting } = useDeleteConfirmation<TestItem>({
        onDelete: () => {
          throw new Error('Delete failed')
        },
      })

      confirmDelete(testItem)
      await executeDelete()

      expect(isDeleting.value).toBe(false)
    })
  })

  describe('cancelDelete', () => {
    it('hides the modal', () => {
      const { confirmDelete, cancelDelete, showModal } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)
      cancelDelete()

      expect(showModal.value).toBe(false)
    })

    it('clears itemToDelete', () => {
      const { confirmDelete, cancelDelete, itemToDelete } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      confirmDelete(testItem)
      cancelDelete()

      expect(itemToDelete.value).toBeNull()
    })

    it('resets isDeleting', () => {
      const { cancelDelete, isDeleting } = useDeleteConfirmation<TestItem>({
        onDelete: vi.fn(),
      })

      cancelDelete()

      expect(isDeleting.value).toBe(false)
    })
  })
})
