/**
 * Toast Composable
 * Wrapper around Bootstrap-Vue-Next's useToast with convenience methods
 *
 * IMPORTANT: This must be called from within a component's setup() context
 * because Bootstrap-Vue-Next's useToast requires the Vue app context.
 *
 * Usage:
 *   import { useAppToast } from '@/composables/useToast'
 *
 *   const toast = useAppToast()
 *   toast.success('Operation completed!')
 *   toast.error('Something went wrong')
 */

import type { VNode } from 'vue'
import { useToast as useBvnToast } from 'bootstrap-vue-next'
import { h } from 'vue'

export interface ToastOptions {
  title?: string
  variant?: 'primary' | 'secondary' | 'success' | 'danger' | 'warning' | 'info' | 'light' | 'dark'
  autoHide?: boolean
  delay?: number // milliseconds before auto-hide
  solid?: boolean
  noCloseButton?: boolean
  pos?: 'top-start' | 'top-center' | 'top-end' | 'middle-start' | 'middle-center' | 'middle-end' | 'bottom-start' | 'bottom-center' | 'bottom-end'
}

const defaultOptions: ToastOptions = {
  autoHide: true,
  delay: 5000,
  solid: true,
  pos: 'top-end',
}

/**
 * App-specific toast composable with convenience methods
 */
export function useAppToast() {
  const bvnToast = useBvnToast()

  /**
   * Show a toast with custom options
   * Uses Bootstrap-Vue-Next's create method (show is deprecated)
   *
   * API per BVN source code (useToast/index.ts):
   * - Properties go directly on the object, NOT inside a 'props' wrapper
   * - Use 'modelValue' (not 'value') for auto-hide timing
   * - Use 'pos' for positioning (maps to 'position' internally)
   */
  function show(message: string | VNode, options: ToastOptions = {}) {
    const opts = { ...defaultOptions, ...options }

    // Use create method - properties go directly on object, no props wrapper!
    bvnToast.create({
      title: opts.title,
      variant: opts.variant,
      solid: opts.solid,
      noCloseButton: opts.noCloseButton,
      body: message,
      pos: opts.pos,
      modelValue: opts.autoHide ? opts.delay : true, // number = auto-hide after ms, true = stay visible
    })
  }

  /**
   * Show success toast
   */
  function success(message: string, title = 'Success') {
    show(message, { title, variant: 'success' })
  }

  /**
   * Show error toast
   */
  function error(message: string, title = 'Error') {
    show(message, { title, variant: 'danger', delay: 8000 }) // Errors stay longer
  }

  /**
   * Show warning toast
   */
  function warning(message: string, title = 'Warning') {
    show(message, { title, variant: 'warning' })
  }

  /**
   * Show info toast
   */
  function info(message: string, title = 'Info') {
    show(message, { title, variant: 'info' })
  }

  /**
   * Show toast from API response (Rails convention)
   * Handles both string and object toast formats from Rails controllers
   */
  function fromResponse(response: any) {
    // Extract toast data from various response formats
    const toastData = response?.data?.toast
      || response?.response?.data?.toast
      || null

    if (!toastData) {
      return false
    }

    // String format: simple success message
    if (typeof toastData === 'string') {
      success(toastData)
      return true
    }

    // Object format: { title?, variant?, message }
    if (typeof toastData === 'object' && !Array.isArray(toastData)) {
      const title = toastData.title || 'Success'
      const variant = toastData.variant || 'success'
      let message = toastData.message

      // Handle array of messages
      if (Array.isArray(message)) {
        message = h('div', message.map(m => h('p', { class: 'mb-1' }, m)))
      }

      show(message, { title, variant })
      return true
    }

    return false
  }

  /**
   * Show error from API error response
   */
  function fromError(err: any) {
    const message = err?.response?.data?.error
      || err?.response?.data?.errors?.join(', ')
      || err?.message
      || 'An unexpected error occurred'

    error(message)
  }

  /**
   * Show success toast with an Undo button (Gmail/Outlook pattern)
   * Uses BVN slots pattern with hide callback for proper interaction
   * Toast stays visible for 8 seconds or until user interacts
   */
  async function successWithUndo(message: string, onUndo: () => void | Promise<void>, title = 'Success') {
    // Use slots pattern with hide callback - the correct BVN way
    const result = await bvnToast.create(
      {
        title,
        variant: 'success',
        solid: true,
        pos: 'top-end',
        modelValue: 8000, // 8 seconds for undo actions
        noCloseButton: false,
        slots: {
          default: ({ hide }: { hide: (trigger?: string) => void }) => [
            h('div', { class: 'd-flex align-items-center justify-content-between gap-3' }, [
              h('span', message),
              h(
                'button',
                {
                  class: 'btn btn-sm btn-outline-light',
                  onClick: () => hide('undo'),
                },
                'Undo',
              ),
            ]),
          ],
        },
      },
      { resolveOnHide: true },
    )

    // Check if user clicked Undo
    if (result && typeof result === 'object' && 'trigger' in result && result.trigger === 'undo') {
      try {
        await onUndo()
      }
      catch (err) {
        error('Undo failed')
      }
    }
  }

  return {
    show,
    success,
    successWithUndo,
    error,
    warning,
    info,
    fromResponse,
    fromError,
    // Expose the raw BVN toast for advanced usage
    raw: bvnToast,
  }
}

// Re-export for convenience
export type { ToastOptions }
