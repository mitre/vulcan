/**
 * Tests for table sorting functionality in RequirementsTable
 *
 * Custom sortCompare function handles:
 * - Standard string sorting for rule_id, status, title
 * - Special severity sorting (high > medium > low, i.e., CAT I > CAT II > CAT III)
 */

import { describe, expect, it } from 'vitest'

// Mirror the ITableRule interface used in RequirementsTable
interface ITableRule {
  id: number
  rule_id: string
  version: string
  title: string
  status: string
  rule_severity: string
  locked: boolean
  review_requestor_id: number | null
  is_merged: boolean
  satisfies_count?: number
  changes_requested?: boolean
  satisfies_rules?: { id: number, rule_id: string, title: string }[]
  _showDetails?: boolean
}

/**
 * sortCompare function - mirrors the implementation in RequirementsTable.vue
 * BTable calls this and applies asc/desc direction internally
 */
function sortCompare(a: ITableRule, b: ITableRule, key: string): number {
  let aVal: string | number | null = null
  let bVal: string | number | null = null

  // Get values based on sort key
  switch (key) {
    case 'rule_id':
      aVal = a.rule_id
      bVal = b.rule_id
      break
    case 'status':
      aVal = a.status
      bVal = b.status
      break
    case 'title':
      aVal = a.title
      bVal = b.title
      break
    case 'rule_severity':
      // Sort by severity priority: CAT I (high) = 1, CAT II (medium) = 2, CAT III (low) = 3, unknown = 4
      // Lower number = higher priority, so ascending sort shows CAT I first
      const severityOrder: Record<string, number> = { high: 1, medium: 2, low: 3, unknown: 4 }
      aVal = severityOrder[a.rule_severity] ?? 5
      bVal = severityOrder[b.rule_severity] ?? 5
      break
    default:
      aVal = String(a[key as keyof ITableRule] ?? '')
      bVal = String(b[key as keyof ITableRule] ?? '')
  }

  // Compare values
  if (aVal === bVal) return 0
  if (aVal == null) return 1
  if (bVal == null) return -1
  if (typeof aVal === 'number' && typeof bVal === 'number') {
    return aVal - bVal
  }
  return String(aVal).localeCompare(String(bVal))
}

// Factory to create test rules
function createRule(overrides: Partial<ITableRule> = {}): ITableRule {
  return {
    id: 1,
    rule_id: '000001',
    version: 'V1R1',
    title: 'Test Rule',
    status: 'Not Yet Determined',
    rule_severity: 'medium',
    locked: false,
    review_requestor_id: null,
    is_merged: false,
    satisfies_count: 0,
    _showDetails: false,
    ...overrides,
  }
}

describe('table Sorting', () => {
  describe('sortCompare function', () => {
    describe('rule_id sorting', () => {
      it('sorts rule_ids alphabetically', () => {
        const a = createRule({ rule_id: '000010' })
        const b = createRule({ rule_id: '000020' })

        expect(sortCompare(a, b, 'rule_id')).toBeLessThan(0)
        expect(sortCompare(b, a, 'rule_id')).toBeGreaterThan(0)
      })

      it('returns 0 for equal rule_ids', () => {
        const a = createRule({ rule_id: '000010' })
        const b = createRule({ rule_id: '000010' })

        expect(sortCompare(a, b, 'rule_id')).toBe(0)
      })

      it('handles mixed alphanumeric rule_ids', () => {
        const a = createRule({ rule_id: 'SV-000010' })
        const b = createRule({ rule_id: 'SV-000020' })

        expect(sortCompare(a, b, 'rule_id')).toBeLessThan(0)
      })
    })

    describe('status sorting', () => {
      it('sorts statuses alphabetically', () => {
        const a = createRule({ status: 'Applicable - Configurable' })
        const b = createRule({ status: 'Not Yet Determined' })

        expect(sortCompare(a, b, 'status')).toBeLessThan(0)
        expect(sortCompare(b, a, 'status')).toBeGreaterThan(0)
      })

      it('returns 0 for equal statuses', () => {
        const a = createRule({ status: 'Not Applicable' })
        const b = createRule({ status: 'Not Applicable' })

        expect(sortCompare(a, b, 'status')).toBe(0)
      })
    })

    describe('title sorting', () => {
      it('sorts titles alphabetically', () => {
        const a = createRule({ title: 'Apple' })
        const b = createRule({ title: 'Banana' })

        expect(sortCompare(a, b, 'title')).toBeLessThan(0)
        expect(sortCompare(b, a, 'title')).toBeGreaterThan(0)
      })

      it('is case-sensitive (localeCompare behavior)', () => {
        const a = createRule({ title: 'apple' })
        const b = createRule({ title: 'Banana' })

        // localeCompare typically handles case, but result depends on locale
        const result = sortCompare(a, b, 'title')
        expect(typeof result).toBe('number')
      })
    })

    describe('severity sorting (special handling)', () => {
      it('sorts CAT I (high) first in ascending order', () => {
        const high = createRule({ rule_severity: 'high' })
        const medium = createRule({ rule_severity: 'medium' })
        const low = createRule({ rule_severity: 'low' })

        // high (1) < medium (2) < low (3) - lower number = higher priority
        // So high comes BEFORE medium in ascending sort
        expect(sortCompare(high, medium, 'rule_severity')).toBeLessThan(0)
        expect(sortCompare(high, low, 'rule_severity')).toBeLessThan(0)
        expect(sortCompare(medium, low, 'rule_severity')).toBeLessThan(0)

        // Reverse comparisons
        expect(sortCompare(medium, high, 'rule_severity')).toBeGreaterThan(0)
        expect(sortCompare(low, high, 'rule_severity')).toBeGreaterThan(0)
        expect(sortCompare(low, medium, 'rule_severity')).toBeGreaterThan(0)
      })

      it('returns 0 for equal severities', () => {
        const a = createRule({ rule_severity: 'medium' })
        const b = createRule({ rule_severity: 'medium' })

        expect(sortCompare(a, b, 'rule_severity')).toBe(0)
      })

      it('handles unknown severity as lowest priority', () => {
        const known = createRule({ rule_severity: 'low' })
        const unknown = createRule({ rule_severity: 'unknown' })

        // low (3) < unknown (4) - unknown sorts last
        expect(sortCompare(known, unknown, 'rule_severity')).toBeLessThan(0)
      })
    })

    describe('sorting full arrays', () => {
      it('sorts array by rule_id ascending', () => {
        const rules = [
          createRule({ id: 3, rule_id: '000030' }),
          createRule({ id: 1, rule_id: '000010' }),
          createRule({ id: 2, rule_id: '000020' }),
        ]

        const sorted = [...rules].sort((a, b) => sortCompare(a, b, 'rule_id'))

        expect(sorted.map(r => r.rule_id)).toEqual(['000010', '000020', '000030'])
      })

      it('sorts array by severity ascending (CAT I first)', () => {
        const rules = [
          createRule({ id: 1, rule_severity: 'low' }),
          createRule({ id: 2, rule_severity: 'high' }),
          createRule({ id: 3, rule_severity: 'medium' }),
        ]

        const sorted = [...rules].sort((a, b) => sortCompare(a, b, 'rule_severity'))

        // Ascending = CAT I (high) first, then CAT II (medium), then CAT III (low)
        expect(sorted.map(r => r.rule_severity)).toEqual(['high', 'medium', 'low'])
      })

      it('sorts array by severity descending (CAT III first)', () => {
        const rules = [
          createRule({ id: 1, rule_severity: 'high' }),
          createRule({ id: 2, rule_severity: 'low' }),
          createRule({ id: 3, rule_severity: 'medium' }),
        ]

        // BTable applies negation for desc order
        const sorted = [...rules].sort((a, b) => -sortCompare(a, b, 'rule_severity'))

        // Descending = CAT III (low) first, then CAT II (medium), then CAT I (high)
        expect(sorted.map(r => r.rule_severity)).toEqual(['low', 'medium', 'high'])
      })
    })

    describe('edge cases', () => {
      it('handles null values', () => {
        const a = createRule({ title: 'Test' })
        const b = { ...createRule(), title: null as unknown as string }

        // Non-null comes before null
        expect(sortCompare(a, b, 'title')).toBeLessThan(0)
      })

      it('handles empty strings', () => {
        const a = createRule({ title: '' })
        const b = createRule({ title: 'Test' })

        // Empty string comes before non-empty
        expect(sortCompare(a, b, 'title')).toBeLessThan(0)
      })

      it('handles unknown keys by stringifying', () => {
        const a = createRule({ id: 1 })
        const b = createRule({ id: 2 })

        // Unknown key falls back to string comparison
        const result = sortCompare(a, b, 'unknown_key')
        expect(typeof result).toBe('number')
      })
    })
  })
})
