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
  pos?: 'top-left' | 'top-center' | 'top-right' | 'middle-left' | 'middle-center' | 'middle-right' | 'bottom-left' | 'bottom-center' | 'bottom-right'
}

const defaultOptions: ToastOptions = {
  autoHide: true,
  delay: 5000,
  solid: true,
  pos: 'top-right',
}

/**
 * App-specific toast composable with convenience methods
 */
export function useAppToast() {
  const bvnToast = useBvnToast()

  /**
   * Show a toast with custom options
   */
  function show(message: string | VNode, options: ToastOptions = {}) {
    const opts = { ...defaultOptions, ...options }

    bvnToast.show?.({
      props: {
        title: opts.title,
        variant: opts.variant,
        solid: opts.solid,
        noCloseButton: opts.noCloseButton,
        body: message,
        pos: opts.pos,
        value: opts.autoHide ? opts.delay : true, // number = auto-hide after ms, true = stay visible
      },
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

  return {
    show,
    success,
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
