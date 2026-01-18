/**
 * useDeleteConfirmation Composable
 *
 * Provides reusable delete confirmation state and logic.
 * Works with DeleteModal component for consistent UX.
 *
 * Usage:
 *   const {
 *     showModal,
 *     itemToDelete,
 *     isDeleting,
 *     confirmDelete,
 *     executeDelete,
 *     cancelDelete,
 *   } = useDeleteConfirmation<IUser>({
 *     onDelete: async (user) => await api.deleteUser(user.id),
 *     onSuccess: () => emit('deleted'),
 *   })
 */
import { ref } from 'vue'

export interface DeleteConfirmationConfig<T> {
  /** Callback to execute the actual delete operation */
  onDelete: (item: T) => Promise<void> | void
  /** Callback after successful delete */
  onSuccess?: () => void
  /** Callback after failed delete */
  onError?: (error: unknown) => void
}

export interface DeleteConfirmationReturn<T> {
  /** Whether the confirmation modal is shown */
  showModal: ReturnType<typeof ref<boolean>>
  /** The item pending deletion */
  itemToDelete: ReturnType<typeof ref<T | null>>
  /** Whether delete is in progress */
  isDeleting: ReturnType<typeof ref<boolean>>
  /** Request deletion confirmation for an item */
  confirmDelete: (item: T) => void
  /** Execute the delete operation */
  executeDelete: () => Promise<void>
  /** Cancel the delete operation */
  cancelDelete: () => void
}

export function useDeleteConfirmation<T>(
  config: DeleteConfirmationConfig<T>,
): DeleteConfirmationReturn<T> {
  const showModal = ref(false)
  const itemToDelete = ref<T | null>(null) as ReturnType<typeof ref<T | null>>
  const isDeleting = ref(false)

  /**
   * Show confirmation modal for an item
   */
  function confirmDelete(item: T) {
    itemToDelete.value = item
    showModal.value = true
  }

  /**
   * Execute the delete after confirmation
   */
  async function executeDelete() {
    if (!itemToDelete.value) return

    isDeleting.value = true
    try {
      await config.onDelete(itemToDelete.value)
      showModal.value = false
      itemToDelete.value = null
      config.onSuccess?.()
    }
    catch (error) {
      console.error('Delete failed:', error)
      config.onError?.(error)
    }
    finally {
      isDeleting.value = false
    }
  }

  /**
   * Cancel the delete operation
   */
  function cancelDelete() {
    showModal.value = false
    itemToDelete.value = null
    isDeleting.value = false
  }

  return {
    showModal,
    itemToDelete,
    isDeleting,
    confirmDelete,
    executeDelete,
    cancelDelete,
  }
}
