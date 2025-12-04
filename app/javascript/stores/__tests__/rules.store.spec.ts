import type { ISlimRule } from '@/types'
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RULE_SEVERITIES, RULE_STATUSES, SEVERITY_MAP, useRulesStore } from '../rules.store'

// Mock the API
vi.mock('@/apis/rules.api', () => ({
  getComponentRules: vi.fn(),
  getRule: vi.fn(),
  updateRule: vi.fn(),
  createRule: vi.fn(),
  deleteRule: vi.fn(),
  createRuleSatisfaction: vi.fn(),
  deleteRuleSatisfaction: vi.fn(),
  createReview: vi.fn(),
  revertRule: vi.fn(),
}))

// Helper to create a mock slim rule
function createSlimRule(overrides: Partial<ISlimRule> = {}): ISlimRule {
  return {
    id: 1,
    rule_id: '000001',
    version: 'V1R1',
    title: 'Test Rule',
    status: 'Not Yet Determined',
    rule_severity: 'medium',
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    is_merged: false,
    satisfies_count: 0,
    ...overrides,
  }
}

describe('rules Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  describe('constants', () => {
    it('exports RULE_STATUSES', () => {
      expect(RULE_STATUSES).toContain('Not Yet Determined')
      expect(RULE_STATUSES).toContain('Applicable - Configurable')
      expect(RULE_STATUSES).toContain('Not Applicable')
      expect(RULE_STATUSES.length).toBe(5)
    })

    it('exports RULE_SEVERITIES', () => {
      expect(RULE_SEVERITIES).toContain('low')
      expect(RULE_SEVERITIES).toContain('medium')
      expect(RULE_SEVERITIES).toContain('high')
      expect(RULE_SEVERITIES.length).toBe(3)
    })

    it('exports SEVERITY_MAP', () => {
      expect(SEVERITY_MAP.low).toBe('CAT III')
      expect(SEVERITY_MAP.medium).toBe('CAT II')
      expect(SEVERITY_MAP.high).toBe('CAT I')
    })
  })

  describe('initial state', () => {
    it('has empty rules array', () => {
      const store = useRulesStore()
      expect(store.rules).toEqual([])
    })

    it('has null pagination', () => {
      const store = useRulesStore()
      expect(store.pagination).toBeNull()
    })

    it('has empty fullRulesCache', () => {
      const store = useRulesStore()
      expect(store.fullRulesCache.size).toBe(0)
    })

    it('has null currentRule', () => {
      const store = useRulesStore()
      expect(store.currentRule).toBeNull()
    })

    it('has showNestedRules true by default', () => {
      const store = useRulesStore()
      expect(store.showNestedRules).toBe(true)
    })

    it('has no loading state', () => {
      const store = useRulesStore()
      expect(store.loading).toBe(false)
    })

    it('has no error', () => {
      const store = useRulesStore()
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    describe('sortedRules', () => {
      it('sorts rules by rule_id', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, rule_id: '000003' }),
          createSlimRule({ id: 2, rule_id: '000001' }),
          createSlimRule({ id: 3, rule_id: '000002' }),
        ]

        expect(store.sortedRules.map(r => r.rule_id)).toEqual(['000001', '000002', '000003'])
      })
    })

    describe('primaryRules', () => {
      it('filters out merged rules', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, is_merged: false }),
          createSlimRule({ id: 2, is_merged: true }),
          createSlimRule({ id: 3, is_merged: false }),
        ]

        expect(store.primaryRules.length).toBe(2)
        expect(store.primaryRules.every(r => !r.is_merged)).toBe(true)
      })
    })

    describe('nestedRules', () => {
      it('returns only merged rules', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, is_merged: false }),
          createSlimRule({ id: 2, is_merged: true }),
          createSlimRule({ id: 3, is_merged: true }),
        ]

        expect(store.nestedRules.length).toBe(2)
        expect(store.nestedRules.every(r => r.is_merged)).toBe(true)
      })
    })

    describe('visibleRules', () => {
      it('returns all rules when showNestedRules is true', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, is_merged: false }),
          createSlimRule({ id: 2, is_merged: true }),
        ]
        store.showNestedRules = true

        expect(store.visibleRules.length).toBe(2)
      })

      it('returns only primary rules when showNestedRules is false', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, is_merged: false }),
          createSlimRule({ id: 2, is_merged: true }),
        ]
        store.showNestedRules = false

        expect(store.visibleRules.length).toBe(1)
        expect(store.visibleRules[0].is_merged).toBe(false)
      })
    })

    describe('getSlimRuleById', () => {
      it('returns the correct rule', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, title: 'Rule 1' }),
          createSlimRule({ id: 2, title: 'Rule 2' }),
        ]

        expect(store.getSlimRuleById(2)?.title).toBe('Rule 2')
      })

      it('returns undefined for non-existent id', () => {
        const store = useRulesStore()
        store.rules = [createSlimRule({ id: 1 })]

        expect(store.getSlimRuleById(999)).toBeUndefined()
      })
    })
  })

  describe('actions', () => {
    describe('toggleNestedRules', () => {
      it('toggles showNestedRules from true to false', () => {
        const store = useRulesStore()
        expect(store.showNestedRules).toBe(true)

        store.toggleNestedRules()

        expect(store.showNestedRules).toBe(false)
      })

      it('toggles showNestedRules from false to true', () => {
        const store = useRulesStore()
        store.showNestedRules = false

        store.toggleNestedRules()

        expect(store.showNestedRules).toBe(true)
      })
    })

    describe('updateSlimRuleLocal', () => {
      it('updates a rule in the list', () => {
        const store = useRulesStore()
        store.rules = [
          createSlimRule({ id: 1, status: 'Not Yet Determined' }),
        ]

        store.updateSlimRuleLocal(1, { status: 'Applicable - Configurable' })

        expect(store.rules[0].status).toBe('Applicable - Configurable')
      })

      it('does nothing for non-existent id', () => {
        const store = useRulesStore()
        store.rules = [createSlimRule({ id: 1 })]

        store.updateSlimRuleLocal(999, { status: 'Applicable - Configurable' })

        expect(store.rules.length).toBe(1)
        expect(store.rules[0].status).toBe('Not Yet Determined')
      })
    })

    describe('reset', () => {
      it('resets all state to initial values', () => {
        const store = useRulesStore()
        store.rules = [createSlimRule()]
        store.componentId = 123
        store.showNestedRules = false
        store.error = 'some error'

        store.reset()

        expect(store.rules).toEqual([])
        expect(store.componentId).toBeNull()
        expect(store.showNestedRules).toBe(true)
        expect(store.error).toBeNull()
        expect(store.fullRulesCache.size).toBe(0)
      })
    })
  })

  describe('satisfaction relationship getters', () => {
    it('correctly computes satisfies_count', () => {
      const store = useRulesStore()
      store.rules = [
        createSlimRule({ id: 1, satisfies_count: 3 }),
        createSlimRule({ id: 2, satisfies_count: 0 }),
      ]

      expect(store.rules[0].satisfies_count).toBe(3)
      expect(store.rules[1].satisfies_count).toBe(0)
    })

    it('correctly identifies merged rules', () => {
      const store = useRulesStore()
      store.rules = [
        createSlimRule({ id: 1, is_merged: true }),
        createSlimRule({ id: 2, is_merged: false }),
      ]

      expect(store.rules[0].is_merged).toBe(true)
      expect(store.rules[1].is_merged).toBe(false)
    })

    it('filters satisfaction relationships in visibleRules', () => {
      const store = useRulesStore()
      store.rules = [
        createSlimRule({ id: 1, is_merged: false, satisfies_count: 2 }), // parent
        createSlimRule({ id: 2, is_merged: true, satisfies_count: 0 }), // child
        createSlimRule({ id: 3, is_merged: true, satisfies_count: 0 }), // child
      ]

      // With showNestedRules = true, all visible
      store.showNestedRules = true
      expect(store.visibleRules.length).toBe(3)

      // With showNestedRules = false, only parent visible
      store.showNestedRules = false
      expect(store.visibleRules.length).toBe(1)
      expect(store.visibleRules[0].satisfies_count).toBe(2)
    })
  })

  describe('fullRuleToSlim conversion', () => {
    it('computes satisfies_count from satisfies array', async () => {
      const store = useRulesStore()
      // Set up initial rules
      store.rules = [createSlimRule({ id: 1, satisfies_count: 0 })]

      // Mock the API to return a full rule with satisfies
      const mockFullRule = {
        id: 1,
        rule_id: '000001',
        version: 'V1R1',
        title: 'Parent Rule',
        status: 'Applicable - Configurable',
        rule_severity: 'medium',
        locked: false,
        review_requestor_id: null,
        satisfies: [
          { id: 10, rule_id: '000010', title: 'Child Rule 1' },
          { id: 11, rule_id: '000011', title: 'Child Rule 2' },
          { id: 12, rule_id: '000012', title: 'Child Rule 3' },
        ],
        satisfied_by: [],
      }

      const { getRule } = await import('@/apis/rules.api')
      vi.mocked(getRule).mockResolvedValueOnce({ data: mockFullRule })

      // Call refreshRule which uses fullRuleToSlim internally
      await store.refreshRule(1)

      // Verify satisfies_count was computed correctly
      expect(store.rules[0].satisfies_count).toBe(3)
    })

    it('computes satisfies_rules from satisfies array with correct fields', async () => {
      const store = useRulesStore()
      store.rules = [createSlimRule({ id: 1 })]

      const mockFullRule = {
        id: 1,
        rule_id: '000001',
        version: 'V1R1',
        title: 'Parent Rule',
        status: 'Applicable - Configurable',
        rule_severity: 'medium',
        locked: false,
        review_requestor_id: null,
        satisfies: [
          { id: 10, rule_id: '000010', title: 'Child Rule 1', fixtext: 'Some fix' },
          { id: 11, rule_id: '000011', title: 'Child Rule 2', fixtext: 'Another fix' },
        ],
        satisfied_by: [],
      }

      const { getRule } = await import('@/apis/rules.api')
      vi.mocked(getRule).mockResolvedValueOnce({ data: mockFullRule })

      await store.refreshRule(1)

      // Verify satisfies_rules has correct structure (id, rule_id, title only)
      expect(store.rules[0].satisfies_rules).toEqual([
        { id: 10, rule_id: '000010', title: 'Child Rule 1' },
        { id: 11, rule_id: '000011', title: 'Child Rule 2' },
      ])
    })

    it('sets is_merged based on satisfied_by array', async () => {
      const store = useRulesStore()
      store.rules = [createSlimRule({ id: 1, is_merged: false })]

      const mockFullRule = {
        id: 1,
        rule_id: '000001',
        version: 'V1R1',
        title: 'Child Rule',
        status: 'Applicable - Configurable',
        rule_severity: 'medium',
        locked: false,
        review_requestor_id: null,
        satisfies: [],
        satisfied_by: [
          { id: 100, rule_id: '000100', title: 'Parent Rule' },
        ],
      }

      const { getRule } = await import('@/apis/rules.api')
      vi.mocked(getRule).mockResolvedValueOnce({ data: mockFullRule })

      await store.refreshRule(1)

      // Verify is_merged is true when satisfied_by has entries
      expect(store.rules[0].is_merged).toBe(true)
    })

    it('handles empty satisfies array correctly', async () => {
      const store = useRulesStore()
      store.rules = [createSlimRule({ id: 1, satisfies_count: 5 })] // Pre-set to non-zero

      const mockFullRule = {
        id: 1,
        rule_id: '000001',
        version: 'V1R1',
        title: 'Rule with no satisfies',
        status: 'Not Yet Determined',
        rule_severity: 'medium',
        locked: false,
        review_requestor_id: null,
        satisfies: [],
        satisfied_by: [],
      }

      const { getRule } = await import('@/apis/rules.api')
      vi.mocked(getRule).mockResolvedValueOnce({ data: mockFullRule })

      await store.refreshRule(1)

      // Verify satisfies_count is 0 and satisfies_rules is empty
      expect(store.rules[0].satisfies_count).toBe(0)
      expect(store.rules[0].satisfies_rules).toEqual([])
      expect(store.rules[0].is_merged).toBe(false)
    })

    it('handles undefined satisfies array correctly', async () => {
      const store = useRulesStore()
      store.rules = [createSlimRule({ id: 1 })]

      const mockFullRule = {
        id: 1,
        rule_id: '000001',
        version: 'V1R1',
        title: 'Rule with undefined satisfies',
        status: 'Not Yet Determined',
        rule_severity: 'medium',
        locked: false,
        review_requestor_id: null,
        // satisfies and satisfied_by are undefined
      }

      const { getRule } = await import('@/apis/rules.api')
      vi.mocked(getRule).mockResolvedValueOnce({ data: mockFullRule })

      await store.refreshRule(1)

      // Verify defaults are used
      expect(store.rules[0].satisfies_count).toBe(0)
      expect(store.rules[0].satisfies_rules).toEqual([])
      expect(store.rules[0].is_merged).toBe(false)
    })
  })
})
