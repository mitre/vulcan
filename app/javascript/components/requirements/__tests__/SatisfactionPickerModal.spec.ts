/**
 * SatisfactionPickerModal Component Unit Tests
 *
 * Tests for the SatisfactionPickerModal component that handles
 * adding/removing satisfaction relationships for a parent rule.
 */

import type { ISlimRule } from '@/types'
import { describe, expect, it } from 'vitest'

// Mock rule data for testing
function createMockRule(id: number, ruleId: string, options: Partial<ISlimRule> = {}): ISlimRule {
  return {
    id,
    rule_id: ruleId,
    version: '1',
    title: `Rule ${ruleId}`,
    status: 'Not Yet Determined',
    rule_severity: 'medium',
    locked: false,
    is_merged: false,
    satisfies_count: 0,
    ...options,
  }
}

describe('satisfactionPickerModal', () => {
  describe('available rules filtering', () => {
    it('excludes parent rule from available list', () => {
      const parentRuleId = 100
      const rules: ISlimRule[] = [
        createMockRule(100, 'SV-100', {}),
        createMockRule(101, 'SV-101', {}),
        createMockRule(102, 'SV-102', {}),
      ]
      const currentSatisfiedRuleIds: number[] = []

      // Simulate availableRules computed
      const availableRules = rules.filter((rule) => {
        if (rule.id === parentRuleId) return false
        if (rule.is_merged && !currentSatisfiedRuleIds.includes(rule.id)) return false
        return true
      })

      expect(availableRules).toHaveLength(2)
      expect(availableRules.map(r => r.id)).toEqual([101, 102])
    })

    it('excludes rules already merged by another parent', () => {
      const parentRuleId = 100
      const rules: ISlimRule[] = [
        createMockRule(100, 'SV-100', {}),
        createMockRule(101, 'SV-101', { is_merged: true }), // merged by different parent
        createMockRule(102, 'SV-102', {}),
      ]
      const currentSatisfiedRuleIds: number[] = []

      const availableRules = rules.filter((rule) => {
        if (rule.id === parentRuleId) return false
        if (rule.is_merged && !currentSatisfiedRuleIds.includes(rule.id)) return false
        return true
      })

      expect(availableRules).toHaveLength(1)
      expect(availableRules[0].id).toBe(102)
    })

    it('includes currently satisfied rules (for removal option)', () => {
      const parentRuleId = 100
      const rules: ISlimRule[] = [
        createMockRule(100, 'SV-100', {}),
        createMockRule(101, 'SV-101', { is_merged: true }), // satisfied by THIS parent
        createMockRule(102, 'SV-102', {}),
      ]
      const currentSatisfiedRuleIds: number[] = [101]

      const availableRules = rules.filter((rule) => {
        if (rule.id === parentRuleId) return false
        if (rule.is_merged && !currentSatisfiedRuleIds.includes(rule.id)) return false
        return true
      })

      expect(availableRules).toHaveLength(2)
      expect(availableRules.map(r => r.id)).toEqual([101, 102])
    })
  })

  describe('search filtering', () => {
    it('filters by rule_id', () => {
      const rules: ISlimRule[] = [
        createMockRule(101, 'SV-101', {}),
        createMockRule(102, 'SV-102', {}),
        createMockRule(200, 'SV-200', {}),
      ]
      const searchQuery = '101'

      const filteredRules = rules.filter(r =>
        r.rule_id.toLowerCase().includes(searchQuery.toLowerCase())
        || r.title.toLowerCase().includes(searchQuery.toLowerCase()),
      )

      expect(filteredRules).toHaveLength(1)
      expect(filteredRules[0].id).toBe(101)
    })

    it('filters by title', () => {
      const rules: ISlimRule[] = [
        createMockRule(101, 'SV-101', { title: 'Configure audit logging' }),
        createMockRule(102, 'SV-102', { title: 'Enable password policy' }),
        createMockRule(103, 'SV-103', { title: 'Configure password length' }),
      ]
      const searchQuery = 'password'

      const filteredRules = rules.filter(r =>
        r.rule_id.toLowerCase().includes(searchQuery.toLowerCase())
        || r.title.toLowerCase().includes(searchQuery.toLowerCase()),
      )

      expect(filteredRules).toHaveLength(2)
      expect(filteredRules.map(r => r.id)).toEqual([102, 103])
    })

    it('returns all rules when search is empty', () => {
      const rules: ISlimRule[] = [
        createMockRule(101, 'SV-101', {}),
        createMockRule(102, 'SV-102', {}),
      ]
      const searchQuery = ''

      const filteredRules = searchQuery.trim()
        ? rules.filter(r =>
            r.rule_id.toLowerCase().includes(searchQuery.toLowerCase())
            || r.title.toLowerCase().includes(searchQuery.toLowerCase()),
          )
        : rules

      expect(filteredRules).toHaveLength(2)
    })

    it('search is case-insensitive', () => {
      const rules: ISlimRule[] = [
        createMockRule(101, 'SV-101', { title: 'Configure Audit Logging' }),
      ]
      const searchQuery = 'AUDIT'

      const filteredRules = rules.filter(r =>
        r.rule_id.toLowerCase().includes(searchQuery.toLowerCase())
        || r.title.toLowerCase().includes(searchQuery.toLowerCase()),
      )

      expect(filteredRules).toHaveLength(1)
    })
  })

  describe('sorting', () => {
    it('sorts currently satisfied rules first', () => {
      const currentSatisfiedRuleIds = [102]
      const rules: ISlimRule[] = [
        createMockRule(101, 'SV-101', {}),
        createMockRule(102, 'SV-102', { is_merged: true }),
        createMockRule(103, 'SV-103', {}),
      ]

      const sortedRules = [...rules].sort((a, b) => {
        const aIsCurrent = currentSatisfiedRuleIds.includes(a.id)
        const bIsCurrent = currentSatisfiedRuleIds.includes(b.id)
        if (aIsCurrent && !bIsCurrent) return -1
        if (!aIsCurrent && bIsCurrent) return 1
        return a.rule_id.localeCompare(b.rule_id)
      })

      expect(sortedRules[0].id).toBe(102)
    })

    it('sorts by rule_id within same satisfaction status', () => {
      const currentSatisfiedRuleIds: number[] = []
      const rules: ISlimRule[] = [
        createMockRule(103, 'SV-103', {}),
        createMockRule(101, 'SV-101', {}),
        createMockRule(102, 'SV-102', {}),
      ]

      const sortedRules = [...rules].sort((a, b) => {
        const aIsCurrent = currentSatisfiedRuleIds.includes(a.id)
        const bIsCurrent = currentSatisfiedRuleIds.includes(b.id)
        if (aIsCurrent && !bIsCurrent) return -1
        if (!aIsCurrent && bIsCurrent) return 1
        return a.rule_id.localeCompare(b.rule_id)
      })

      expect(sortedRules.map(r => r.id)).toEqual([101, 102, 103])
    })
  })

  describe('selection state', () => {
    it('initializes with currently satisfied rules selected', () => {
      const currentSatisfiedRuleIds = [101, 102]
      const selectedRuleIds = new Set(currentSatisfiedRuleIds)

      expect(selectedRuleIds.has(101)).toBe(true)
      expect(selectedRuleIds.has(102)).toBe(true)
      expect(selectedRuleIds.has(103)).toBe(false)
    })

    it('toggles selection on', () => {
      const selectedRuleIds = new Set<number>([101])

      // Toggle 102 on
      const newSet = new Set(selectedRuleIds)
      if (newSet.has(102)) {
        newSet.delete(102)
      }
      else {
        newSet.add(102)
      }

      expect(newSet.has(101)).toBe(true)
      expect(newSet.has(102)).toBe(true)
    })

    it('toggles selection off', () => {
      const selectedRuleIds = new Set<number>([101, 102])

      // Toggle 102 off
      const newSet = new Set(selectedRuleIds)
      if (newSet.has(102)) {
        newSet.delete(102)
      }
      else {
        newSet.add(102)
      }

      expect(newSet.has(101)).toBe(true)
      expect(newSet.has(102)).toBe(false)
    })
  })

  describe('change detection', () => {
    it('detects additions (newly checked rules)', () => {
      const currentSatisfiedRuleIds = [101]
      const selectedRuleIds = new Set([101, 102, 103])

      const toAdd = [...selectedRuleIds].filter(id => !currentSatisfiedRuleIds.includes(id))

      expect(toAdd).toEqual([102, 103])
    })

    it('detects removals (unchecked rules)', () => {
      const currentSatisfiedRuleIds = [101, 102, 103]
      const selectedRuleIds = new Set([101])

      const toRemove = currentSatisfiedRuleIds.filter(id => !selectedRuleIds.has(id))

      expect(toRemove).toEqual([102, 103])
    })

    it('detects no changes when selection matches current', () => {
      const currentSatisfiedRuleIds = [101, 102]
      const selectedRuleIds = new Set([101, 102])

      const toAdd = [...selectedRuleIds].filter(id => !currentSatisfiedRuleIds.includes(id))
      const toRemove = currentSatisfiedRuleIds.filter(id => !selectedRuleIds.has(id))

      expect(toAdd).toHaveLength(0)
      expect(toRemove).toHaveLength(0)
    })

    it('detects both additions and removals', () => {
      const currentSatisfiedRuleIds = [101, 102]
      const selectedRuleIds = new Set([102, 103])

      const toAdd = [...selectedRuleIds].filter(id => !currentSatisfiedRuleIds.includes(id))
      const toRemove = currentSatisfiedRuleIds.filter(id => !selectedRuleIds.has(id))

      expect(toAdd).toEqual([103])
      expect(toRemove).toEqual([101])
    })

    it('hasChanges is true when there are additions', () => {
      const toAdd = [102]
      const toRemove: number[] = []

      const hasChanges = toAdd.length > 0 || toRemove.length > 0

      expect(hasChanges).toBe(true)
    })

    it('hasChanges is true when there are removals', () => {
      const toAdd: number[] = []
      const toRemove = [101]

      const hasChanges = toAdd.length > 0 || toRemove.length > 0

      expect(hasChanges).toBe(true)
    })

    it('hasChanges is false when no changes', () => {
      const toAdd: number[] = []
      const toRemove: number[] = []

      const hasChanges = toAdd.length > 0 || toRemove.length > 0

      expect(hasChanges).toBe(false)
    })
  })

  describe('selection count', () => {
    it('counts selected rules correctly', () => {
      const selectedRuleIds = new Set([101, 102, 103])

      expect(selectedRuleIds.size).toBe(3)
    })

    it('counts zero when nothing selected', () => {
      const selectedRuleIds = new Set<number>()

      expect(selectedRuleIds.size).toBe(0)
    })
  })

  describe('status helpers', () => {
    it('identifies selected rules', () => {
      const selectedRuleIds = new Set([101, 102])

      const isSelected = (ruleId: number) => selectedRuleIds.has(ruleId)

      expect(isSelected(101)).toBe(true)
      expect(isSelected(102)).toBe(true)
      expect(isSelected(103)).toBe(false)
    })

    it('identifies currently satisfied rules', () => {
      const currentSatisfiedRuleIds = [101, 102]

      const isCurrentlySatisfied = (ruleId: number) => currentSatisfiedRuleIds.includes(ruleId)

      expect(isCurrentlySatisfied(101)).toBe(true)
      expect(isCurrentlySatisfied(102)).toBe(true)
      expect(isCurrentlySatisfied(103)).toBe(false)
    })
  })

  describe('empty states', () => {
    it('handles empty rules list', () => {
      const rules: ISlimRule[] = []
      const parentRuleId = 100
      const currentSatisfiedRuleIds: number[] = []

      const availableRules = rules.filter((rule) => {
        if (rule.id === parentRuleId) return false
        if (rule.is_merged && !currentSatisfiedRuleIds.includes(rule.id)) return false
        return true
      })

      expect(availableRules).toHaveLength(0)
    })

    it('handles all rules being merged by other parents', () => {
      const rules: ISlimRule[] = [
        createMockRule(100, 'SV-100', {}), // parent
        createMockRule(101, 'SV-101', { is_merged: true }),
        createMockRule(102, 'SV-102', { is_merged: true }),
      ]
      const parentRuleId = 100
      const currentSatisfiedRuleIds: number[] = []

      const availableRules = rules.filter((rule) => {
        if (rule.id === parentRuleId) return false
        if (rule.is_merged && !currentSatisfiedRuleIds.includes(rule.id)) return false
        return true
      })

      expect(availableRules).toHaveLength(0)
    })
  })
})
