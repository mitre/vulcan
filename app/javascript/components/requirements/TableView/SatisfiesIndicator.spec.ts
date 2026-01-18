import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import SatisfiesIndicator from './SatisfiesIndicator.vue'

describe('satisfiesIndicator', () => {
  describe('no relationships', () => {
    it('shows dash when no satisfaction relationships', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {},
      })

      expect(wrapper.text()).toBe('—')
    })

    it('shows dash when explicitly no relationships', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 0,
          isMerged: false,
        },
      })

      expect(wrapper.text()).toBe('—')
    })

    it('shows dash for merged rules (child indicator moved to ID column)', () => {
      // The ← indicator for child rules is now rendered in RequirementsTable ID column
      // SatisfiesIndicator only shows →N for parent rules
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 0,
          isMerged: true,
        },
      })

      expect(wrapper.text()).toBe('—')
    })
  })

  describe('satisfies others (parent rules)', () => {
    it('shows outgoing arrow with count', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 3,
        },
      })

      expect(wrapper.text()).toContain('3')
      expect(wrapper.find('.bi-arrow-right').exists()).toBe(true)
      expect(wrapper.find('.satisfies-badge').exists()).toBe(true)
    })

    it('shows correct count for single rule', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 1,
        },
      })

      expect(wrapper.text()).toContain('1')
    })

    it('has correct tooltip for plural', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 5,
          actionsEnabled: true,
        },
      })

      const badge = wrapper.find('.satisfies-badge')
      expect(badge.attributes('title')).toContain('5 requirements')
      expect(badge.attributes('title')).toContain('click to manage')
    })

    it('has correct tooltip for singular', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 1,
          actionsEnabled: true,
        },
      })

      const badge = wrapper.find('.satisfies-badge')
      expect(badge.attributes('title')).toContain('1 requirement')
      expect(badge.attributes('title')).not.toContain('requirements')
    })

    it('applies info color class', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 2,
        },
      })

      expect(wrapper.find('.satisfies-badge').classes()).toContain('text-info')
    })

    it('handles large counts', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 99,
        },
      })

      expect(wrapper.text()).toContain('99')
    })
  })

  describe('edge cases', () => {
    it('handles undefined satisfiesCount', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: undefined,
          isMerged: false,
        },
      })

      expect(wrapper.text()).toBe('—')
    })

    it('treats 0 satisfiesCount as no relationship', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          satisfiesCount: 0,
        },
      })

      expect(wrapper.find('.satisfies-badge').exists()).toBe(false)
      expect(wrapper.text()).toBe('—')
    })
  })

  describe('clickable behavior', () => {
    it('has clickable class when actions enabled', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: true,
        },
      })

      const badge = wrapper.find('.satisfies-badge')
      expect(badge.classes()).toContain('clickable')
    })

    it('does not have clickable class when actions disabled', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: false,
        },
      })

      const badge = wrapper.find('.satisfies-badge')
      expect(badge.classes()).not.toContain('clickable')
    })

    it('has role="button" for accessibility when actions enabled', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: true,
        },
      })

      const badge = wrapper.find('.satisfies-badge')
      expect(badge.attributes('role')).toBe('button')
      expect(badge.attributes('tabindex')).toBe('0')
    })

    it('has no role/tabindex when actions disabled', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: false,
        },
      })

      const badge = wrapper.find('.satisfies-badge')
      expect(badge.attributes('role')).toBeUndefined()
      expect(badge.attributes('tabindex')).toBeUndefined()
    })
  })

  describe('events', () => {
    it('emits manageSatisfactions on click', async () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: true,
        },
      })

      await wrapper.find('.satisfies-badge').trigger('click')
      expect(wrapper.emitted('manageSatisfactions')).toBeTruthy()
      expect(wrapper.emitted('manageSatisfactions')![0]).toEqual([123])
    })

    it('does not emit manageSatisfactions when actions disabled', async () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: false,
        },
      })

      await wrapper.find('.satisfies-badge').trigger('click')
      expect(wrapper.emitted('manageSatisfactions')).toBeFalsy()
    })

    it('handles keyboard enter', async () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: true,
        },
      })

      await wrapper.find('.satisfies-badge').trigger('keydown.enter')
      expect(wrapper.emitted('manageSatisfactions')).toBeTruthy()
    })

    it('handles keyboard space', async () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          actionsEnabled: true,
        },
      })

      await wrapper.find('.satisfies-badge').trigger('keydown.space')
      expect(wrapper.emitted('manageSatisfactions')).toBeTruthy()
    })
  })

  describe('props', () => {
    it('accepts satisfiesRules array', () => {
      const rules = [
        { id: 1, rule_id: '000001', title: 'Rule 1' },
        { id: 2, rule_id: '000002', title: 'Rule 2' },
      ]

      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 2,
          satisfiesRules: rules,
        },
      })

      expect(wrapper.vm.satisfiesRules).toEqual(rules)
    })

    it('respects actionsEnabled prop', () => {
      const wrapper = mount(SatisfiesIndicator, {
        props: {
          ruleId: 123,
          satisfiesCount: 1,
          actionsEnabled: false,
        },
      })

      expect(wrapper.vm.actionsEnabled).toBe(false)
    })
  })
})
