import { describe, it, expect } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BasicRuleForm from '@/components/rules/forms/BasicRuleForm.vue'
import BootstrapVue from 'bootstrap-vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

describe('BasicRuleForm', () => {
  const defaultStatuses = [
    'Not Yet Determined',
    'Applicable - Configurable',
    'Applicable - Inherently Meets',
    'Applicable - Does Not Meet',
    'Not Applicable'
  ]

  const defaultSeveritiesMap = {
    low: 'CAT III',
    medium: 'CAT II',
    high: 'CAT I'
  }

  const createWrapper = (ruleOverrides = {}) => {
    const defaultRule = {
      status: 'Not Yet Determined',
      satisfied_by: [],
      locked: false,
      review_requestor_id: null,
      disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
      checks_attributes: [{ content: '' }],
      // Props passed to RuleSecurityRequirementsGuideInformation
      nist_control_family: 'AC',
      srg_rule_attributes: { title: 'Test SRG Rule' },
      ident: 'CCI-000001',
      srg_info: { title: 'Test SRG' },
      ...ruleOverrides
    }

    return shallowMount(BasicRuleForm, {
      localVue,
      propsData: {
        rule: defaultRule,
        statuses: defaultStatuses,
        severities_map: defaultSeveritiesMap
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
