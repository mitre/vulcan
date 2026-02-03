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

  describe('autoSelectFirst option', () => {
    it('does not auto-select when autoSelectFirst is false (default)', () => {
      const { selectedRuleId } = useRuleSelection(mockRules, componentId)
      expect(selectedRuleId.value).toBeNull()
    })

    it('auto-selects first rule when autoSelectFirst is true', () => {
      const { selectedRuleId, selectedRule } = useRuleSelection(mockRules, componentId, { autoSelectFirst: true })
      expect(selectedRuleId.value).toBe(1)
      expect(selectedRule.value).toEqual(mockRules.value[0])
    })

    it('does not override existing selection from localStorage', () => {
      localStorage.setItem(`selectedRuleId-${componentId}`, JSON.stringify(2))
      const { selectedRuleId } = useRuleSelection(mockRules, componentId, { autoSelectFirst: true })
      expect(selectedRuleId.value).toBe(2)
    })

    it('does not auto-select when rules array is empty', () => {
      const emptyRules = ref([])
      const { selectedRuleId } = useRuleSelection(emptyRules, componentId, { autoSelectFirst: true })
      expect(selectedRuleId.value).toBeNull()
    })

    it('adds first rule to openRuleIds when auto-selecting', () => {
      const { openRuleIds } = useRuleSelection(mockRules, componentId, { autoSelectFirst: true })
      expect(openRuleIds.value).toContain(1)
    })
  })

  describe('autoSelectFirst with nested rules (satisfies/satisfied_by)', () => {
    // Rules with nesting relationships:
    // - PARENT: has satisfies (children nested under it)
    // - CHILD: has satisfied_by (hidden when nesting enabled)
    // - STANDALONE: no relationships (always visible)
    //
    // When nesting is enabled, display order is: Parents first, then Standalone leaves
    // Children are hidden from main list (shown nested under parent)
    //
    // Auto-select should pick the first VISIBLE rule:
    // 1. First parent (if any)
    // 2. Else first standalone
    // 3. Never pick a child (it would be hidden)

    const nestedRules = ref([
      {
        id: 1,
        rule_id: '000001',
        satisfies: [],
        satisfied_by: [{ id: 10 }], // CHILD - nested under rule 10
        histories: []
      },
      {
        id: 2,
        rule_id: '000002',
        satisfies: [],
        satisfied_by: [{ id: 10 }], // CHILD - nested under rule 10
        histories: []
      },
      {
        id: 3,
        rule_id: '000003',
        satisfies: [],
        satisfied_by: [], // STANDALONE
        histories: []
      },
      {
        id: 10,
        rule_id: '000010',
        satisfies: [{ id: 1 }, { id: 2 }], // PARENT - has 2 children
        satisfied_by: [],
        histories: []
      },
      {
        id: 11,
        rule_id: '000011',
        satisfies: [],
        satisfied_by: [], // STANDALONE
        histories: []
      }
    ])

    it('selects first parent rule when parents exist (not first by rule_id)', () => {
      // Rule 000001 is first by rule_id but it's a CHILD (hidden in tree view)
      // Rule 000010 is a PARENT and should be selected first
      const { selectedRuleId } = useRuleSelection(nestedRules, componentId, { autoSelectFirst: true })
      expect(selectedRuleId.value).toBe(10) // Parent, not child 000001
    })

    it('selects first standalone when no parents exist', () => {
      const standaloneOnlyRules = ref([
        {
          id: 1,
          rule_id: '000001',
          satisfies: [],
          satisfied_by: [{ id: 99 }], // CHILD (parent not in list)
          histories: []
        },
        {
          id: 2,
          rule_id: '000002',
          satisfies: [],
          satisfied_by: [], // STANDALONE
          histories: []
        },
        {
          id: 3,
          rule_id: '000003',
          satisfies: [],
          satisfied_by: [], // STANDALONE
          histories: []
        }
      ])
      const { selectedRuleId } = useRuleSelection(standaloneOnlyRules, componentId, { autoSelectFirst: true })
      expect(selectedRuleId.value).toBe(2) // First standalone, not child
    })

    it('never selects a child rule (satisfied_by) as first', () => {
      const childFirstRules = ref([
        {
          id: 1,
          rule_id: '000001',
          satisfies: [],
          satisfied_by: [{ id: 10 }], // CHILD
          histories: []
        },
        {
          id: 2,
          rule_id: '000002',
          satisfies: [],
          satisfied_by: [{ id: 10 }], // CHILD
          histories: []
        },
        {
          id: 10,
          rule_id: '000010',
          satisfies: [{ id: 1 }, { id: 2 }], // PARENT
          satisfied_by: [],
          histories: []
        }
      ])
      const { selectedRuleId } = useRuleSelection(childFirstRules, componentId, { autoSelectFirst: true })
      // Should select parent (10), not first child (1)
      expect(selectedRuleId.value).toBe(10)
    })

    it('falls back to first rule if all rules are children (edge case)', () => {
      const allChildrenRules = ref([
        {
          id: 1,
          rule_id: '000001',
          satisfies: [],
          satisfied_by: [{ id: 99 }], // CHILD (parent not in list)
          histories: []
        },
        {
          id: 2,
          rule_id: '000002',
          satisfies: [],
          satisfied_by: [{ id: 99 }], // CHILD
          histories: []
        }
      ])
      const { selectedRuleId } = useRuleSelection(allChildrenRules, componentId, { autoSelectFirst: true })
      // Fallback to first rule when no parents or standalone exist
      expect(selectedRuleId.value).toBe(1)
    })

    it('handles rules without satisfies/satisfied_by properties (backwards compatibility)', () => {
      // Original mockRules don't have these properties - should still work
      const { selectedRuleId } = useRuleSelection(mockRules, componentId, { autoSelectFirst: true })
      expect(selectedRuleId.value).toBe(1) // First rule as before
    })

    it('sorts by rule_id before selecting (handles unsorted arrays)', () => {
      // Array is NOT in rule_id order - simulates real database order
      const unsortedRules = ref([
        {
          id: 50,
          rule_id: '000050',
          satisfies: [],
          satisfied_by: [], // STANDALONE but not first by rule_id
          histories: []
        },
        {
          id: 10,
          rule_id: '000010',
          satisfies: [],
          satisfied_by: [], // STANDALONE - should be selected (first by rule_id)
          histories: []
        },
        {
          id: 30,
          rule_id: '000030',
          satisfies: [],
          satisfied_by: [], // STANDALONE
          histories: []
        }
      ])
      const { selectedRuleId } = useRuleSelection(unsortedRules, componentId, { autoSelectFirst: true })
      // Should select rule_id 000010 (id: 10), not 000050 (id: 50) which is first in array
      expect(selectedRuleId.value).toBe(10)
    })

    it('sorts parents by rule_id when selecting first parent', () => {
      // Parents not in rule_id order
      const unsortedParentRules = ref([
        {
          id: 20,
          rule_id: '000020',
          satisfies: [{ id: 1 }], // PARENT but not first by rule_id
          satisfied_by: [],
          histories: []
        },
        {
          id: 5,
          rule_id: '000005',
          satisfies: [{ id: 2 }], // PARENT - should be selected (first parent by rule_id)
          satisfied_by: [],
          histories: []
        },
        {
          id: 1,
          rule_id: '000001',
          satisfies: [],
          satisfied_by: [{ id: 20 }], // CHILD
          histories: []
        }
      ])
      const { selectedRuleId } = useRuleSelection(unsortedParentRules, componentId, { autoSelectFirst: true })
      // Should select parent with rule_id 000005 (id: 5), not 000020 (id: 20)
      expect(selectedRuleId.value).toBe(5)
    })
  })
})
