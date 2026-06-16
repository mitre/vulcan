import { ref } from "vue";
import { patchComponent } from "../api/componentsApi";

/**
 * Dialog copy from ConfirmComponentReleaseMixin — exported once so both
 * consumers (ComponentCard, ProjectComponent) share one source of truth
 * when rendering the declarative <b-modal> in their templates.
 */
export const RELEASE_CONFIRM_COPY = Object.freeze({
  title: "Release Component",
  okTitle: "Release Component",
  okVariant: "success",
  cancelTitle: "Cancel",
  body:
    "Are you sure you want to release this component? " +
    "This cannot be undone and will make the component publicly available within Vulcan.",
});

/**
 * useConfirmRelease — component release confirmation for Vue 2.7
 *
 * Replaces ConfirmComponentReleaseMixin. Follows the useDeleteConfirmation
 * pattern: the composable owns the confirmation STATE and the release
 * OPERATION; the consumer renders a declarative <b-modal v-model="showModal">
 * (no $bvModal.msgBoxConfirm — imperative instance APIs don't exist in setup).
 *
 * Toast display and projectUpdated emit stay with the consumer — it reads
 * the returned { success, response, error } and reacts.
 *
 * Usage:
 *   setup() {
 *     const { showModal, isReleasing, requestRelease, cancel, confirm } = useConfirmRelease();
 *     async function onConfirmRelease() {
 *       const { success, response, error } = await confirm();
 *       if (success) { alertOrNotifyResponse(response); emit("projectUpdated"); }
 *       else if (error) { alertOrNotifyResponse(error); }
 *     }
 *     return { showModal, isReleasing, requestRelease, cancel, onConfirmRelease,
 *              releaseModal: RELEASE_CONFIRM_COPY };
 *   }
 *
 * @returns {Object} Reactive state and methods
 */
export function useConfirmRelease() {
  const showModal = ref(false);
  const isReleasing = ref(false);
  const componentToRelease = ref(null);

  /**
   * Open the release confirmation dialog.
   * Mixin guard parity: non-releasable components never open the dialog.
   *
   * @param {Object} component - The component to release (needs id + releasable)
   * @returns {boolean} true if the dialog opened
   */
  function requestRelease(component) {
    if (!component || !component.releasable) {
      return false;
    }
    componentToRelease.value = component;
    showModal.value = true;
    return true;
  }

  /**
   * Cancel the release and reset state.
   */
  function cancel() {
    showModal.value = false;
    componentToRelease.value = null;
    isReleasing.value = false;
  }

  /**
   * Confirm and execute the release: PATCH { released: true }.
   * Release cannot be undone — on error the dialog stays open with the
   * component retained so the user can retry; on success everything resets.
   *
   * @returns {Promise<{success: boolean, response: Object|null, error: Error|null}>}
   */
  async function confirm() {
    if (!componentToRelease.value || isReleasing.value) {
      return { success: false, response: null, error: null };
    }

    isReleasing.value = true;

    try {
      const response = await patchComponent(componentToRelease.value.id, { released: true });

      showModal.value = false;
      componentToRelease.value = null;
      isReleasing.value = false;

      return { success: true, response, error: null };
    } catch (error) {
      // Keep the dialog open for retry — only the in-flight flag resets.
      isReleasing.value = false;
      return { success: false, response: null, error };
    }
  }

  return {
    // State
    showModal,
    isReleasing,
    componentToRelease,
    // Methods
    requestRelease,
    cancel,
    confirm,
  };
}
