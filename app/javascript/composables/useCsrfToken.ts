/**
 * useCsrfToken Composable
 *
 * Provides CSRF token for Rails form submissions.
 * Extracts the token from the meta tag set by Rails.
 *
 * Usage:
 *   const { csrfToken } = useCsrfToken()
 *   // csrfToken.value contains the token string
 */
import { computed } from 'vue'

/**
 * Get the CSRF token from the Rails meta tag
 */
export function useCsrfToken() {
  const csrfToken = computed(() =>
    document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') ?? '',
  )

  return {
    csrfToken,
  }
}
