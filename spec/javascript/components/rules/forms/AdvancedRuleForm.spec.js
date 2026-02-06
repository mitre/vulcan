import { describe, it, expect } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import AdvancedRuleForm from '@/components/rules/forms/AdvancedRuleForm.vue'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

// REQUIREMENTS:
// 1. disaDescriptionFormFields controls which DISA description fields are
//    visible to the author based on the rule's status.
// 2. severity_override_guidance must be shown for statuses where authors
//    may need to document severity override justification:
//    - "Applicable - Configurable" (full editing)
//    - "Applicable - Does Not Meet" (gap documentation)
//    - Rules with satisfied_by entries (treated like Configurable)
// 3. severity_override_guidance must NOT be shown for:
//    - "Not Yet Determined" (no severity assessment yet)
//    - "Applicable - Inherently Meets" (no override needed)
//    - "Not Applicable" (no severity assessment needed)
// 4. ruleFormFields controls which top-level rule fields (status, title,
//    severity, etc.) are visible per status.

describe('AdvancedRuleForm', () => {
  const defaultStatuses = [
    'Not Yet Determined',
    'Applicable - Configurable',
    'Applicable - Inherently Meets',
    'Applicable - Does Not Meet',
    'Not Applicable'
  ]

  const defaultSeverities = ['low', 'medium', 'high']

  const createWrapper = (ruleOverrides = {}) => {
    const defaultRule = {
      status: 'Not Yet Determined',
      satisfied_by: [],
      locked: false,
      review_requestor_id: null,
      disa_rule_descriptions_attributes: [{
        _destroy: false,
        vuln_discussion: '',
        severity_override_guidance: '',
        mitigation_control: ''
      }],
      checks_attributes: [{ content: '', _destroy: false }],
      rule_descriptions_attributes: [],
      nist_control_family: 'AC',
      srg_rule_attributes: { title: 'Test SRG Rule' },
      ident: 'CCI-000001',
      srg_info: { title: 'Test SRG' },
      ...ruleOverrides
    }

    return shallowMount(AdvancedRuleForm, {
      localVue,
      propsData: {
        rule: defaultRule,
        statuses: defaultStatuses,
        severities: defaultSeverities
      }
    })
  }

  describe('disaDescriptionFormFields', () => {
    describe('"Applicable - Configurable" status', () => {
      it('includes all DISA description fields', () => {
        const wrapper = createWrapper({ status: 'Applicable - Configurable' })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).toEqual([
          'documentable',
          'vuln_discussion',
          'false_positives',
          'false_negatives',
          'mitigations_available',
          'mitigations',
          'poam_available',
          'poam',
          'severity_override_guidance',
          'potential_impacts',
          'third_party_tools',
          'mitigation_control',
          'responsibility',
          'ia_controls'
        ])
        expect(fields.disabled).toEqual([])
      })
    })

    describe('"Applicable - Does Not Meet" status', () => {
      it('shows exactly mitigation_control and severity_override_guidance', () => {
        const wrapper = createWrapper({ status: 'Applicable - Does Not Meet' })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).toEqual(['mitigation_control', 'severity_override_guidance'])
        expect(fields.disabled).toEqual([])
      })
    })

    describe('"Not Yet Determined" status', () => {
      it('shows only vuln_discussion', () => {
        const wrapper = createWrapper({ status: 'Not Yet Determined', satisfied_by: [] })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).toEqual(['vuln_discussion'])
      })

      it('does not include severity_override_guidance', () => {
        const wrapper = createWrapper({ status: 'Not Yet Determined', satisfied_by: [] })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).not.toContain('severity_override_guidance')
      })
    })

    describe('"Applicable - Inherently Meets" status', () => {
      it('shows no DISA description fields', () => {
        const wrapper = createWrapper({ status: 'Applicable - Inherently Meets' })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).toEqual([])
      })
    })

    describe('"Not Applicable" status', () => {
      it('shows no DISA description fields', () => {
        const wrapper = createWrapper({ status: 'Not Applicable' })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).toEqual([])
      })
    })

    describe('rules with satisfied_by entries', () => {
      it('shows all DISA description fields regardless of status', () => {
        const wrapper = createWrapper({
          status: 'Not Yet Determined',
          satisfied_by: [{ id: 1 }]
        })
        const fields = wrapper.vm.disaDescriptionFormFields

        expect(fields.displayed).toContain('severity_override_guidance')
        expect(fields.displayed).toContain('mitigation_control')
        expect(fields.displayed).toContain('vuln_discussion')
      })
    })
  })

  describe('ruleFormFields', () => {
    describe('"Applicable - Does Not Meet" status', () => {
      it('shows status, status_justification, and vendor_comments', () => {
        const wrapper = createWrapper({ status: 'Applicable - Does Not Meet' })
        const fields = wrapper.vm.ruleFormFields

        expect(fields.displayed).toEqual(['status', 'status_justification', 'vendor_comments'])
        expect(fields.disabled).toEqual([])
      })
    })

    describe('"Not Yet Determined" status', () => {
      it('shows status and title (title disabled)', () => {
        const wrapper = createWrapper({ status: 'Not Yet Determined' })
        const fields = wrapper.vm.ruleFormFields

        expect(fields.displayed).toEqual(['status', 'title'])
        expect(fields.disabled).toEqual(['title'])
      })
    })
  })
})
