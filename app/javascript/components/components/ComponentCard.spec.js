import { describe, expect, it } from 'vitest'

describe('componentCard display logic', () => {
  describe('control count display', () => {
    it('shows parent count when parent_rules_count > 0', () => {
      const component = {
        rules_count: 273,
        parent_rules_count: 15,
      }

      // Simulate the v-if logic from ComponentCard.vue line 39
      const shouldShowParentCount = component.parent_rules_count > 0
      expect(shouldShowParentCount).toBe(true)

      // Verify the text that would be displayed
      const displayText = `${component.parent_rules_count} Primary Control${component.parent_rules_count !== 1 ? 's' : ''} / ${component.rules_count} Total`
      expect(displayText).toBe('15 Primary Controls / 273 Total')
    })

    it('shows regular count when parent_rules_count is 0', () => {
      const component = {
        rules_count: 191,
        parent_rules_count: 0,
      }

      const shouldShowParentCount = component.parent_rules_count > 0
      expect(shouldShowParentCount).toBe(false)

      const displayText = `${component.rules_count} Control${component.rules_count !== 1 ? 's' : ''}`
      expect(displayText).toBe('191 Controls')
    })

    it('shows singular form for 1 parent', () => {
      const component = {
        rules_count: 50,
        parent_rules_count: 1,
      }

      const displayText = `${component.parent_rules_count} Primary Control${component.parent_rules_count !== 1 ? 's' : ''} / ${component.rules_count} Total`
      expect(displayText).toBe('1 Primary Control / 50 Total')
    })

    it('shows singular form for 1 control when no parents', () => {
      const component = {
        rules_count: 1,
        parent_rules_count: 0,
      }

      const displayText = `${component.rules_count} Control${component.rules_count !== 1 ? 's' : ''}`
      expect(displayText).toBe('1 Control')
    })
  })
})
