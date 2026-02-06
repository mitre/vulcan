import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue } from 'bootstrap-vue'
import RuleDetails from '@/components/benchmarks/RuleDetails.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * RuleDetails Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. GENERIC (works for STIG and SRG):
 *    - Accepts type prop ('stig' | 'srg')
 *    - Displays rule title
 *    - Renders vuln discussion form
 *    - Renders check form
 *    - Renders fix text
 *    - Renders vendor comments if present
 *
 * 2. NO TYPE-SPECIFIC DISPLAY:
 *    - Component structure is the same for both types
 *    - All fields are generic (rule has same structure)
 *
 * 3. DISABLED FORMS:
 *    - All form fields disabled (read-only viewer)
 */
describe('RuleDetails', () => {
  let wrapper

  const mockRule = {
    id: 1,
    title: 'Test Rule Title',
    fixtext: 'Fix instructions here',
    vendor_comments: 'Vendor note about this rule',
    disa_rule_descriptions_attributes: [
      { vuln_discussion: 'Vulnerability details and discussion' }
    ],
    checks_attributes: [
      { content: 'Check content and procedure' }
    ]
  }

  const mockRuleWithoutVendorComments = {
    id: 2,
    title: 'Another Rule',
    fixtext: 'Different fix',
    disa_rule_descriptions_attributes: [
      { vuln_discussion: 'Different vuln' }
    ],
    checks_attributes: [
      { content: 'Different check' }
    ]
  }

  const createWrapper = (props = {}) => {
    return shallowMount(RuleDetails, {
      localVue,
      propsData: {
        selectedRule: mockRule,
        type: 'stig',
        ...props
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  // ==========================================
  // TYPE PROP
  // ==========================================
  describe('type prop', () => {
    it('accepts stig type', () => {
      wrapper = createWrapper({ type: 'stig' })
      expect(wrapper.props('type')).toBe('stig')
    })

    it('accepts srg type', () => {
      wrapper = createWrapper({ type: 'srg' })
      expect(wrapper.props('type')).toBe('srg')
    })

    it('type prop is required', () => {
      expect(RuleDetails.props.type.required).toBe(true)
    })

    it('validates type prop', () => {
      const validator = RuleDetails.props.type.validator
      expect(validator('stig')).toBe(true)
      expect(validator('srg')).toBe(true)
      expect(validator('invalid')).toBe(false)
    })
  })

  // ==========================================
  // BASIC RENDERING
  // ==========================================
  describe('basic rendering', () => {
    it('renders rule title in card header', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Test Rule Title')
    })

    it('renders fix text field', () => {
      wrapper = createWrapper()
      // Should contain "Fix" label
      expect(wrapper.text()).toContain('Fix')
    })

    it('renders vendor comments when present', () => {
      wrapper = createWrapper({ selectedRule: mockRule })
      expect(wrapper.text()).toContain('Vendor Comments')
    })

    it('does not render vendor comments when absent', () => {
      wrapper = createWrapper({ selectedRule: mockRuleWithoutVendorComments })
      expect(wrapper.text()).not.toContain('Vendor Comments')
    })
  })

  // ==========================================
  // FORM COMPONENTS
  // ==========================================
  describe('form components', () => {
    it('passes disabled=true to DisaRuleDescriptionForm', () => {
      wrapper = createWrapper()
      const disaForm = wrapper.findComponent({ name: 'DisaRuleDescriptionForm' })
      expect(disaForm.exists()).toBe(true)
      expect(disaForm.props('disabled')).toBe(true)
    })

    it('passes disabled=true to CheckForm', () => {
      wrapper = createWrapper()
      const checkForm = wrapper.findComponent({ name: 'CheckForm' })
      expect(checkForm.exists()).toBe(true)
      expect(checkForm.props('disabled')).toBe(true)
    })

    it('configures disaDescriptionFormFields correctly', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.disaDescriptionFormFields).toEqual({
        displayed: ['vuln_discussion'],
        disabled: []
      })
    })

    it('configures checkFormFields correctly', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.checkFormFields).toEqual({
        displayed: ['content'],
        disabled: []
      })
    })
  })

  // ==========================================
  // GENERIC BEHAVIOR (same for STIG and SRG)
  // ==========================================
  describe('generic behavior', () => {
    it('renders identically for STIG type', () => {
      const stigWrapper = createWrapper({ type: 'stig' })
      expect(stigWrapper.text()).toContain('Test Rule Title')
      expect(stigWrapper.text()).toContain('Fix')
    })

    it('renders identically for SRG type', () => {
      const srgWrapper = createWrapper({ type: 'srg' })
      expect(srgWrapper.text()).toContain('Test Rule Title')
      expect(srgWrapper.text()).toContain('Fix')
    })
  })
})
