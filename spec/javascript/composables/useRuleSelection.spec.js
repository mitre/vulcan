import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { ref } from 'vue'
import { useRuleSelection } from '@/composables/useRuleSelection'

describe('useRuleSelection', () => {
  const mockRules = ref([
    {
      id: 1,
      rule_id: 'CNTR-00-000010',
      histories: [{ name: 'User One' }, { name: 'User Two' }]
    },
    {
      id: 2,
      rule_id: 'CNTR-00-000020',
      histories: []
    },
    {
      id: 3,
      rule_id: 'CNTR-00-000030',
      histories: [{ name: 'User Three' }]
    }
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
    it('initializes with null selectedRuleId', () => {
      const { selectedRuleId } = useRuleSelection(mockRules, componentId)
      expect(selectedRuleId.value).toBeNull()
    })

    it('initializes with empty openRuleIds', () => {
      const { openRuleIds } = useRuleSelection(mockRules, componentId)
      expect(openRuleIds.value).toEqual([])
    })

    it('restores selectedRuleId from localStorage', () => {
      localStorage.setItem(`selectedRuleId-${componentId}`, JSON.stringify(2))
      const { selectedRuleId } = useRuleSelection(mockRules, componentId)
      expect(selectedRuleId.value).toBe(2)
    })

    it('restores openRuleIds from localStorage', () => {
      localStorage.setItem('openRuleIds', JSON.stringify([1, 2]))
      const { openRuleIds } = useRuleSelection(mockRules, componentId)
      expect(openRuleIds.value).toEqual([1, 2])
    })

    it('handles invalid localStorage data gracefully', () => {
      localStorage.setItem(`selectedRuleId-${componentId}`, 'invalid json')
      const { selectedRuleId } = useRuleSelection(mockRules, componentId)
      expect(selectedRuleId.value).toBeNull()
    })
  })

  describe('selectedRule', () => {
    it('returns the selected rule when found', () => {
      const { selectedRuleId, selectedRule } = useRuleSelection(mockRules, componentId)
      selectedRuleId.value = 1
      expect(selectedRule.value).toEqual(mockRules.value[0])
    })

    it('returns null when no rule is selected', () => {
      const { selectedRule } = useRuleSelection(mockRules, componentId)
      expect(selectedRule.value).toBeNull()
    })

    it('returns null and resets selectedRuleId when rule not found', () => {
      const { selectedRuleId, selectedRule } = useRuleSelection(mockRules, componentId)
      selectedRuleId.value = 999 // non-existent
      expect(selectedRule.value).toBeNull()
      expect(selectedRuleId.value).toBeNull()
    })
  })

  describe('lastEditor', () => {
    it('returns the last editor name from histories', () => {
      const { selectedRuleId, lastEditor } = useRuleSelection(mockRules, componentId)
      selectedRuleId.value = 1
      expect(lastEditor.value).toBe('User Two')
    })

    it('returns "Unknown User" when histories is empty', () => {
      const { selectedRuleId, lastEditor } = useRuleSelection(mockRules, componentId)
      selectedRuleId.value = 2
      expect(lastEditor.value).toBe('Unknown User')
    })

    it('returns "Unknown User" when no rule is selected', () => {
      const { lastEditor } = useRuleSelection(mockRules, componentId)
      expect(lastEditor.value).toBe('Unknown User')
    })
  })

  describe('selectRule', () => {
    it('sets the selectedRuleId', () => {
      const { selectedRuleId, selectRule } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      expect(selectedRuleId.value).toBe(2)
    })

    it('adds the rule to openRuleIds', () => {
      const { openRuleIds, selectRule } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      expect(openRuleIds.value).toContain(2)
    })

    it('does not duplicate rule in openRuleIds', () => {
      const { openRuleIds, selectRule } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      selectRule(2)
      expect(openRuleIds.value.filter(id => id === 2).length).toBe(1)
    })

    it('persists selectedRuleId to localStorage', () => {
      const { selectRule } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      expect(localStorage.getItem(`selectedRuleId-${componentId}`)).toBe('2')
    })

    it('persists openRuleIds to localStorage', () => {
      const { selectRule } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      expect(JSON.parse(localStorage.getItem('openRuleIds'))).toContain(2)
    })
  })

  describe('deselectRule', () => {
    it('removes the rule from openRuleIds', () => {
      const { openRuleIds, selectRule, deselectRule } = useRuleSelection(mockRules, componentId)
      selectRule(1)
      selectRule(2)
      deselectRule(1)
      expect(openRuleIds.value).not.toContain(1)
      expect(openRuleIds.value).toContain(2)
    })

    it('clears selectedRuleId when deselecting current rule', () => {
      const { selectedRuleId, selectRule, deselectRule } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      deselectRule(2)
      expect(selectedRuleId.value).toBeNull()
    })

    it('does nothing when deselecting a non-open rule', () => {
      const { openRuleIds, deselectRule } = useRuleSelection(mockRules, componentId)
      deselectRule(999)
      expect(openRuleIds.value).toEqual([])
    })
  })

  describe('closeAllRules', () => {
    it('clears all open rules', () => {
      const { openRuleIds, selectRule, closeAllRules } = useRuleSelection(mockRules, componentId)
      selectRule(1)
      selectRule(2)
      selectRule(3)
      closeAllRules()
      expect(openRuleIds.value).toEqual([])
    })

    it('clears selectedRuleId', () => {
      const { selectedRuleId, selectRule, closeAllRules } = useRuleSelection(mockRules, componentId)
      selectRule(1)
      closeAllRules()
      expect(selectedRuleId.value).toBeNull()
    })
  })

  describe('isRuleOpen', () => {
    it('returns true for open rules', () => {
      const { selectRule, isRuleOpen } = useRuleSelection(mockRules, componentId)
      selectRule(2)
      expect(isRuleOpen(2)).toBe(true)
    })

    it('returns false for closed rules', () => {
      const { isRuleOpen } = useRuleSelection(mockRules, componentId)
      expect(isRuleOpen(2)).toBe(false)
    })
  })
})
