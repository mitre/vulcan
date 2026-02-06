import { describe, it, expect } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import DisaRuleDescriptionForm from '@/components/rules/forms/DisaRuleDescriptionForm.vue'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

describe('DisaRuleDescriptionForm', () => {
  const createWrapper = (propsOverrides = {}) => {
    const defaultDescription = {
      _destroy: false,
      documentable: false,
      vuln_discussion: '',
      false_positives: '',
      false_negatives: '',
      mitigations_available: false,
      mitigations: '',
      poam_available: false,
      poam: '',
      severity_override_guidance: '',
      potential_impacts: '',
      third_party_tools: '',
      mitigation_control: '',
      responsibility: '',
      ia_controls: ''
    }

    const defaultRule = {
      status: 'Applicable - Configurable',
      satisfied_by: [],
      locked: false,
      review_requestor_id: null
    }

    const defaultFields = {
      displayed: [
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
      ],
      disabled: []
    }

    return mount(DisaRuleDescriptionForm, {
      localVue,
      propsData: {
        description: defaultDescription,
        rule: defaultRule,
        index: 0,
        disabled: false,
        fields: defaultFields,
        ...propsOverrides
      }
    })
  }

  // REQUIREMENT: The severity_override_guidance field label must read
  // "Severity Override Guidance" to match the DISA STIG terminology.
  // The database column is named severity_override_guidance, the
  // HumanizedTypesMixIn uses "Severity Override Guidance", and the
  // CSV export header is "Severity Override". The label in the form
  // template must be consistent with all of these.

  describe('severity_override_guidance field', () => {
    it('renders the field when included in displayed fields', () => {
      const wrapper = createWrapper()

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]'
      )
      expect(fieldGroup.exists()).toBe(true)
    })

    it('displays the correct label "Severity Override Guidance"', () => {
      const wrapper = createWrapper()

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]'
      )
      const label = fieldGroup.find('label')

      // The label must say "Severity" not "Security"
      expect(label.text()).toContain('Severity Override Guidance')
      expect(label.text()).not.toContain('Security Override Guidance')
    })

    it('does not render when not in displayed fields', () => {
      const wrapper = createWrapper({
        fields: {
          displayed: ['mitigation_control'],
          disabled: []
        }
      })

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]'
      )
      expect(fieldGroup.exists()).toBe(false)
    })

    it('renders a MarkdownTextarea for the field', () => {
      const wrapper = createWrapper()

      const fieldGroup = wrapper.find(
        '[id^="ruleEditor-disa_rule_description-severity_override_guidance-group"]'
      )
      // MarkdownTextarea wraps b-form-textarea — check it renders
      const textarea = fieldGroup.find('textarea, [id^="ruleEditor-disa_rule_description-severity_override_guidance-"]')
      expect(textarea.exists()).toBe(true)
    })
  })
})
