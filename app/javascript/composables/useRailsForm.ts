/**
 * useRailsForm Composable
 *
 * Provides utilities for Rails-compatible form submissions.
 * Handles method override (_method) for PUT/DELETE requests.
 *
 * Usage:
 *   const { submitForm } = useRailsForm()
 *   submitForm('/users/123', 'delete')
 */
import { useCsrfToken } from './useCsrfToken'

export type RailsMethod = 'get' | 'post' | 'put' | 'patch' | 'delete'

export interface RailsFormOptions {
  /** Additional form data as key-value pairs */
  data?: Record<string, string>
}

/**
 * Create and submit a Rails-compatible form
 */
export function useRailsForm() {
  const { csrfToken } = useCsrfToken()

  /**
   * Submit a form to a Rails endpoint
   *
   * @param action - The URL to submit to
   * @param method - HTTP method (get, post, put, patch, delete)
   * @param options - Additional options including form data
   */
  function submitForm(action: string, method: RailsMethod, options?: RailsFormOptions) {
    const form = document.createElement('form')
    form.method = method === 'get' ? 'GET' : 'POST'
    form.action = action

    // Add method override for non-GET/POST methods
    if (method !== 'get' && method !== 'post') {
      const methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      methodInput.value = method
      form.appendChild(methodInput)
    }

    // Add CSRF token
    if (method !== 'get') {
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = csrfToken.value
      form.appendChild(tokenInput)
    }

    // Add additional data
    if (options?.data) {
      for (const [name, value] of Object.entries(options.data)) {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = name
        input.value = value
        form.appendChild(input)
      }
    }

    document.body.appendChild(form)
    form.submit()
  }

  /**
   * Shorthand for DELETE requests
   */
  function submitDelete(action: string) {
    submitForm(action, 'delete')
  }

  /**
   * Shorthand for PUT requests
   */
  function submitPut(action: string, data?: Record<string, string>) {
    submitForm(action, 'put', { data })
  }

  return {
    csrfToken,
    submitForm,
    submitDelete,
    submitPut,
  }
}
