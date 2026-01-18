/**
 * useConfirmModal - Programmatic confirmation dialogs
 *
 * Wraps Bootstrap-Vue-Next's useModal composable to provide
 * a simple API for confirmation dialogs throughout the app.
 *
 * Replaces window.confirm() with proper Vue-based modals.
 *
 * @example
 * const { confirm, confirmDelete, confirmAction } = useConfirmModal()
 *
 * // Simple confirmation
 * if (await confirm('Are you sure?')) {
 *   // User clicked OK
 * }
 *
 * // Delete confirmation (red OK button)
 * if (await confirmDelete('Delete this item?')) {
 *   // User confirmed deletion
 * }
 *
 * // Custom confirmation
 * if (await confirmAction({
 *   title: 'Confirm Action',
 *   body: 'This will modify the record.',
 *   okTitle: 'Proceed',
 *   okVariant: 'warning'
 * })) {
 *   // User confirmed
 * }
 */

import type { ButtonVariant, ColorVariant } from 'bootstrap-vue-next'
import { useModal } from 'bootstrap-vue-next'

export interface ConfirmOptions {
  /** Modal title */
  title?: string
  /** Modal body text */
  body?: string
  /** OK button text */
  okTitle?: string
  /** Cancel button text */
  cancelTitle?: string
  /** OK button variant (color) */
  okVariant?: ButtonVariant | null
  /** Cancel button variant */
  cancelVariant?: ButtonVariant | null
  /** Modal size */
  size?: 'sm' | 'md' | 'lg' | 'xl'
  /** Center the modal vertically */
  centered?: boolean
  /** Header variant (background color) */
  headerVariant?: ColorVariant | null
}

/**
 * Composable for confirmation dialogs
 *
 * Uses Bootstrap-Vue-Next's useModal under the hood.
 * Must be used within a component wrapped by <BApp>.
 */
export function useConfirmModal() {
  const { create } = useModal()

  /**
   * Show a simple confirmation dialog
   *
   * @param message - The message to display
   * @param title - Optional title (defaults to 'Confirm')
   * @returns Promise<boolean> - true if user clicked OK, false otherwise
   */
  async function confirm(message: string, title = 'Confirm'): Promise<boolean> {
    const result = await create({
      title,
      body: message,
      okTitle: 'OK',
      cancelTitle: 'Cancel',
      centered: true,
    }).show()

    // result can be BvTriggerableEvent, boolean, or null
    if (result === null || result === false) return false
    if (result === true) return true
    // BvTriggerableEvent has ok property
    return (result as { ok?: boolean }).ok === true
  }

  /**
   * Show a delete confirmation dialog with danger styling
   *
   * @param message - The message to display
   * @param itemName - Optional item name to include in title
   * @returns Promise<boolean> - true if user confirmed deletion
   */
  async function confirmDelete(message: string, itemName?: string): Promise<boolean> {
    const title = itemName ? `Delete ${itemName}?` : 'Confirm Delete'

    const result = await create({
      title,
      body: message,
      okTitle: 'Delete',
      okVariant: 'danger',
      cancelTitle: 'Cancel',
      centered: true,
      headerVariant: 'danger',
    }).show()

    if (result === null || result === false) return false
    if (result === true) return true
    return (result as { ok?: boolean }).ok === true
  }

  /**
   * Show a custom confirmation dialog
   *
   * @param options - Full configuration options
   * @returns Promise<boolean> - true if user clicked OK
   */
  async function confirmAction(options: ConfirmOptions): Promise<boolean> {
    const result = await create({
      title: options.title ?? 'Confirm',
      body: options.body ?? 'Are you sure?',
      okTitle: options.okTitle ?? 'OK',
      cancelTitle: options.cancelTitle ?? 'Cancel',
      okVariant: options.okVariant ?? 'primary',
      cancelVariant: options.cancelVariant ?? 'secondary',
      size: options.size ?? 'md',
      centered: options.centered ?? true,
      headerVariant: options.headerVariant ?? null,
    }).show()

    if (result === null || result === false) return false
    if (result === true) return true
    return (result as { ok?: boolean }).ok === true
  }

  /**
   * Show a warning confirmation dialog with warning styling
   *
   * @param message - The message to display
   * @param title - Optional title
   * @returns Promise<boolean> - true if user confirmed
   */
  async function confirmWarning(message: string, title = 'Warning'): Promise<boolean> {
    const result = await create({
      title,
      body: message,
      okTitle: 'Proceed',
      okVariant: 'warning',
      cancelTitle: 'Cancel',
      centered: true,
      headerVariant: 'warning',
    }).show()

    if (result === null || result === false) return false
    if (result === true) return true
    return (result as { ok?: boolean }).ok === true
  }

  return {
    confirm,
    confirmDelete,
    confirmAction,
    confirmWarning,
  }
}
