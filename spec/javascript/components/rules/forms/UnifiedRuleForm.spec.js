/**
 * UnifiedRuleForm Integration Tests
 *
 * REQUIREMENTS:
 * 1. Renders correct fields per status in basic mode (matching old BasicRuleForm)
 * 2. Renders correct fields per status in advanced mode (matching old AdvancedRuleForm)
 * 3. Severity override guidance appears dynamically when severity differs from SRG default
 * 4. satisfied_by forces Configurable behavior, disables title+fixtext only
 * 5. Collapsible DISA/Checks sections visible only in advanced mode
 * 6. RuleSecurityRequirementsGuideInformation always rendered
 */
import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import UnifiedRuleForm from '@/components/rules/forms/UnifiedRuleForm.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

function makeRule(overrides = {}) {
  return {
    status: 'Applicable - Configurable',
    rule_severity: 'medium',
    locked: false,
    review_requestor_id: null,
    satisfied_by: [],
    srg_rule_attributes: {
      rule_severity: 'medium',
      title: 'Test SRG Rule',
      disa_rule_descriptions_attributes: [{ vuln_discussion: 'SRG discussion' }],
      checks_attributes: [{ content: 'SRG check' }],
      fixtext: 'SRG fix',
      version: 'SRG-V1',
    },
    disa_rule_descriptions_attributes: [{
      _destroy: false,
      vuln_discussion: '',
      severity_override_guidance: '',
    }],
    checks_attributes: [{ content: '', _destroy: false }],
    nist_control_family: 'AC-2 (1)',
    ident: 'CCI-000015',
    srg_info: { title: 'Test SRG', version: 'V1R1' },
    ...overrides,
  }
}

describe('UnifiedRuleForm', () => {
  let wrapper

  const defaultStatuses = [
    'Not Yet Determined',
    'Applicable - Configurable',
    'Applicable - Inherently Meets',
    'Applicable - Does Not Meet',
    'Not Applicable',
  ]

  const createWrapper = (ruleOverrides = {}, props = {}) => {
    return shallowMount(UnifiedRuleForm, {
      localVue,
      propsData: {
        rule: makeRule(ruleOverrides),
        statuses: defaultStatuses,
        ...props,
      },
    })
  }

  afterEach(() => {
    if (wrapper) wrapper.destroy()
  })

  // ─── Component renders ─────────────────────────────────────
  describe('rendering', () => {
    it('renders RuleForm component', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'RuleForm' }).exists()).toBe(true)
    })

    it('renders RuleSecurityRequirementsGuideInformation', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'RuleSecurityRequirementsGuideInformation' }).exists()).toBe(true)
    })
  })

  // ─── Basic mode field visibility ───────────────────────────
  describe('basic mode (advancedMode=false)', () => {
    it('passes correct fields for Configurable', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(
        expect.arrayContaining(['status', 'rule_severity', 'title', 'fixtext', 'vendor_comments'])
      )
      expect(fields.disabled).toEqual([])
    })

    it('passes correct fields for Not Yet Determined (includes fixtext for context)', () => {
      wrapper = createWrapper({ status: 'Not Yet Determined' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(
        expect.arrayContaining(['status', 'rule_severity', 'title', 'fixtext'])
      )
      expect(fields.disabled).toEqual(
        expect.arrayContaining(['title', 'rule_severity', 'fixtext'])
      )
    })

    it('passes correct fields for Inherently Meets', () => {
      wrapper = createWrapper({ status: 'Applicable - Inherently Meets' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(
        expect.arrayContaining(['status', 'rule_severity', 'status_justification', 'artifact_description', 'vendor_comments'])
      )
    })

    it('passes correct fields for Does Not Meet', () => {
      wrapper = createWrapper({ status: 'Applicable - Does Not Meet' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(
        expect.arrayContaining(['status', 'rule_severity', 'status_justification', 'vendor_comments'])
      )
    })

    it('passes correct fields for Not Applicable', () => {
      wrapper = createWrapper({ status: 'Not Applicable' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(
        expect.arrayContaining(['status', 'rule_severity', 'status_justification', 'artifact_description', 'vendor_comments'])
      )
      expect(fields.disabled).toEqual(expect.arrayContaining(['rule_severity']))
    })
  })

  // ─── Advanced mode field visibility ────────────────────────
  describe('advanced mode (advancedMode=true)', () => {
    it('includes advanced fields for Configurable', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: true })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(expect.arrayContaining([
        'status', 'rule_severity', 'title', 'fixtext', 'vendor_comments',
        'status_justification', 'version', 'rule_weight',
        'artifact_description', 'fix_id', 'fixtext_fixref', 'ident', 'ident_system',
      ]))
    })

    it('shows collapsible DISA section for Does Not Meet (has advanced DISA additions)', () => {
      wrapper = createWrapper({ status: 'Applicable - Does Not Meet' }, { advancedMode: true })
      // DNM has advancedDisplayed DISA fields so should get collapsible sections
      expect(wrapper.findComponent({ name: 'DisaRuleDescriptionForm' }).exists()).toBe(true)
      const headings = wrapper.findAll('h2')
      const hasRuleDescriptionHeading = headings.wrappers.some(h => h.text() === 'Rule Description')
      expect(hasRuleDescriptionHeading).toBe(true)
    })

    it('does NOT show collapsible DISA section for NYD advanced (no advanced additions)', () => {
      wrapper = createWrapper({ status: 'Not Yet Determined' }, { advancedMode: true })
      // NYD has no advancedDisplayed entries, so disa_fields stay inline in RuleForm
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeDefined()
      expect(ruleForm.props('disa_fields').displayed).toContain('vuln_discussion')
      // No collapsible heading
      const headings = wrapper.findAll('h2')
      const hasRuleDescriptionHeading = headings.wrappers.some(h => h.text() === 'Rule Description')
      expect(hasRuleDescriptionHeading).toBe(false)
    })
  })

  // ─── DISA section visibility ───────────────────────────────
  describe('DISA section visibility', () => {
    it('passes disa_fields to RuleForm when DISA fields exist (basic mode)', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeDefined()
      expect(ruleForm.props('disa_fields').displayed).toContain('vuln_discussion')
    })

    it('passes disa_fields for NYD in basic mode (vuln_discussion disabled for context)', () => {
      wrapper = createWrapper({ status: 'Not Yet Determined' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeDefined()
      expect(ruleForm.props('disa_fields').displayed).toContain('vuln_discussion')
      expect(ruleForm.props('disa_fields').disabled).toContain('vuln_discussion')
    })

    it('does not pass disa_fields when no DISA fields (Inherently Meets basic)', () => {
      wrapper = createWrapper({ status: 'Applicable - Inherently Meets' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeUndefined()
    })

    it('does NOT pass disa_fields to RuleForm in advanced mode (collapsible section handles it)', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: true })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeUndefined()
    })

    it('shows collapsible DISA section in advanced mode when DISA fields exist', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: true })
      expect(wrapper.findComponent({ name: 'DisaRuleDescriptionForm' }).exists()).toBe(true)
    })

    it('hides collapsible DISA section in basic mode', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      // In basic mode, DisaRuleDescriptionForm is rendered inside RuleForm (via disa_fields prop)
      // The collapsible section with its own heading should NOT exist
      const headings = wrapper.findAll('h2')
      const hasRuleDescriptionHeading = headings.wrappers.some(h => h.text() === 'Rule Description')
      expect(hasRuleDescriptionHeading).toBe(false)
    })
  })

  // ─── Checks section visibility ─────────────────────────────
  describe('checks section visibility', () => {
    it('passes check_fields for Configurable', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('check_fields')).toBeDefined()
      expect(ruleForm.props('check_fields').displayed).toContain('content')
    })

    it('passes check_fields for Not Yet Determined (disabled, for context)', () => {
      wrapper = createWrapper({ status: 'Not Yet Determined' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('check_fields')).toBeDefined()
      expect(ruleForm.props('check_fields').displayed).toContain('content')
      expect(ruleForm.props('check_fields').disabled).toContain('content')
    })

    it('does not pass check_fields for statuses without check context', () => {
      wrapper = createWrapper({ status: 'Not Applicable' }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('check_fields')).toBeUndefined()
    })

    it('does NOT pass check_fields to RuleForm in advanced mode (collapsible section handles it)', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: true })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('check_fields')).toBeUndefined()
    })

    it('shows collapsible Checks section in advanced mode for Configurable', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: true })
      const headings = wrapper.findAll('h2')
      const hasChecksHeading = headings.wrappers.some(h => h.text() === 'Checks')
      expect(hasChecksHeading).toBe(true)
    })

    it('keeps check fields inline for NYD advanced mode (no collapsible section)', () => {
      wrapper = createWrapper({ status: 'Not Yet Determined' }, { advancedMode: true })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      // NYD has no advanced additions, so check fields stay inline in RuleForm
      expect(ruleForm.props('check_fields')).toBeDefined()
      expect(ruleForm.props('check_fields').displayed).toContain('content')
      // No collapsible heading
      const headings = wrapper.findAll('h2')
      const hasChecksHeading = headings.wrappers.some(h => h.text() === 'Checks')
      expect(hasChecksHeading).toBe(false)
    })
  })

  // ─── Severity override (R2) ────────────────────────────────
  describe('severity override (R2)', () => {
    it('injects severity_override_guidance into rule fields when severity changed', () => {
      wrapper = createWrapper({
        status: 'Applicable - Configurable',
        rule_severity: 'high',
        srg_rule_attributes: { rule_severity: 'medium', title: 'T', disa_rule_descriptions_attributes: [{}], checks_attributes: [{}], fixtext: '', version: '' },
      }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('fields').displayed).toContain('severity_override_guidance')
    })

    it('does NOT inject when severity matches SRG default', () => {
      wrapper = createWrapper({
        status: 'Applicable - Configurable',
        rule_severity: 'medium',
        srg_rule_attributes: { rule_severity: 'medium', title: 'T', disa_rule_descriptions_attributes: [{}], checks_attributes: [{}], fixtext: '', version: '' },
      }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('fields').displayed).not.toContain('severity_override_guidance')
    })
  })

  // ─── satisfied_by behavior (R3) ────────────────────────────
  describe('satisfied_by behavior (R3)', () => {
    it('uses Configurable fields when satisfied_by is set', () => {
      wrapper = createWrapper({
        status: 'Not Yet Determined',
        satisfied_by: [{ id: 1, fixtext: 'parent fix', checks_attributes: [{ content: '' }] }],
      }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).toEqual(
        expect.arrayContaining(['status', 'rule_severity', 'title', 'fixtext', 'vendor_comments'])
      )
    })

    it('disables title and fixtext when satisfied_by is set', () => {
      wrapper = createWrapper({
        status: 'Not Yet Determined',
        satisfied_by: [{ id: 1 }],
      }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.disabled).toEqual(expect.arrayContaining(['title', 'fixtext']))
    })

    it('does NOT disable entire form (disabled prop is false)', () => {
      wrapper = createWrapper({
        satisfied_by: [{ id: 1 }],
      }, { advancedMode: false })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disabled')).toBe(false)
    })
  })

  // ─── Form disabled states ─────────────────────────────────
  describe('form disabled state', () => {
    it('disables form when rule is locked', () => {
      wrapper = createWrapper({ locked: true })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disabled')).toBe(true)
    })

    it('disables form when under review', () => {
      wrapper = createWrapper({ review_requestor_id: 42 })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disabled')).toBe(true)
    })

    it('disables form when readOnly', () => {
      wrapper = createWrapper({}, { readOnly: true })
      const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disabled')).toBe(true)
    })
  })

  // ─── IA Control / CCI (R5) ─────────────────────────────────
  describe('IA Control / CCI always visible (R5)', () => {
    it('RuleForm receives rule with nist_control_family and ident for all statuses', () => {
      // IA Control/CCI are rendered inside RuleForm based on rule data (not field config)
      // They must always be present regardless of status
      const statuses = [
        'Not Yet Determined',
        'Applicable - Configurable',
        'Applicable - Inherently Meets',
        'Applicable - Does Not Meet',
        'Not Applicable',
      ]
      for (const status of statuses) {
        wrapper = createWrapper({ status }, { advancedMode: false })
        const ruleForm = wrapper.findComponent({ name: 'RuleForm' })
        const rule = ruleForm.props('rule')
        expect(rule.nist_control_family).toBe('AC-2 (1)')
        expect(rule.ident).toBe('CCI-000015')
        wrapper.destroy()
      }
    })
  })

  // ─── Reactivity (Part C) ──────────────────────────────────
  // These tests verify that changing inputs (status, severity) causes
  // the composable to re-compute and pass updated field props to RuleForm.
  // This catches Vue 2.7 reactivity bugs (e.g., toRef vs computed).
  describe('reactivity: field updates when inputs change', () => {
    it('updates fields when status changes from Configurable to Inherently Meets', async () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      let ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      // Configurable has title, fixtext, vendor_comments
      expect(ruleForm.props('fields').displayed).toContain('title')
      expect(ruleForm.props('fields').displayed).toContain('fixtext')

      // Change to Inherently Meets — loses title, fixtext; gains status_justification, artifact_description
      await wrapper.setProps({
        rule: makeRule({ status: 'Applicable - Inherently Meets' }),
      })
      ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      expect(fields.displayed).not.toContain('title')
      expect(fields.displayed).not.toContain('fixtext')
      expect(fields.displayed).toContain('status_justification')
      expect(fields.displayed).toContain('artifact_description')
    })

    it('severity_override_guidance appears when severity changes from SRG default', async () => {
      wrapper = createWrapper({
        status: 'Applicable - Configurable',
        rule_severity: 'medium',
        srg_rule_attributes: { rule_severity: 'medium' },
      }, { advancedMode: false })
      let ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('fields').displayed).not.toContain('severity_override_guidance')

      // Change severity to high (differs from SRG default 'medium')
      await wrapper.setProps({
        rule: makeRule({
          rule_severity: 'high',
          srg_rule_attributes: { rule_severity: 'medium' },
        }),
      })
      ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('fields').displayed).toContain('severity_override_guidance')
    })

    it('severity_override_guidance disappears when severity returns to SRG default', async () => {
      // Start with changed severity
      wrapper = createWrapper({
        status: 'Applicable - Configurable',
        rule_severity: 'high',
        srg_rule_attributes: { rule_severity: 'medium' },
      }, { advancedMode: false })
      let ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('fields').displayed).toContain('severity_override_guidance')

      // Change severity back to medium (matches SRG default)
      await wrapper.setProps({
        rule: makeRule({
          rule_severity: 'medium',
          srg_rule_attributes: { rule_severity: 'medium' },
        }),
      })
      ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('fields').displayed).not.toContain('severity_override_guidance')
    })

    it('DISA section disappears when status changes to one without DISA fields', async () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      let ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeDefined()
      expect(ruleForm.props('disa_fields').displayed).toContain('vuln_discussion')

      // Change to Inherently Meets — no DISA fields
      await wrapper.setProps({
        rule: makeRule({ status: 'Applicable - Inherently Meets' }),
      })
      ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('disa_fields')).toBeUndefined()
    })

    it('check section disappears when status changes to one without check fields', async () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' }, { advancedMode: false })
      let ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('check_fields')).toBeDefined()

      // Change to Not Applicable — no check fields
      await wrapper.setProps({
        rule: makeRule({ status: 'Not Applicable' }),
      })
      ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      expect(ruleForm.props('check_fields')).toBeUndefined()
    })

    it('satisfied_by forces Configurable field set on NYD rule', async () => {
      wrapper = createWrapper({ status: 'Not Yet Determined' }, { advancedMode: false })
      let ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      // NYD: title and fixtext disabled, no vendor_comments
      expect(ruleForm.props('fields').disabled).toContain('title')
      expect(ruleForm.props('fields').disabled).toContain('fixtext')
      expect(ruleForm.props('fields').displayed).not.toContain('vendor_comments')

      // Set satisfied_by — switches to Configurable field set
      await wrapper.setProps({
        rule: makeRule({
          status: 'Not Yet Determined',
          satisfied_by: [{ id: 1, fixtext: 'parent fix' }],
        }),
      })
      ruleForm = wrapper.findComponent({ name: 'RuleForm' })
      const fields = ruleForm.props('fields')
      // Now uses Configurable displayed fields
      expect(fields.displayed).toContain('vendor_comments')
      // But title and fixtext still disabled by satisfied_by
      expect(fields.disabled).toContain('title')
      expect(fields.disabled).toContain('fixtext')
    })
  })

  // ─── Status hint ───────────────────────────────────────────
  describe('status hint', () => {
    it('shows "fields hidden" hint when status is not Configurable', () => {
      wrapper = createWrapper({ status: 'Not Applicable' })
      expect(wrapper.text()).toContain('Some fields are hidden')
    })

    it('does not show hint when status is Configurable', () => {
      wrapper = createWrapper({ status: 'Applicable - Configurable' })
      expect(wrapper.text()).not.toContain('Some fields are hidden')
    })
  })
})
