/**
 * Store Helper Utilities
 *
 * Common patterns for Pinia stores to reduce boilerplate.
 * Provides standardized error handling and async action wrappers.
 */

/**
 * Extract error message from unknown error
 * Handles Error instances, strings, and axios-style errors
 */
export function extractErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error) {
    return error.message
  }
  if (typeof error === 'string') {
    return error
  }
  // Handle axios-style errors
  if (error && typeof error === 'object') {
    const axiosError = error as {
      response?: { data?: { error?: string, errors?: string[] } }
      message?: string
    }
    if (axiosError.response?.data?.error) {
      return axiosError.response.data.error
    }
    if (axiosError.response?.data?.errors?.[0]) {
      return axiosError.response.data.errors[0]
    }
    if (axiosError.message) {
      return axiosError.message
    }
  }
  return fallback
}

/**
 * Create standard async action wrapper for store methods
 * Handles loading state, error state, and standardized error messages
 *
 * Usage in store:
 * ```ts
 * async fetchItems() {
 *   return withStoreAction(this, 'Failed to fetch items', async () => {
 *     const response = await api.getItems()
 *     this.items = response.data
 *     return response
 *   })
 * }
 * ```
 */
export async function withStoreAction<T>(
  store: { loading: boolean, error: string | null },
  errorMessage: string,
  action: () => Promise<T>,
): Promise<T> {
  store.loading = true
  store.error = null
  try {
    return await action()
  }
  catch (error) {
    store.error = extractErrorMessage(error, errorMessage)
    throw error
  }
  finally {
    store.loading = false
  }
}

/**
 * Create a type-safe initialState reset function
 *
 * Usage:
 * ```ts
 * const initialState = { items: [], loading: false, error: null }
 * // In actions:
 * reset() {
 *   resetStoreState(this, initialState)
 * }
 * ```
 */
export function resetStoreState<T extends object>(store: T, initialState: T): void {
  Object.assign(store, { ...initialState })
}

/**
 * Update an item in a list by ID
 * Returns new array (immutable)
 */
export function updateItemInList<T extends { id: number }>(
  items: T[],
  id: number,
  updates: Partial<T>,
): T[] {
  return items.map(item =>
    item.id === id ? { ...item, ...updates } : item,
  )
}

/**
 * Remove an item from a list by ID
 * Returns new array (immutable)
 */
export function removeItemFromList<T extends { id: number }>(
  items: T[],
  id: number,
): T[] {
  return items.filter(item => item.id !== id)
}

/**
 * Find an item in a list by ID
 */
export function findItemById<T extends { id: number }>(
  items: T[],
  id: number,
): T | undefined {
  return items.find(item => item.id === id)
}

/**
 * Async action wrapper for Composition API stores
 * Works with Vue refs for loading and error state
 *
 * Usage in Composition API store:
 * ```ts
 * const loading = ref(false)
 * const error = ref<string | null>(null)
 *
 * async function fetchItems() {
 *   return withAsyncAction(loading, error, 'Failed to fetch', async () => {
 *     const response = await api.getItems()
 *     items.value = response.data
 *     return response
 *   })
 * }
 * ```
 */
export async function withAsyncAction<T>(
  loading: { value: boolean },
  error: { value: string | null },
  errorMessage: string,
  action: () => Promise<T>,
): Promise<T> {
  loading.value = true
  error.value = null
  try {
    return await action()
  }
  catch (err) {
    error.value = extractErrorMessage(err, errorMessage)
    throw err
  }
  finally {
    loading.value = false
  }
}
