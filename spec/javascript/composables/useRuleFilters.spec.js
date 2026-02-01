import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { ref } from 'vue'
import { useRuleFilters } from '@/composables/useRuleFilters'

describe('useRuleFilters', () => {
  const mockRules = ref([
    { id: 1, rule_id: 'CNTR-00-000010', status: 'Applicable - Configurable', locked: false, review_requestor_id: null },
    { id: 2, rule_id: 'CNTR-00-000020', status: 'Applicable - Configurable', locked: true, review_requestor_id: null },
    { id: 3, rule_id: 'CNTR-00-000030', status: 'Applicable - Inherently Meets', locked: false, review_requestor_id: null },
    { id: 4, rule_id: 'CNTR-00-000040', status: 'Applicable - Does Not Meet', locked: false, review_requestor_id: 5 },
    { id: 5, rule_id: 'CNTR-00-000050', status: 'Not Applicable', locked: false, review_requestor_id: null },
    { id: 6, rule_id: 'CNTR-00-000060', status: 'Not Yet Determined', locked: false, review_requestor_id: null },
  ])

  const componentId = 41

  beforeEach(() => {
    localStorage.clear()
    vi.clearAllMocks()
  })

  afterEach(() => {
    localStorage.clear()
  })

  describe('initialization', () => {
    it('initializes with all status filters enabled', () => {
      const { filters } = useRuleFilters(mockRules, componentId)
      expect(filters.value.acFilterChecked).toBe(true)
      expect(filters.value.aimFilterChecked).toBe(true)
      expect(filters.value.adnmFilterChecked).toBe(true)
      expect(filters.value.naFilterChecked).toBe(true)
      expect(filters.value.nydFilterChecked).toBe(true)
    })

    it('initializes with all review filters enabled', () => {
      const { filters } = useRuleFilters(mockRules, componentId)
      expect(filters.value.nurFilterChecked).toBe(true)
      expect(filters.value.urFilterChecked).toBe(true)
      expect(filters.value.lckFilterChecked).toBe(true)
    })

    it('initializes with display options disabled', () => {
      const { filters } = useRuleFilters(mockRules, componentId)
      expect(filters.value.nestSatisfiedRulesChecked).toBe(false)
      expect(filters.value.showSRGIdChecked).toBe(false)
      expect(filters.value.sortBySRGIdChecked).toBe(false)
    })

    it('initializes with empty search', () => {
      const { filters } = useRuleFilters(mockRules, componentId)
      expect(filters.value.search).toBe('')
    })
  })

  describe('counts', () => {
    it('computes status counts correctly', () => {
      const { counts } = useRuleFilters(mockRules, componentId)
      expect(counts.value.ac).toBe(2)   // 2 Applicable - Configurable
      expect(counts.value.aim).toBe(1)  // 1 Applicable - Inherently Meets
      expect(counts.value.adnm).toBe(1) // 1 Applicable - Does Not Meet
      expect(counts.value.na).toBe(1)   // 1 Not Applicable
      expect(counts.value.nyd).toBe(1)  // 1 Not Yet Determined
    })

    it('computes review counts correctly', () => {
      const { counts } = useRuleFilters(mockRules, componentId)
      expect(counts.value.lck).toBe(1)  // 1 locked
      expect(counts.value.ur).toBe(1)   // 1 under review (has review_requestor_id)
      expect(counts.value.nur).toBe(4)  // 4 not under review (not locked, no review_requestor_id)
    })

    it('updates counts when rules change', () => {
      const rules = ref([
        { id: 1, status: 'Applicable - Configurable', locked: false, review_requestor_id: null }
      ])
      const { counts } = useRuleFilters(rules, componentId)
      expect(counts.value.ac).toBe(1)

      rules.value.push({ id: 2, status: 'Applicable - Configurable', locked: false, review_requestor_id: null })
      expect(counts.value.ac).toBe(2)
    })
  })

  describe('toggleFilter', () => {
    it('toggles a filter from true to false', () => {
      const { filters, toggleFilter } = useRuleFilters(mockRules, componentId)
      expect(filters.value.acFilterChecked).toBe(true)
      toggleFilter('acFilterChecked')
      expect(filters.value.acFilterChecked).toBe(false)
    })

    it('toggles a filter from false to true', () => {
      const { filters, toggleFilter } = useRuleFilters(mockRules, componentId)
      expect(filters.value.nestSatisfiedRulesChecked).toBe(false)
      toggleFilter('nestSatisfiedRulesChecked')
      expect(filters.value.nestSatisfiedRulesChecked).toBe(true)
    })
  })

  describe('setFilter', () => {
    it('sets a filter to a specific value', () => {
      const { filters, setFilter } = useRuleFilters(mockRules, componentId)
      setFilter('acFilterChecked', false)
      expect(filters.value.acFilterChecked).toBe(false)
      setFilter('acFilterChecked', true)
      expect(filters.value.acFilterChecked).toBe(true)
    })

    it('sets search filter', () => {
      const { filters, setFilter } = useRuleFilters(mockRules, componentId)
      setFilter('search', 'CNTR-00')
      expect(filters.value.search).toBe('CNTR-00')
    })
  })

  describe('resetFilters', () => {
    it('resets all filters to defaults', () => {
      const { filters, toggleFilter, setFilter, resetFilters } = useRuleFilters(mockRules, componentId)

      // Change some filters
      toggleFilter('acFilterChecked')
      toggleFilter('nestSatisfiedRulesChecked')
      setFilter('search', 'test')

      // Reset
      resetFilters()

      // Verify defaults restored
      expect(filters.value.acFilterChecked).toBe(true)
      expect(filters.value.nestSatisfiedRulesChecked).toBe(false)
      expect(filters.value.search).toBe('')
    })
  })

  describe('filteredRules', () => {
    it('returns all rules when all filters enabled', () => {
      const { filteredRules } = useRuleFilters(mockRules, componentId)
      expect(filteredRules.value.length).toBe(6)
    })

    it('filters by status', () => {
      const { filters, filteredRules } = useRuleFilters(mockRules, componentId)
      filters.value.aimFilterChecked = false
      filters.value.adnmFilterChecked = false
      filters.value.naFilterChecked = false
      filters.value.nydFilterChecked = false
      // Only Applicable - Configurable should remain
      expect(filteredRules.value.length).toBe(2)
      expect(filteredRules.value.every(r => r.status === 'Applicable - Configurable')).toBe(true)
    })

    it('filters by review status (locked)', () => {
      const { filters, filteredRules } = useRuleFilters(mockRules, componentId)
      filters.value.nurFilterChecked = false
      filters.value.urFilterChecked = false
      // Only locked should remain
      expect(filteredRules.value.length).toBe(1)
      expect(filteredRules.value[0].locked).toBe(true)
    })

    it('filters by review status (under review)', () => {
      const { filters, filteredRules } = useRuleFilters(mockRules, componentId)
      filters.value.nurFilterChecked = false
      filters.value.lckFilterChecked = false
      // Only under review should remain
      expect(filteredRules.value.length).toBe(1)
      expect(filteredRules.value[0].review_requestor_id).toBeTruthy()
    })

    it('filters by search term (rule_id)', () => {
      const { filters, filteredRules } = useRuleFilters(mockRules, componentId)
      filters.value.search = '000010'
      expect(filteredRules.value.length).toBe(1)
      expect(filteredRules.value[0].rule_id).toBe('CNTR-00-000010')
    })

    it('search is case insensitive', () => {
      const { filters, filteredRules } = useRuleFilters(mockRules, componentId)
      filters.value.search = 'cntr-00-000010'
      expect(filteredRules.value.length).toBe(1)
    })

    it('combines status and search filters', () => {
      const { filters, filteredRules } = useRuleFilters(mockRules, componentId)
      filters.value.aimFilterChecked = false
      filters.value.adnmFilterChecked = false
      filters.value.naFilterChecked = false
      filters.value.nydFilterChecked = false
      filters.value.search = '000010'
      expect(filteredRules.value.length).toBe(1)
    })
  })

  describe('allStatusFiltersEnabled', () => {
    it('returns true when all status filters are enabled', () => {
      const { allStatusFiltersEnabled } = useRuleFilters(mockRules, componentId)
      expect(allStatusFiltersEnabled.value).toBe(true)
    })

    it('returns false when any status filter is disabled', () => {
      const { filters, allStatusFiltersEnabled } = useRuleFilters(mockRules, componentId)
      filters.value.acFilterChecked = false
      expect(allStatusFiltersEnabled.value).toBe(false)
    })
  })

  describe('allReviewFiltersEnabled', () => {
    it('returns true when all review filters are enabled', () => {
      const { allReviewFiltersEnabled } = useRuleFilters(mockRules, componentId)
      expect(allReviewFiltersEnabled.value).toBe(true)
    })

    it('returns false when any review filter is disabled', () => {
      const { filters, allReviewFiltersEnabled } = useRuleFilters(mockRules, componentId)
      filters.value.lckFilterChecked = false
      expect(allReviewFiltersEnabled.value).toBe(false)
    })
  })
})
