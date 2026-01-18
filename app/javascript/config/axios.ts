import axios from 'axios'

/**
 * Configure axios to include Rails CSRF token in all requests
 */
function getCsrfToken(): string {
  const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  if (!token) {
    console.warn('CSRF token not found in meta tag')
    return ''
  }
  return token
}

// Set CSRF token for all axios requests
axios.defaults.headers.common['X-CSRF-Token'] = getCsrfToken()

// Set Accept header to request JSON responses from Rails
axios.defaults.headers.common.Accept = 'application/json'

// Update CSRF token after DOM changes (in case meta tag is updated)
export function refreshCsrfToken() {
  axios.defaults.headers.common['X-CSRF-Token'] = getCsrfToken()
}

export default axios
