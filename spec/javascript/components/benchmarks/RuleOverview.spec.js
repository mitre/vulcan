import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue } from 'bootstrap-vue'
import RuleOverview from '@/components/benchmarks/RuleOverview.vue'
import { RULE_TERM } from '@/constants/terminology'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * RuleOverview Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. STIG MODE - Field Order:
 *    a. Rule ID (truncated SV-203591, click-to-expand full SV-203591r557031_rule)
 *    b. STIG ID (from version column)
 *    c. → SRG ID (from srg_id column, indented/secondary)
 *    d. Legacy toggle (collapsed by default):
 *       - Vuln ID (from vuln_id)
 *       - Legacy IDs (from legacy_ids)
 *    e. Severity (with badge)
 *    f. CCI, IA Control, ATT&CK, CIS Controls
 *
 * 2. SRG MODE - Field Order:
 *    a. SRG ID (from version column - primary identifier)
 *    b. Rule ID (truncated, click-to-expand)
 *    c. Legacy toggle (if legacy_ids present):
 *       - Legacy IDs
 *    d. Severity (with badge)
 *    e. CCI, IA Control, ATT&CK, CIS Controls
 *
 * 3. LABELS - NEVER show:
 *    - "Version" (confusing XCCDF name)
 *    - "Requirement ID" (old label)
 *    - "Satisfies (SRG)" (old label)
 *    - "Core SRG" (old label, data is null for SRG rules)
 *
 * 4. EXPANDABLE RULE ID:
 *    - Initially shows truncated form (e.g., SV-203591)
 *    - Click toggles to full form (e.g., SV-203591r557031_rule)
 *    - Click again collapses back
 *
 * 5. LEGACY TOGGLE:
 *    - Collapsed by default
 *    - Click to reveal Vuln ID and Legacy IDs (STIG) or just Legacy IDs (SRG)
 *    - Only shown if there are legacy fields to display
 */
describe('RuleOverview', () => {
  let wrapper

  const stigRule = {
    id: 1,
    rule_id: 'SV-203591r557031_rule',
    version: 'RHEL-08-010190',
    title: 'Test STIG Rule',
    rule_severity: 'high',
    vuln_id: 'V-203591',
    srg_id: 'SRG-OS-000480',
    legacy_ids: 'V-56571, SV-70831',
    ident: 'CCI-000366',
    nist_control_family: 'CM-6'
  }

  const stigRuleWithMitreAndCis = {
    ...stigRule,
    ident: 'CCI-000366, T1078, T1078.004, 18, 5.2'
  }

  const srgRule = {
    id: 2,
    rule_id: 'SV-203591r557031_rule',
    version: 'SRG-OS-000001-GPOS-00001',
    title: 'Test SRG Rule',
    rule_severity: 'medium',
    ident: 'CCI-000366',
    nist_control_family: 'CM-6',
    vuln_id: null,
    srg_id: null,
    legacy_ids: null
  }

  const srgRuleWithLegacy = {
    ...srgRule,
    legacy_ids: 'V-56571, SV-70831'
  }

  const createWrapper = (props = {}) => {
    return mount(RuleOverview, {
      localVue,
      propsData: {
        selectedRule: stigRule,
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
  // TERMINOLOGY INTEGRATION
  // ==========================================
  describe('RULE_TERM integration', () => {
    it('uses RULE_TERM.singular in title', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain(`${RULE_TERM.singular} Overview`)
    })
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
      expect(RuleOverview.props.type.required).toBe(true)
    })

    it('validates type prop', () => {
      const validator = RuleOverview.props.type.validator
      expect(validator('stig')).toBe(true)
      expect(validator('srg')).toBe(true)
      expect(validator('invalid')).toBe(false)
    })
  })

  // ==========================================
  // FORBIDDEN LABELS
  // ==========================================
  describe('forbidden labels', () => {
    it('never shows "Version" label in STIG mode', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Version<\/strong>/)
    })

    it('never shows "Version" label in SRG mode', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Version<\/strong>/)
    })

    it('never shows "Requirement ID" label', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Requirement ID<\/strong>/)
    })

    it('never shows "Satisfies (SRG)" label', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Satisfies \(SRG\)<\/strong>/)
    })

    it('never shows "Core SRG" label', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Core SRG<\/strong>/)
    })
  })

  // ==========================================
  // STIG MODE
  // ==========================================
  describe('STIG mode', () => {
    it('shows truncated Rule ID initially', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      expect(wrapper.text()).toContain('Rule ID')
      expect(wrapper.text()).toContain('SV-203591')
      // Should NOT show full ID by default
      expect(wrapper.text()).not.toContain('SV-203591r557031_rule')
    })

    it('shows STIG ID from version column', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      expect(wrapper.text()).toContain('STIG ID')
      expect(wrapper.text()).toContain('RHEL-08-010190')
    })

    it('shows SRG ID from srg_id column', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      // Use arrow prefix to indicate secondary/mapping relationship
      expect(wrapper.text()).toContain('SRG ID')
      expect(wrapper.text()).toContain('SRG-OS-000480')
    })

    it('does not show Vuln ID by default (hidden in legacy toggle)', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      // Vuln ID label should not be visible when legacy toggle is collapsed
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Vuln ID<\/strong>/)
    })

    it('does not show Legacy IDs by default (hidden in legacy toggle)', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      expect(wrapper.text()).not.toContain('V-56571')
    })

    it('shows legacy toggle button when legacy fields exist', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const toggle = wrapper.find('[data-testid="legacy-toggle"]')
      expect(toggle.exists()).toBe(true)
    })

    it('reveals Vuln ID and Legacy IDs when legacy toggle clicked', async () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const toggle = wrapper.find('[data-testid="legacy-toggle"]')
      await toggle.trigger('click')
      expect(wrapper.text()).toContain('Vuln ID')
      expect(wrapper.text()).toContain('V-203591')
      expect(wrapper.text()).toContain('Legacy IDs')
      expect(wrapper.text()).toContain('V-56571')
    })

    it('collapses legacy toggle on second click', async () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const toggle = wrapper.find('[data-testid="legacy-toggle"]')
      await toggle.trigger('click')
      await wrapper.vm.$nextTick()
      // Legacy IDs value should be visible when expanded
      expect(wrapper.text()).toContain('V-56571')
      await toggle.trigger('click')
      await wrapper.vm.$nextTick()
      // Legacy IDs value should be hidden when collapsed
      expect(wrapper.text()).not.toContain('V-56571')
    })
  })

  // ==========================================
  // SRG MODE
  // ==========================================
  describe('SRG mode', () => {
    it('shows SRG ID from version column as primary', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      expect(wrapper.text()).toContain('SRG ID')
      expect(wrapper.text()).toContain('SRG-OS-000001-GPOS-00001')
    })

    it('shows truncated Rule ID', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      expect(wrapper.text()).toContain('Rule ID')
      expect(wrapper.text()).toContain('SV-203591')
      expect(wrapper.text()).not.toContain('SV-203591r557031_rule')
    })

    it('does not show Vuln ID (not populated for SRG rules)', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Vuln ID<\/strong>/)
    })

    it('does not show STIG ID (not populated for SRG rules)', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>STIG ID<\/strong>/)
    })

    it('does not show legacy toggle when no legacy_ids', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const toggle = wrapper.find('[data-testid="legacy-toggle"]')
      expect(toggle.exists()).toBe(false)
    })

    it('shows legacy toggle when legacy_ids present', () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRuleWithLegacy })
      const toggle = wrapper.find('[data-testid="legacy-toggle"]')
      expect(toggle.exists()).toBe(true)
    })

    it('reveals Legacy IDs (but not Vuln ID) when legacy toggle clicked on SRG', async () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRuleWithLegacy })
      const toggle = wrapper.find('[data-testid="legacy-toggle"]')
      await toggle.trigger('click')
      expect(wrapper.text()).toContain('Legacy IDs')
      expect(wrapper.text()).toContain('V-56571')
      // Vuln ID should not appear in SRG mode even when expanded
      const html = wrapper.html()
      expect(html).not.toMatch(/<strong>Vuln ID<\/strong>/)
    })
  })

  // ==========================================
  // EXPANDABLE RULE ID
  // ==========================================
  describe('expandable Rule ID', () => {
    it('initially shows truncated Rule ID', () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const ruleIdItem = wrapper.find('[data-testid="rule-id"]')
      expect(ruleIdItem.text()).toContain('SV-203591')
      expect(ruleIdItem.text()).not.toContain('SV-203591r557031_rule')
    })

    it('expands to full Rule ID on click', async () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const expandBtn = wrapper.find('[data-testid="rule-id-toggle"]')
      await expandBtn.trigger('click')
      const ruleIdItem = wrapper.find('[data-testid="rule-id"]')
      expect(ruleIdItem.text()).toContain('SV-203591r557031_rule')
    })

    it('collapses back to truncated on second click', async () => {
      wrapper = createWrapper({ type: 'stig', selectedRule: stigRule })
      const expandBtn = wrapper.find('[data-testid="rule-id-toggle"]')
      await expandBtn.trigger('click')
      await expandBtn.trigger('click')
      const ruleIdItem = wrapper.find('[data-testid="rule-id"]')
      expect(ruleIdItem.text()).toContain('SV-203591')
      expect(ruleIdItem.text()).not.toContain('SV-203591r557031_rule')
    })

    it('works in SRG mode too', async () => {
      wrapper = createWrapper({ type: 'srg', selectedRule: srgRule })
      const ruleIdItem = wrapper.find('[data-testid="rule-id"]')
      expect(ruleIdItem.text()).toContain('SV-203591')

      const expandBtn = wrapper.find('[data-testid="rule-id-toggle"]')
      await expandBtn.trigger('click')
      expect(ruleIdItem.text()).toContain('SV-203591r557031_rule')
    })
  })

  // ==========================================
  // COMMON FIELDS (both types)
  // ==========================================
  describe('common fields', () => {
    it('displays Severity with CAT label badge', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Severity')
      expect(wrapper.text()).toContain('CAT I')
    })

    it('displays CCI', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('CCI')
      expect(wrapper.text()).toContain('CCI-000366')
    })

    it('displays IA Control', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('IA Control')
      expect(wrapper.text()).toContain('CM-6')
    })
  })

  // ==========================================
  // SEVERITY BADGE
  // ==========================================
  describe('severity badge', () => {
    it('applies bg-danger text-white class for high severity', () => {
      wrapper = createWrapper({ selectedRule: { ...stigRule, rule_severity: 'high' } })
      expect(wrapper.vm.severityBgColor).toBe('bg-danger text-white')
    })

    it('applies bg-warning text-dark class for medium severity', () => {
      wrapper = createWrapper({ selectedRule: { ...stigRule, rule_severity: 'medium' } })
      expect(wrapper.vm.severityBgColor).toBe('bg-warning text-dark')
    })

    it('applies bg-success text-white class for low severity', () => {
      wrapper = createWrapper({ selectedRule: { ...stigRule, rule_severity: 'low' } })
      expect(wrapper.vm.severityBgColor).toBe('bg-success text-white')
    })
  })

  // ==========================================
  // IDENT PARSING
  // ==========================================
  describe('ident parsing', () => {
    it('parses MITRE ATT&CK techniques', () => {
      wrapper = createWrapper({ selectedRule: stigRuleWithMitreAndCis })
      const mitreTechniques = wrapper.vm.mitreTechniques
      expect(mitreTechniques).toContain('T1078')
      expect(mitreTechniques).toContain('T1078.004')
    })

    it('parses CIS Controls', () => {
      wrapper = createWrapper({ selectedRule: stigRuleWithMitreAndCis })
      const cisControls = wrapper.vm.cisControls
      expect(cisControls).toContain('18')
      expect(cisControls).toContain('5.2')
    })

    it('returns empty arrays when ident is null', () => {
      const ruleNoIdent = { ...stigRule, ident: null }
      wrapper = createWrapper({ selectedRule: ruleNoIdent })
      expect(wrapper.vm.mitreTechniques).toEqual([])
      expect(wrapper.vm.cisControls).toEqual([])
    })
  })

  // ==========================================
  // EMPTY STATE
  // ==========================================
  describe('empty state', () => {
    it('shows prompt when no rule selected', () => {
      wrapper = createWrapper({ selectedRule: null })
      expect(wrapper.text()).toContain(`Select a ${RULE_TERM.singular.toLowerCase()} to view overview`)
    })
  })
})
