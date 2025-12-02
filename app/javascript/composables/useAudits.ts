/**
 * Audits Composable
 * Admin audit log operations with toast notifications
 *
 * Architecture: API → Store → Composable → Page
 * Pages use this composable, never the store directly.
 */

import type { IAuditFilters } from '@/types'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useAuditsStore } from '@/stores'
import { useAppToast } from './useToast'

export function useAudits() {
  const store = useAuditsStore()
  const toast = useAppToast()

  // Reactive refs from store
  const {
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
  } = storeToRefs(store)

  // Computed getters
  const auditCount = computed(() => store.auditCount)
  const currentPage = computed(() => store.currentPage)
  const totalPages = computed(() => store.totalPages)
  const hasActiveFilters = computed(() => store.hasActiveFilters)
  const auditableTypes = computed(() => store.auditableTypes)
  const auditActions = computed(() => store.auditActions)

  // Actions with toast handling

  /**
   * Fetch audits with current filters
   */
  async function fetchAudits(page: number = 1) {
    try {
      await store.fetchAudits(page)
    }
    catch (err) {
      toast.error('Failed to load audits', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Fetch single audit detail
   */
  async function fetchAuditDetail(id: number) {
    try {
      await store.fetchAuditDetail(id)
    }
    catch (err) {
      toast.error('Failed to load audit detail', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Fetch audit statistics
   */
  async function fetchStats() {
    try {
      await store.fetchStats()
    }
    catch (err) {
      toast.error('Failed to load audit statistics', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Update filters and refetch
   */
  async function setFilters(newFilters: Partial<IAuditFilters>) {
    try {
      await store.setFilters(newFilters)
    }
    catch (err) {
      toast.error('Failed to filter audits', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Clear all filters
   */
  async function clearFilters() {
    try {
      await store.clearFilters()
    }
    catch (err) {
      toast.error('Failed to clear filters', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Go to specific page
   */
  async function goToPage(page: number) {
    try {
      await store.goToPage(page)
    }
    catch (err) {
      toast.error('Failed to load page', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Get audit by ID from current list
   */
  function getAuditById(id: number) {
    return store.getAuditById(id)
  }

  /**
   * Clear selected audit detail
   */
  function clearSelectedAudit() {
    store.clearSelectedAudit()
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    store.reset()
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
    // Computed
    auditCount,
    currentPage,
    totalPages,
    hasActiveFilters,
    auditableTypes,
    auditActions,
    // Actions
    fetchAudits,
    fetchAuditDetail,
    fetchStats,
    setFilters,
    clearFilters,
    goToPage,
    getAuditById,
    clearSelectedAudit,
    reset,
  }
}
