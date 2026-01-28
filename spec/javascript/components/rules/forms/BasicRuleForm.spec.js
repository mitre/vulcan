import { describe, it, expect } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BasicRuleForm from '@/components/rules/forms/BasicRuleForm.vue'
import BootstrapVue from 'bootstrap-vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

describe('BasicRuleForm', () => {
  const createWrapper = (ruleOverrides = {}) => {
    const defaultRule = {
      status: 'Not Yet Determined',
      satisfied_by: [],
      disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
      checks_attributes: [{ content: '' }],
      ...ruleOverrides
    }

    return shallowMount(BasicRuleForm, {
      localVue,
      propsData: {
        rule: defaultRule,
        disabled: false,
        fields: { displayed: [], disabled: [] }
      }
    })
  }

  describe('disaDescriptionFormFields', () => {
    it('shows vuln_discussion when status is Applicable - Configurable', () => {
      const wrapper = createWrapper({ status: 'Applicable - Configurable' })
      const fields = wrapper.vm.disaDescriptionFormFields

      expect(fields.displayed).toContain('vuln_discussion')
    })

    it('shows vuln_discussion when satisfied_by has entries (regardless of status)', () => {
      const wrapper = createWrapper({
        status: 'Not Yet Determined',
        satisfied_by: [{ id: 1 }]
      })
      const fields = wrapper.vm.disaDescriptionFormFields

      expect(fields.displayed).toContain('vuln_discussion')
    })

    it('does not show vuln_discussion when no satisfied_by and wrong status', () => {
      const wrapper = createWrapper({
        status: 'Applicable - Inherently Meets',
        satisfied_by: []
      })
      const fields = wrapper.vm.disaDescriptionFormFields

      expect(fields.displayed).not.toContain('vuln_discussion')
    })
  })

  describe('checkFormFields', () => {
    it('shows content when status is Applicable - Configurable', () => {
      const wrapper = createWrapper({ status: 'Applicable - Configurable' })
      const fields = wrapper.vm.checkFormFields

      expect(fields.displayed).toContain('content')
    })

    it('shows content when satisfied_by has entries (regardless of status)', () => {
      const wrapper = createWrapper({
        status: 'Not Yet Determined',
        satisfied_by: [{ id: 1 }]
      })
      const fields = wrapper.vm.checkFormFields

      expect(fields.displayed).toContain('content')
    })

    it('does not show content when no satisfied_by and wrong status', () => {
      const wrapper = createWrapper({
        status: 'Applicable - Inherently Meets',
        satisfied_by: []
      })
      const fields = wrapper.vm.checkFormFields

      expect(fields.displayed).not.toContain('content')
    })
  })
})
