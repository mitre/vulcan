import axios from 'axios'

export const http = axios.create({
  baseURL: '/',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
  },
})

// Add CSRF token to every request
http.interceptors.request.use((config) => {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  if (csrfToken) {
    config.headers['X-CSRF-Token'] = csrfToken
  }
  return config
})

// Handle error responses - extract error message from various formats
http.interceptors.response.use(
  response => response,
  (error) => {
    // If response has data with error message, ensure it's accessible
    if (error.response?.data) {
      const data = error.response.data
      // Normalize error format - Rails can return errors in different formats
      if (data.errors && Array.isArray(data.errors)) {
        error.response.data.error = data.errors.join(', ')
      }
      else if (data.error && typeof data.error === 'object') {
        error.response.data.error = Object.values(data.error).flat().join(', ')
      }
    }
    return Promise.reject(error)
  },
)

export function setHTTPHeader(headers: Record<string, string>) {
  Object.assign(http.defaults.headers.common, headers)
}
