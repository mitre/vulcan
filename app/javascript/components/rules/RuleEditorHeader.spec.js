import { describe, expect, it } from 'vitest'
import RuleEditorHeader from './RuleEditorHeader.vue'

describe('ruleEditorHeader', () => {
  function testComputed(computedName, props) {
    return RuleEditorHeader.computed[computedName].bind(props)
  }

  describe('filteredSelectRulesForCheckbox computed property', () => {
    it('returns all rules when search is empty', () => {
      const computed = testComputed('filteredSelectRulesForCheckbox', {
        satisfiesSearchText: '',
        filteredSelectRules: [
          { value: 1, text: 'GPOS-000001' },
          { value: 2, text: 'GPOS-000002' },
        ],
      })

      const result = computed()
      expect(result.length).toBe(2)
    })

    it('filters rules by search text', () => {
      const computed = testComputed('filteredSelectRulesForCheckbox', {
        satisfiesSearchText: '000002',
        filteredSelectRules: [
          { value: 1, text: 'GPOS-000001' },
          { value: 2, text: 'GPOS-000002' },
          { value: 3, text: 'GPOS-000003' },
        ],
      })

      const result = computed()
      expect(result.length).toBe(1)
      expect(result[0].text).toBe('GPOS-000002')
    })

    it('search is case insensitive', () => {
      const computed = testComputed('filteredSelectRulesForCheckbox', {
        satisfiesSearchText: 'gpos',
        filteredSelectRules: [
          { value: 1, text: 'GPOS-000001' },
          { value: 2, text: 'RHEL-000002' },
        ],
      })

      const result = computed()
      expect(result.length).toBe(1)
      expect(result[0].text).toBe('GPOS-000001')
    })
  })
})
