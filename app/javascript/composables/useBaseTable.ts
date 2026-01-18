/**
 * useBaseTable Composable
 *
 * Provides unified table functionality including:
 * - Search filtering across configurable fields
 * - Pagination with configurable page size
 * - Optional localStorage persistence for filter state
 *
 * Usage:
 *   const { search, currentPage, paginatedItems, totalRows } = useBaseTable({
 *     items: computed(() => props.items),
 *     searchFields: ['name', 'email'],
 *     perPage: 10,
 *     persistKey: 'usersTable', // optional
 *   })
 */
import type { ComputedRef, Ref } from 'vue'
import { computed, ref, watch } from 'vue'

export interface BaseTableConfig<T> {
  /** Reactive array of items to filter/paginate */
  items: Ref<T[]> | ComputedRef<T[]>
  /** Fields to search within (uses string coercion) */
  searchFields: (keyof T)[]
  /** Items per page (default: 10) */
  perPage?: number
  /** localStorage key for persisting filter state */
  persistKey?: string
}

export interface BaseTableReturn<T> {
  /** Search term (v-model binding) */
  search: Ref<string>
  /** Current page number (1-indexed) */
  currentPage: Ref<number>
  /** Items per page */
  perPage: Ref<number>
  /** Items filtered by search term */
  filteredItems: ComputedRef<T[]>
  /** Current page of filtered items */
  paginatedItems: ComputedRef<T[]>
  /** Total number of filtered items */
  totalRows: ComputedRef<number>
  /** Total number of pages */
  totalPages: ComputedRef<number>
  /** Whether filtered results are empty */
  isEmpty: ComputedRef<boolean>
  /** Whether there are any filtered results */
  hasResults: ComputedRef<boolean>
  /** Reset to first page */
  resetPage: () => void
  /** Clear search and reset */
  clearSearch: () => void
}

export function useBaseTable<T extends Record<string, unknown>>(
  config: BaseTableConfig<T>,
): BaseTableReturn<T> {
  const search = ref('')
  const currentPage = ref(1)
  const perPage = ref(config.perPage ?? 10)

  // Filter by search term across specified fields
  const filteredItems = computed(() => {
    const term = search.value.toLowerCase().trim()
    if (!term) return config.items.value

    return config.items.value.filter(item =>
      config.searchFields.some((field) => {
        const value = item[field]
        return String(value ?? '').toLowerCase().includes(term)
      }),
    )
  })

  // Paginate filtered results
  const paginatedItems = computed(() => {
    const start = (currentPage.value - 1) * perPage.value
    return filteredItems.value.slice(start, start + perPage.value)
  })

  const totalRows = computed(() => filteredItems.value.length)
  const totalPages = computed(() => Math.ceil(totalRows.value / perPage.value))
  const isEmpty = computed(() => filteredItems.value.length === 0)
  const hasResults = computed(() => filteredItems.value.length > 0)

  // Reset to page 1 when search changes
  watch(search, () => {
    currentPage.value = 1
  })

  // Optional localStorage persistence
  if (config.persistKey) {
    const stored = localStorage.getItem(config.persistKey)
    if (stored) {
      try {
        const parsed = JSON.parse(stored)
        if (typeof parsed.search === 'string') search.value = parsed.search
        if (typeof parsed.perPage === 'number') perPage.value = parsed.perPage
      }
      catch {
        localStorage.removeItem(config.persistKey)
      }
    }

    watch([search, perPage], () => {
      localStorage.setItem(
        config.persistKey!,
        JSON.stringify({
          search: search.value,
          perPage: perPage.value,
        }),
      )
    })
  }

  function resetPage() {
    currentPage.value = 1
  }

  function clearSearch() {
    search.value = ''
    currentPage.value = 1
  }

  return {
    search,
    currentPage,
    perPage,
    filteredItems,
    paginatedItems,
    totalRows,
    totalPages,
    isEmpty,
    hasResults,
    resetPage,
    clearSearch,
  }
}
