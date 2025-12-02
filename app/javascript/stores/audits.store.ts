/**
 * Audits Store
 * Admin audit log state management
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 */

import type {
  IAudit,
  IAuditDetail,
  IAuditFilterOptions,
  IAuditFilters,
  IAuditStats,
  IPagination,
} from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { getAuditDetail, getAudits, getAuditStats } from '@/apis/audits.api'
import { withAsyncAction } from '@/utils'

const initialFilters: IAuditFilters = {
  auditable_type: '',
  action_type: '',
  user_id: '',
  from_date: '',
  to_date: '',
  search: '',
  page: 1,
  per_page: 50,
}

export const useAuditsStore = defineStore('audits.store', () => {
  // State
  const audits = ref<IAudit[]>([])
  const selectedAudit = ref<IAuditDetail | null>(null)
  const stats = ref<IAuditStats | null>(null)
  const filterOptions = ref<IAuditFilterOptions | null>(null)
  const pagination = ref<IPagination | null>(null)
  const filters = ref<IAuditFilters>({ ...initialFilters })
  const loading = ref(false)
  const statsLoading = ref(false)
  const detailLoading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const auditCount = computed(() => pagination.value?.total ?? audits.value.length)
  const currentPage = computed(() => pagination.value?.page ?? 1)
  const totalPages = computed(() => pagination.value?.total_pages ?? 1)
  const hasActiveFilters = computed(() =>
    !!filters.value.auditable_type
    || !!filters.value.action_type
    || !!filters.value.user_id
    || !!filters.value.from_date
    || !!filters.value.to_date
    || !!filters.value.search,
  )
  const getAuditById = computed(() => (id: number) => audits.value.find(a => a.id === id))
  const auditableTypes = computed(() => filterOptions.value?.auditable_types ?? [])
  const auditActions = computed(() => filterOptions.value?.actions ?? [])

  // Actions

  /**
   * Fetch audits with current filters and pagination
   * GET /admin/audits
   */
  async function fetchAudits(page: number = 1) {
    return withAsyncAction(loading, error, 'Failed to fetch audits', async () => {
      const response = await getAudits({
        ...filters.value,
        page,
      })
      audits.value = response.data.audits
      pagination.value = response.data.pagination
      filterOptions.value = response.data.filters
      return response
    })
  }

  /**
   * Fetch single audit detail
   * GET /admin/audits/:id
   */
  async function fetchAuditDetail(id: number) {
    return withAsyncAction(detailLoading, error, 'Failed to fetch audit detail', async () => {
      const response = await getAuditDetail(id)
      selectedAudit.value = response.data.audit
      return response
    })
  }

  /**
   * Fetch audit statistics
   * GET /admin/audits/stats
   */
  async function fetchStats() {
    return withAsyncAction(statsLoading, error, 'Failed to fetch audit stats', async () => {
      const response = await getAuditStats()
      stats.value = response.data
      return response
    })
  }

  /**
   * Update filters and refetch from page 1
   */
  async function setFilters(newFilters: Partial<IAuditFilters>) {
    filters.value = { ...filters.value, ...newFilters }
    await fetchAudits(1)
  }

  /**
   * Clear all filters
   */
  async function clearFilters() {
    filters.value = { ...initialFilters }
    await fetchAudits(1)
  }

  /**
   * Go to specific page
   */
  async function goToPage(page: number) {
    filters.value.page = page
    await fetchAudits(page)
  }

  /**
   * Clear selected audit detail
   */
  function clearSelectedAudit() {
    selectedAudit.value = null
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    audits.value = []
    selectedAudit.value = null
    stats.value = null
    filterOptions.value = null
    pagination.value = null
    filters.value = { ...initialFilters }
    loading.value = false
    statsLoading.value = false
    detailLoading.value = false
    error.value = null
  }

  return {
    // State
    audits,
    selectedAudit,
    stats,
    filterOptions,
    pagination,
    filters,
    loading,
    statsLoading,
    detailLoading,
    error,

    // Getters
    auditCount,
    currentPage,
    totalPages,
    hasActiveFilters,
    getAuditById,
    auditableTypes,
    auditActions,

    // Actions
    fetchAudits,
    fetchAuditDetail,
    fetchStats,
    setFilters,
    clearFilters,
    goToPage,
    clearSelectedAudit,
    reset,
  }
})
