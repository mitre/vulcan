import { describe, test, expect } from 'vitest'
import RuleForm from './RuleForm.vue'

describe('RuleForm', () => {
  function testComputed(computedName, props) {
    return RuleForm.computed[computedName].bind(props)
  }

  const mockRule = {
    id: 1,
    rule_id: '000001',
    status: 'Not Yet Determined',
    satisfied_by: [],
    satisfies: []
  }

  describe('status_text computed property', () => {
    test('returns rule status when no satisfied_by relationships', () => {
      const computed = testComputed('status_text', {
        rule: { ...mockRule, status: 'Not Yet Determined', satisfied_by: [] }
      })

      expect(computed()).toBe('Not Yet Determined')
    })

    test('returns Applicable - Configurable when satisfied_by exists', () => {
      const computed = testComputed('status_text', {
        rule: {
          ...mockRule,
          status: 'Not Yet Determined',
          satisfied_by: [{ id: 2 }]
        }
      })

      expect(computed()).toBe('Applicable - Configurable')
    })

    test('returns Applicable - Configurable when status is already AC and satisfied_by exists', () => {
      const computed = testComputed('status_text', {
        rule: {
          ...mockRule,
          status: 'Applicable - Configurable',
          satisfied_by: [{ id: 2 }]
        }
      })

      expect(computed()).toBe('Applicable - Configurable')
    })

    test('returns actual status when satisfied_by is empty array', () => {
      const computed = testComputed('status_text', {
        rule: { ...mockRule, status: 'Applicable - Inherently Meets', satisfied_by: [] }
      })

      expect(computed()).toBe('Applicable - Inherently Meets')
    })
  })
})
