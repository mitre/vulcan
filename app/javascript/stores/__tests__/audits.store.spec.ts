/**
 * Audits Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuditsStore } from '../audits.store'

// Mock the API module
vi.mock('@/apis/audits.api', () => ({
  getAudits: vi.fn(),
  getAuditDetail: vi.fn(),
  getAuditStats: vi.fn(),
}))

describe('audits Store', () => {
  let store: ReturnType<typeof useAuditsStore>

  beforeEach(() => {
    store = useAuditsStore()
    store.reset()
  })

  describe('initial state', () => {
    it('has empty audits array', () => {
      expect(store.audits).toEqual([])
    })

    it('has selectedAudit null', () => {
      expect(store.selectedAudit).toBeNull()
    })

    it('has stats null', () => {
      expect(store.stats).toBeNull()
    })

    it('has filterOptions null', () => {
      expect(store.filterOptions).toBeNull()
    })

    it('has pagination null', () => {
      expect(store.pagination).toBeNull()
    })

    it('has default filters', () => {
      expect(store.filters).toEqual({
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

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })

    it('has statsLoading false', () => {
      expect(store.statsLoading).toBe(false)
    })

    it('has detailLoading false', () => {
      expect(store.detailLoading).toBe(false)
    })

    it('has error null', () => {
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    it('auditCount returns pagination total when available', () => {
      expect(store.auditCount).toBe(0)
      store.$patch({ audits: [{ id: 1 }, { id: 2 }] as any })
      expect(store.auditCount).toBe(2)
      store.$patch({ pagination: { page: 1, per_page: 50, total: 1000, total_pages: 20 } })
      expect(store.auditCount).toBe(1000)
    })

    it('currentPage returns pagination page or 1', () => {
      expect(store.currentPage).toBe(1)
      store.$patch({ pagination: { page: 5, per_page: 50, total: 1000, total_pages: 20 } })
      expect(store.currentPage).toBe(5)
    })

    it('totalPages returns pagination total_pages or 1', () => {
      expect(store.totalPages).toBe(1)
      store.$patch({ pagination: { page: 1, per_page: 50, total: 1000, total_pages: 20 } })
      expect(store.totalPages).toBe(20)
    })

    it('hasActiveFilters returns false when no filters', () => {
      expect(store.hasActiveFilters).toBe(false)
    })

    it('hasActiveFilters returns true when auditable_type set', () => {
      store.$patch({
        filters: { ...store.filters, auditable_type: 'User' },
      })
      expect(store.hasActiveFilters).toBe(true)
    })

    it('hasActiveFilters returns true when action_type set', () => {
      store.$patch({
        filters: { ...store.filters, action_type: 'update' },
      })
      expect(store.hasActiveFilters).toBe(true)
    })

    it('hasActiveFilters returns true when search set', () => {
      store.$patch({
        filters: { ...store.filters, search: 'test' },
      })
      expect(store.hasActiveFilters).toBe(true)
    })

    it('getAuditById finds audit by id', () => {
      const mockAudit = { id: 42, auditable_type: 'User', action: 'update' }
      store.$patch({ audits: [mockAudit] as any })
      expect(store.getAuditById(42)).toEqual(mockAudit)
      expect(store.getAuditById(999)).toBeUndefined()
    })

    it('auditableTypes returns filter options auditable_types', () => {
      expect(store.auditableTypes).toEqual([])
      store.$patch({
        filterOptions: {
          auditable_types: ['User', 'Project'],
          actions: ['create', 'update'],
        },
      })
      expect(store.auditableTypes).toEqual(['User', 'Project'])
    })

    it('auditActions returns filter options actions', () => {
      expect(store.auditActions).toEqual([])
      store.$patch({
        filterOptions: {
          auditable_types: ['User', 'Project'],
          actions: ['create', 'update'],
        },
      })
      expect(store.auditActions).toEqual(['create', 'update'])
    })
  })

  describe('actions', () => {
    it('clearSelectedAudit sets selectedAudit to null', () => {
      store.$patch({ selectedAudit: { id: 1 } as any })
      store.clearSelectedAudit()
      expect(store.selectedAudit).toBeNull()
    })

    it('reset clears all state to initial', () => {
      store.$patch({
        audits: [{ id: 1 }] as any,
        selectedAudit: { id: 1 } as any,
        stats: { total_audits: 100 } as any,
        pagination: { page: 5 } as any,
        filters: { auditable_type: 'User', action_type: '', user_id: '', from_date: '', to_date: '', search: '', page: 5, per_page: 50 },
        loading: true,
        error: 'some error',
      })

      store.reset()

      expect(store.audits).toEqual([])
      expect(store.selectedAudit).toBeNull()
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
      expect(store.filters.page).toBe(1)
      expect(store.filters.auditable_type).toBe('')
    })
  })
})
