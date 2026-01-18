/**
 * Composable Helper Utilities
 *
 * Common patterns for Vue composables to reduce boilerplate.
 * Provides standardized toast notification wrappers.
 */

import { extractErrorMessage } from './store-helpers'

/**
 * Toast message configuration
 */
export interface IToastMessages {
  success: string
  error: string
}

/**
 * Wrap an async operation with toast notifications
 *
 * Usage:
 * ```ts
 * const toast = useAppToast()
 *
 * async function create(data) {
 *   return withToast(
 *     toast,
 *     { success: 'Created successfully', error: 'Failed to create' },
 *     () => store.create(data)
 *   )
 * }
 * ```
 */
export async function withToast<T>(
  toast: { success: (msg: string) => void, error: (title: string, msg?: string) => void },
  messages: IToastMessages,
  action: () => Promise<T>,
): Promise<T | null> {
  try {
    const result = await action()
    toast.success(messages.success)
    return result
  }
  catch (error) {
    const errorMsg = extractErrorMessage(error, messages.error)
    toast.error(messages.error, errorMsg)
    return null
  }
}

/**
 * Wrap an async operation with toast notifications, returning boolean success
 *
 * Usage:
 * ```ts
 * async function remove(id: number): Promise<boolean> {
 *   return withToastBoolean(
 *     toast,
 *     { success: 'Deleted successfully', error: 'Failed to delete' },
 *     () => store.delete(id)
 *   )
 * }
 * ```
 */
export async function withToastBoolean(
  toast: { success: (msg: string) => void, error: (title: string, msg?: string) => void },
  messages: IToastMessages,
  action: () => Promise<unknown>,
): Promise<boolean> {
  try {
    await action()
    toast.success(messages.success)
    return true
  }
  catch (error) {
    const errorMsg = extractErrorMessage(error, messages.error)
    toast.error(messages.error, errorMsg)
    return false
  }
}

/**
 * Create standard list computed properties
 *
 * Usage:
 * ```ts
 * const { count, isEmpty } = useListMetrics(items)
 * ```
 */
export function createListMetrics<T>(items: { value: T[] }) {
  return {
    count: () => items.value.length,
    isEmpty: () => items.value.length === 0,
    hasItems: () => items.value.length > 0,
  }
}
