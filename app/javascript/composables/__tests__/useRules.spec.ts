import type { ISlimRule } from '@/types'
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { RULE_SEVERITIES, RULE_STATUSES, SEVERITY_MAP, useRules } from '../useRules'

// Mock the toast composable with tracking
const mockToast = {
  success: vi.fn(),
  successWithUndo: vi.fn(),
  error: vi.fn(),
  info: vi.fn(),
  warning: vi.fn(),
}
vi.mock('../useToast', () => ({
  useAppToast: () => mockToast,
}))

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

describe('useRules composable', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  describe('exported constants', () => {
    it('exports RULE_STATUSES', () => {
      const { RULE_STATUSES: statuses } = useRules()
      expect(statuses).toContain('Not Yet Determined')
      expect(statuses).toContain('Applicable - Configurable')
      expect(statuses.length).toBe(5)
    })

    it('exports RULE_SEVERITIES', () => {
      const { RULE_SEVERITIES: severities } = useRules()
      expect(severities).toContain('low')
      expect(severities).toContain('medium')
      expect(severities).toContain('high')
    })

    it('exports SEVERITY_MAP', () => {
      const { SEVERITY_MAP: map } = useRules()
      expect(map.low).toBe('CAT III')
      expect(map.medium).toBe('CAT II')
      expect(map.high).toBe('CAT I')
    })
  })

  describe('reactive state', () => {
    it('provides reactive rules array', () => {
      const { rules } = useRules()
      expect(rules.value).toEqual([])
    })

    it('provides reactive currentRule', () => {
      const { currentRule } = useRules()
      expect(currentRule.value).toBeNull()
    })

    it('provides reactive loading state', () => {
      const { loading } = useRules()
      expect(loading.value).toBe(false)
    })

    it('provides reactive error state', () => {
      const { error } = useRules()
      expect(error.value).toBeNull()
    })

    it('provides reactive showNestedRules', () => {
      const { showNestedRules } = useRules()
      expect(showNestedRules.value).toBe(true)
    })
  })

  describe('computed getters', () => {
    it('provides sortedRules', () => {
      const { rules, sortedRules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, rule_id: '000002' }),
        createSlimRule({ id: 2, rule_id: '000001' }),
      ]

      expect(sortedRules.value.map(r => r.rule_id)).toEqual(['000001', '000002'])
    })

    it('provides primaryRules (non-merged)', () => {
      const { rules, primaryRules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, is_merged: false }),
        createSlimRule({ id: 2, is_merged: true }),
      ]

      expect(primaryRules.value.length).toBe(1)
      expect(primaryRules.value[0].is_merged).toBe(false)
    })

    it('provides nestedRules (merged)', () => {
      const { rules, nestedRules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, is_merged: false }),
        createSlimRule({ id: 2, is_merged: true }),
        createSlimRule({ id: 3, is_merged: true }),
      ]

      expect(nestedRules.value.length).toBe(2)
      expect(nestedRules.value.every(r => r.is_merged)).toBe(true)
    })

    it('provides visibleRules based on showNestedRules toggle', () => {
      const { rules, visibleRules, showNestedRules, toggleNestedRules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, is_merged: false }),
        createSlimRule({ id: 2, is_merged: true }),
      ]

      // Default: showNestedRules = true, all visible
      expect(visibleRules.value.length).toBe(2)

      // Toggle off: only primary visible
      toggleNestedRules()
      expect(showNestedRules.value).toBe(false)
      expect(visibleRules.value.length).toBe(1)
    })
  })

  describe('getSlimRuleById', () => {
    it('returns rule by id', () => {
      const { rules, getSlimRuleById } = useRules()
      rules.value = [
        createSlimRule({ id: 1, title: 'First' }),
        createSlimRule({ id: 2, title: 'Second' }),
      ]

      expect(getSlimRuleById(2)?.title).toBe('Second')
    })

    it('returns undefined for non-existent id', () => {
      const { rules, getSlimRuleById } = useRules()
      rules.value = [createSlimRule({ id: 1 })]

      expect(getSlimRuleById(999)).toBeUndefined()
    })
  })

  describe('toggleNestedRules', () => {
    it('toggles showNestedRules state', () => {
      const { showNestedRules, toggleNestedRules } = useRules()

      expect(showNestedRules.value).toBe(true)
      toggleNestedRules()
      expect(showNestedRules.value).toBe(false)
      toggleNestedRules()
      expect(showNestedRules.value).toBe(true)
    })
  })

  describe('updateSlimRuleLocal', () => {
    it('updates rule in place', () => {
      const { rules, updateSlimRuleLocal } = useRules()
      rules.value = [createSlimRule({ id: 1, status: 'Not Yet Determined' })]

      updateSlimRuleLocal(1, { status: 'Applicable - Configurable' })

      expect(rules.value[0].status).toBe('Applicable - Configurable')
    })
  })

  describe('satisfaction relationships', () => {
    beforeEach(() => {
      mockToast.success.mockClear()
      mockToast.successWithUndo.mockClear()
      mockToast.error.mockClear()
    })

    it('exposes satisfies_count on rules', () => {
      const { rules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, satisfies_count: 5 }),
        createSlimRule({ id: 2, satisfies_count: 0 }),
      ]

      expect(rules.value[0].satisfies_count).toBe(5)
      expect(rules.value[1].satisfies_count).toBe(0)
    })

    it('exposes is_merged on rules', () => {
      const { rules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, is_merged: true }),
        createSlimRule({ id: 2, is_merged: false }),
      ]

      expect(rules.value[0].is_merged).toBe(true)
      expect(rules.value[1].is_merged).toBe(false)
    })

    it('filters based on showNestedRules toggle', () => {
      const { rules, visibleRules, showNestedRules, toggleNestedRules } = useRules()
      rules.value = [
        createSlimRule({ id: 1, is_merged: false, satisfies_count: 2 }), // parent
        createSlimRule({ id: 2, is_merged: true, satisfies_count: 0 }), // child
        createSlimRule({ id: 3, is_merged: true, satisfies_count: 0 }), // child
      ]

      // All visible when showNestedRules = true
      expect(showNestedRules.value).toBe(true)
      expect(visibleRules.value.length).toBe(3)

      // Only parent visible when showNestedRules = false
      toggleNestedRules()
      expect(visibleRules.value.length).toBe(1)
      expect(visibleRules.value[0].id).toBe(1)
      expect(visibleRules.value[0].satisfies_count).toBe(2)
    })

    describe('removeSatisfaction', () => {
      it('shows successWithUndo toast on successful removal', async () => {
        const { removeSatisfaction } = useRules()

        // Mock the API
        const { deleteRuleSatisfaction, getRule } = await import('@/apis/rules.api')
        vi.mocked(deleteRuleSatisfaction).mockResolvedValueOnce({ data: {} })
        vi.mocked(getRule).mockResolvedValue({
          data: {
            id: 1,
            rule_id: '000001',
            version: 'V1R1',
            title: 'Test',
            status: 'Not Yet Determined',
            rule_severity: 'medium',
            locked: false,
            satisfies: [],
            satisfied_by: [],
          },
        })

        const result = await removeSatisfaction(10, 20)

        expect(result).toBe(true)
        // Uses successWithUndo for Gmail/Outlook style undo pattern
        expect(mockToast.successWithUndo).toHaveBeenCalledWith(
          'Satisfaction removed',
          expect.any(Function),
        )
      })

      it('provides undo callback that restores satisfaction', async () => {
        const { removeSatisfaction } = useRules()

        // Mock the API
        const { deleteRuleSatisfaction, createRuleSatisfaction, getRule } = await import('@/apis/rules.api')
        vi.mocked(deleteRuleSatisfaction).mockResolvedValueOnce({ data: {} })
        vi.mocked(createRuleSatisfaction).mockResolvedValueOnce({ data: {} })
        vi.mocked(getRule).mockResolvedValue({
          data: {
            id: 1,
            rule_id: '000001',
            version: 'V1R1',
            title: 'Test',
            status: 'Not Yet Determined',
            rule_severity: 'medium',
            locked: false,
            satisfies: [],
            satisfied_by: [],
          },
        })

        await removeSatisfaction(10, 20)

        // Get the undo callback that was passed to successWithUndo
        const undoCallback = mockToast.successWithUndo.mock.calls[0][1]

        // Execute the undo callback
        await undoCallback()

        // Verify satisfaction was restored via API
        expect(createRuleSatisfaction).toHaveBeenCalledWith(10, 20)
        expect(mockToast.success).toHaveBeenCalledWith('Satisfaction restored')
      })

      it('shows error toast on removal failure', async () => {
        const { removeSatisfaction } = useRules()

        const { deleteRuleSatisfaction } = await import('@/apis/rules.api')
        vi.mocked(deleteRuleSatisfaction).mockRejectedValueOnce(new Error('API Error'))

        const result = await removeSatisfaction(10, 20)

        expect(result).toBe(false)
        expect(mockToast.error).toHaveBeenCalledWith('Failed to remove satisfaction')
      })
    })

    describe('addSatisfaction', () => {
      it('shows success toast on successful add', async () => {
        const { addSatisfaction } = useRules()

        const { createRuleSatisfaction, getRule } = await import('@/apis/rules.api')
        vi.mocked(createRuleSatisfaction).mockResolvedValueOnce({ data: {} })
        vi.mocked(getRule).mockResolvedValue({
          data: {
            id: 1,
            rule_id: '000001',
            version: 'V1R1',
            title: 'Test',
            status: 'Not Yet Determined',
            rule_severity: 'medium',
            locked: false,
            satisfies: [{ id: 20, rule_id: '000020', title: 'Child' }],
            satisfied_by: [],
          },
        })

        const result = await addSatisfaction(10, 20)

        expect(result).toBe(true)
        expect(mockToast.success).toHaveBeenCalledWith('Requirements merged')
      })

      it('shows error toast on add failure', async () => {
        const { addSatisfaction } = useRules()

        const { createRuleSatisfaction } = await import('@/apis/rules.api')
        vi.mocked(createRuleSatisfaction).mockRejectedValueOnce(new Error('API Error'))

        const result = await addSatisfaction(10, 20)

        expect(result).toBe(false)
        expect(mockToast.error).toHaveBeenCalledWith('Failed to merge requirements')
      })
    })
  })

  describe('reset', () => {
    it('resets all state', () => {
      const { rules, showNestedRules, error, reset, toggleNestedRules } = useRules()

      // Set some state
      rules.value = [createSlimRule()]
      toggleNestedRules()
      error.value = 'some error'

      // Reset
      reset()

      expect(rules.value).toEqual([])
      expect(showNestedRules.value).toBe(true)
      expect(error.value).toBeNull()
    })
  })
})

// Re-export test for module exports
describe('useRules module exports', () => {
  it('exports constants directly', () => {
    expect(RULE_STATUSES).toBeDefined()
    expect(RULE_SEVERITIES).toBeDefined()
    expect(SEVERITY_MAP).toBeDefined()
  })
})
