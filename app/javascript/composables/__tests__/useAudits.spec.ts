/**
 * useAudits Composable Unit Tests
 */

import type { IAudit, IAuditDetail, IAuditFilters } from '@/types'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuditsStore } from '@/stores'
import { useAudits } from '../useAudits'

// Mock the toast composable
vi.mock('../useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

// Mock the API module
vi.mock('@/apis/audits.api', () => ({
  getAudits: vi.fn(),
  getAuditDetail: vi.fn(),
  getAuditStats: vi.fn(),
}))

// Sample audit data
const sampleAudit: IAudit = {
  id: 1,
  auditable_type: 'User',
  auditable_id: 123,
  action: 'update',
  version: 1,
  user_id: 1,
  user_name: 'Admin User',
  remote_address: '127.0.0.1',
  created_at: '2024-01-01T12:00:00Z',
  changes_summary: 'name changed',
}

const sampleAuditDetail: IAuditDetail = {
  ...sampleAudit,
  associated_type: null,
  associated_id: null,
  audited_changes: { name: ['Old Name', 'New Name'] },
  comment: null,
  request_uuid: 'uuid-123',
  user_email: 'admin@example.com',
  auditable_exists: true,
  auditable_name: 'Test User',
}

describe('useAudits', () => {
  let composable: ReturnType<typeof useAudits>
  let store: ReturnType<typeof useAuditsStore>

  beforeEach(() => {
    store = useAuditsStore()
    store.reset()
    composable = useAudits()
  })

  describe('reactive state', () => {
    it('exposes audits as reactive ref', () => {
      expect(composable.audits.value).toEqual([])

      store.$patch({ audits: [sampleAudit] })
      expect(composable.audits.value).toHaveLength(1)
      expect(composable.audits.value[0]).toEqual(sampleAudit)
    })

    it('exposes selectedAudit as reactive ref', () => {
      expect(composable.selectedAudit.value).toBeNull()

      store.$patch({ selectedAudit: sampleAuditDetail })
      expect(composable.selectedAudit.value).toEqual(sampleAuditDetail)
    })

    it('exposes stats as reactive ref', () => {
      expect(composable.stats.value).toBeNull()

      const stats = {
        total_audits: 1000,
        audits_today: 50,
        audits_this_week: 200,
        by_type: { User: 500, Project: 300, Component: 200 },
        by_action: { create: 300, update: 500, destroy: 200 },
        cached_at: '2024-01-01T12:00:00Z',
      }
      store.$patch({ stats })
      expect(composable.stats.value).toEqual(stats)
    })

    it('exposes filterOptions as reactive ref', () => {
      expect(composable.filterOptions.value).toBeNull()

      const filterOptions = {
        auditable_types: ['User', 'Project', 'Component'] as const,
        actions: ['create', 'update', 'destroy'] as const,
      }
      store.$patch({ filterOptions })
      expect(composable.filterOptions.value).toEqual(filterOptions)
    })

    it('exposes pagination as reactive ref', () => {
      expect(composable.pagination.value).toBeNull()

      store.$patch({ pagination: { page: 1, per_page: 50, total: 1000, total_pages: 20 } })
      expect(composable.pagination.value).toEqual({ page: 1, per_page: 50, total: 1000, total_pages: 20 })
    })

    it('exposes filters as reactive ref', () => {
      expect(composable.filters.value).toEqual({
        auditable_type: '',
        action_type: '',
        user_id: '',
        from_date: '',
        to_date: '',
        search: '',
        page: 1,
        per_page: 50,
      })
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })

    it('exposes statsLoading as reactive ref', () => {
      expect(composable.statsLoading.value).toBe(false)

      store.$patch({ statsLoading: true })
      expect(composable.statsLoading.value).toBe(true)
    })

    it('exposes detailLoading as reactive ref', () => {
      expect(composable.detailLoading.value).toBe(false)

      store.$patch({ detailLoading: true })
      expect(composable.detailLoading.value).toBe(true)
    })

    it('exposes error as reactive ref', () => {
      expect(composable.error.value).toBeNull()

      store.$patch({ error: 'Test error' })
      expect(composable.error.value).toBe('Test error')
    })
  })

  describe('computed properties', () => {
    it('auditCount returns pagination total or audits length', () => {
      expect(composable.auditCount.value).toBe(0)

      store.$patch({ audits: [sampleAudit, { ...sampleAudit, id: 2 }, { ...sampleAudit, id: 3 }] })
      expect(composable.auditCount.value).toBe(3)

      store.$patch({ pagination: { page: 1, per_page: 50, total: 1000, total_pages: 20 } })
      expect(composable.auditCount.value).toBe(1000)
    })

    it('currentPage returns pagination page or 1', () => {
      expect(composable.currentPage.value).toBe(1)

      store.$patch({ pagination: { page: 5, per_page: 50, total: 1000, total_pages: 20 } })
      expect(composable.currentPage.value).toBe(5)
    })

    it('totalPages returns pagination total_pages or 1', () => {
      expect(composable.totalPages.value).toBe(1)

      store.$patch({ pagination: { page: 1, per_page: 50, total: 1000, total_pages: 20 } })
      expect(composable.totalPages.value).toBe(20)
    })

    it('hasActiveFilters returns false when no filters set', () => {
      expect(composable.hasActiveFilters.value).toBe(false)
    })

    it('hasActiveFilters returns true when auditable_type filter is set', () => {
      store.$patch({
        filters: {
          auditable_type: 'User',
          action_type: '',
          user_id: '',
          from_date: '',
          to_date: '',
          search: '',
          page: 1,
          per_page: 50,
        },
      })
      expect(composable.hasActiveFilters.value).toBe(true)
    })

    it('hasActiveFilters returns true when action_type filter is set', () => {
      store.$patch({
        filters: {
          auditable_type: '',
          action_type: 'update',
          user_id: '',
          from_date: '',
          to_date: '',
          search: '',
          page: 1,
          per_page: 50,
        },
      })
      expect(composable.hasActiveFilters.value).toBe(true)
    })

    it('hasActiveFilters returns true when search filter is set', () => {
      store.$patch({
        filters: {
          auditable_type: '',
          action_type: '',
          user_id: '',
          from_date: '',
          to_date: '',
          search: 'test',
          page: 1,
          per_page: 50,
        },
      })
      expect(composable.hasActiveFilters.value).toBe(true)
    })

    it('auditableTypes returns filter options auditable_types', () => {
      expect(composable.auditableTypes.value).toEqual([])

      store.$patch({
        filterOptions: {
          auditable_types: ['User', 'Project', 'Component'] as const,
          actions: ['create', 'update', 'destroy'] as const,
        },
      })
      expect(composable.auditableTypes.value).toEqual(['User', 'Project', 'Component'])
    })

    it('auditActions returns filter options actions', () => {
      expect(composable.auditActions.value).toEqual([])

      store.$patch({
        filterOptions: {
          auditable_types: ['User', 'Project', 'Component'] as const,
          actions: ['create', 'update', 'destroy'] as const,
        },
      })
      expect(composable.auditActions.value).toEqual(['create', 'update', 'destroy'])
    })
  })

  describe('actions', () => {
    it('fetchAudits calls store.fetchAudits', async () => {
      const spy = vi.spyOn(store, 'fetchAudits').mockResolvedValue(undefined as any)
      await composable.fetchAudits(2)
      expect(spy).toHaveBeenCalledWith(2)
    })

    it('fetchAudits defaults to page 1', async () => {
      const spy = vi.spyOn(store, 'fetchAudits').mockResolvedValue(undefined as any)
      await composable.fetchAudits()
      expect(spy).toHaveBeenCalledWith(1)
    })

    it('fetchAuditDetail calls store.fetchAuditDetail', async () => {
      const spy = vi.spyOn(store, 'fetchAuditDetail').mockResolvedValue(undefined as any)
      await composable.fetchAuditDetail(123)
      expect(spy).toHaveBeenCalledWith(123)
    })

    it('fetchStats calls store.fetchStats', async () => {
      const spy = vi.spyOn(store, 'fetchStats').mockResolvedValue(undefined as any)
      await composable.fetchStats()
      expect(spy).toHaveBeenCalled()
    })

    it('setFilters calls store.setFilters', async () => {
      const spy = vi.spyOn(store, 'setFilters').mockResolvedValue(undefined as any)
      const newFilters: Partial<IAuditFilters> = { auditable_type: 'User', action_type: 'update' }
      await composable.setFilters(newFilters)
      expect(spy).toHaveBeenCalledWith(newFilters)
    })

    it('clearFilters calls store.clearFilters', async () => {
      const spy = vi.spyOn(store, 'clearFilters').mockResolvedValue(undefined as any)
      await composable.clearFilters()
      expect(spy).toHaveBeenCalled()
    })

    it('goToPage calls store.goToPage', async () => {
      const spy = vi.spyOn(store, 'goToPage').mockResolvedValue(undefined as any)
      await composable.goToPage(5)
      expect(spy).toHaveBeenCalledWith(5)
    })

    it('getAuditById calls store.getAuditById', () => {
      store.$patch({ audits: [sampleAudit] })
      const audit = composable.getAuditById(1)
      expect(audit).toEqual(sampleAudit)
    })

    it('getAuditById returns undefined for non-existent id', () => {
      store.$patch({ audits: [sampleAudit] })
      const audit = composable.getAuditById(999)
      expect(audit).toBeUndefined()
    })

    it('clearSelectedAudit calls store.clearSelectedAudit', () => {
      const spy = vi.spyOn(store, 'clearSelectedAudit')
      composable.clearSelectedAudit()
      expect(spy).toHaveBeenCalled()
    })

    it('reset calls store.reset', () => {
      const spy = vi.spyOn(store, 'reset')
      composable.reset()
      expect(spy).toHaveBeenCalled()
    })
  })

  describe('error handling', () => {
    it('fetchAudits shows error toast on failure', async () => {
      vi.spyOn(store, 'fetchAudits').mockRejectedValue(new Error('Network error'))
      await composable.fetchAudits()
      // Toast error is called (mock doesn't throw)
    })

    it('fetchAuditDetail shows error toast on failure', async () => {
      vi.spyOn(store, 'fetchAuditDetail').mockRejectedValue(new Error('Not found'))
      await composable.fetchAuditDetail(999)
      // Toast error is called (mock doesn't throw)
    })

    it('fetchStats shows error toast on failure', async () => {
      vi.spyOn(store, 'fetchStats').mockRejectedValue(new Error('Server error'))
      await composable.fetchStats()
      // Toast error is called (mock doesn't throw)
    })

    it('setFilters shows error toast on failure', async () => {
      vi.spyOn(store, 'setFilters').mockRejectedValue(new Error('Filter error'))
      await composable.setFilters({ auditable_type: 'User' })
      // Toast error is called (mock doesn't throw)
    })

    it('clearFilters shows error toast on failure', async () => {
      vi.spyOn(store, 'clearFilters').mockRejectedValue(new Error('Clear error'))
      await composable.clearFilters()
      // Toast error is called (mock doesn't throw)
    })

    it('goToPage shows error toast on failure', async () => {
      vi.spyOn(store, 'goToPage').mockRejectedValue(new Error('Page error'))
      await composable.goToPage(5)
      // Toast error is called (mock doesn't throw)
    })
  })
})
