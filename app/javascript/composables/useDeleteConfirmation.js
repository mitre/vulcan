import { ref } from "vue";

/**
 * useDeleteConfirmation - Reusable delete confirmation state management
 *
 * Provides state and methods for delete confirmation modals across the app.
 * Works with any item type (projects, components, users, STIGs, SRGs, etc.)
 *
 * Usage:
 *   import { useDeleteConfirmation } from "@/composables/useDeleteConfirmation";
 *
 *   setup() {
 *     const {
 *       showModal,
 *       itemToDelete,
 *       isDeleting,
 *       openModal,
 *       cancel,
 *       confirm
 *     } = useDeleteConfirmation();
 *
 *     const handleDelete = async () => {
 *       const { success, error } = await confirm(async (item) => {
 *         await axios.delete(`/api/items/${item.id}`);
 *       });
 *       if (success) {
 *         // Refresh list, show toast, etc.
 *       }
 *     };
 *
 *     return { showModal, itemToDelete, isDeleting, openModal, cancel, handleDelete };
 *   }
 *
 * Template:
 *   <ConfirmDeleteModal
 *     v-model="showModal"
 *     :item-name="itemToDelete?.name"
 *     :is-deleting="isDeleting"
 *     @confirm="handleDelete"
 *     @cancel="cancel"
 *   />
 *
 * @returns {Object} Reactive state and methods
 */
export function useDeleteConfirmation() {
  // State
  const showModal = ref(false);
  const itemToDelete = ref(null);
  const isDeleting = ref(false);

  /**
   * Open the delete confirmation modal for an item
   * @param {Object} item - The item to be deleted
   */
  function openModal(item) {
    itemToDelete.value = item;
    showModal.value = true;
  }

  /**
   * Cancel the delete operation and reset state
   */
  function cancel() {
    showModal.value = false;
    itemToDelete.value = null;
    isDeleting.value = false;
  }

  /**
   * Confirm and execute the delete operation
   * @param {Function} deleteFn - Async function that performs the delete, receives itemToDelete
   * @returns {Promise<{success: boolean, error: Error|null}>}
   */
  async function confirm(deleteFn) {
    // Guard: no item to delete
    if (!itemToDelete.value) {
      return { success: false, error: null };
    }

    // Guard: already deleting
    if (isDeleting.value) {
      return { success: false, error: null };
    }

    isDeleting.value = true;

    try {
      await deleteFn(itemToDelete.value);

      // Success: reset state
      showModal.value = false;
      itemToDelete.value = null;
      isDeleting.value = false;

      return { success: true, error: null };
    } catch (error) {
      // Error: keep modal open for retry
      isDeleting.value = false;
      return { success: false, error };
    }
  }

  return {
    // State
    showModal,
    itemToDelete,
    isDeleting,
    // Methods
    openModal,
    cancel,
    confirm,
  };
}
