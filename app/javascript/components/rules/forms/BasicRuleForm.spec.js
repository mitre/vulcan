import { describe, expect, it } from 'vitest'
import BasicRuleForm from './BasicRuleForm.vue'

describe('basicRuleForm', () => {
  // Test computed properties directly without mounting
  // This follows the Habitica pattern for testing Vue 2 components
  function testComputed(computedName, props) {
    return BasicRuleForm.computed[computedName].bind(props)
  }

  const mockRule = {
    id: 1,
    rule_id: '000001',
    status: 'Not Yet Determined',
    satisfied_by: [],
    satisfies: [],
    locked: false,
    review_requestor_id: null,
  }

  describe('checkFormFields computed property', () => {
    it('shows check fields when status is Applicable - Configurable', () => {
      const computed = testComputed('checkFormFields', {
        rule: { ...mockRule, status: 'Applicable - Configurable', satisfied_by: [] },
      })

      const result = computed()
      expect(result.displayed).toContain('content')
    })

    it('shows check fields when rule has satisfied_by relationships', () => {
      const computed = testComputed('checkFormFields', {
        rule: {
          ...mockRule,
          status: 'Not Yet Determined',
          satisfied_by: [{ id: 2 }],
        },
      })

      const result = computed()
      expect(result.displayed).toContain('content')
    })

    it('hides check fields when status is Not Yet Determined and no satisfied_by', () => {
      const computed = testComputed('checkFormFields', {
        rule: { ...mockRule, status: 'Not Yet Determined', satisfied_by: [] },
      })

      const result = computed()
      expect(result.displayed).not.toContain('content')
    })
  })

  describe('disaDescriptionFormFields computed property', () => {
    it('shows vuln_discussion when status is Applicable - Configurable', () => {
      const computed = testComputed('disaDescriptionFormFields', {
        rule: { ...mockRule, status: 'Applicable - Configurable', satisfied_by: [] },
      })

      const result = computed()
      expect(result.displayed).toContain('vuln_discussion')
    })

    it('shows vuln_discussion when rule has satisfied_by relationships', () => {
      const computed = testComputed('disaDescriptionFormFields', {
        rule: {
          ...mockRule,
          status: 'Not Yet Determined',
          satisfied_by: [{ id: 2 }],
        },
      })

      const result = computed()
      expect(result.displayed).toContain('vuln_discussion')
    })

    it('shows vuln_discussion as disabled for Not Yet Determined without satisfied_by', () => {
      const computed = testComputed('disaDescriptionFormFields', {
        rule: { ...mockRule, status: 'Not Yet Determined', satisfied_by: [] },
      })

      const result = computed()
      expect(result.displayed).toContain('vuln_discussion')
      expect(result.disabled).toContain('vuln_discussion')
    })

    it('shows mitigation fields when status is Applicable - Does Not Meet', () => {
      const computed = testComputed('disaDescriptionFormFields', {
        rule: { ...mockRule, status: 'Applicable - Does Not Meet', satisfied_by: [] },
      })

      const result = computed()
      expect(result.displayed).toContain('mitigations_available')
      expect(result.displayed).toContain('mitigations')
    })
  })
})
