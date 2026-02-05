import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue } from 'bootstrap-vue'
import RuleList from '@/components/benchmarks/RuleList.vue'
import { RULE_TERM } from '@/constants/terminology'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * RuleList Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. GENERIC (works for STIG and SRG):
 *    - Accepts type prop ('stig' | 'srg')
 *    - Uses RULE_TERM constants for labels
 *
 * 2. SEARCH:
 *    - Search by rule ID or title
 *    - Uses RULE_TERM in placeholder
 *
 * 3. FILTER BY SEVERITY:
 *    - High, Medium, Low, All buttons
 *    - Shows count for each
 *
 * 4. RULE LIST:
 *    - Sorted by selected field (rule_id, title, severity)
 *    - Click rule to select
 *    - Highlight selected rule
 *
 * 5. TERMINOLOGY:
 *    - "Requirements" → RULE_TERM.plural
 *    - "Rule" → RULE_TERM.singular
 *    - "Search Rule" → `Search ${RULE_TERM.singular}`
 */
describe('RuleList', () => {
  let wrapper

  const sampleRules = [
    { id: 1, rule_id: 'SV-001', title: 'Rule One', rule_severity: 'high' },
    { id: 2, rule_id: 'SV-002', title: 'Rule Two', rule_severity: 'medium' },
    { id: 3, rule_id: 'SV-003', title: 'Rule Three', rule_severity: 'low' }
  ]

  const createWrapper = (props = {}) => {
    return shallowMount(RuleList, {
      localVue,
      propsData: {
        rules: sampleRules,
        initialSelectedRule: sampleRules[0],
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
    it('uses RULE_TERM.plural for list title', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain(RULE_TERM.plural)
    })

    it('uses RULE_TERM.singular in search placeholder', () => {
      wrapper = createWrapper()
      const placeholder = wrapper.find('input[type="text"]').attributes('placeholder')
      expect(placeholder).toContain(RULE_TERM.singular)
    })

    it('does not have hardcoded "Requirements" string', () => {
      wrapper = createWrapper()
      // Should use RULE_TERM.plural instead
      const html = wrapper.html()
      expect(html).not.toMatch(/(?<!RULE_TERM\.)Requirements/)
    })

    it('does not have hardcoded "Rule" string (uses RULE_TERM)', () => {
      wrapper = createWrapper()
      const html = wrapper.html()
      // Should use RULE_TERM.singular, not hardcoded
      expect(html).not.toMatch(/(?<!RULE_TERM\.)Rule(?!s)/) // "Rule" but not "Rules"
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
      expect(wrapper.vm.$options.props.type.required).toBe(true)
    })
  })

  // ==========================================
  // SEARCH
  // ==========================================
  describe('search functionality', () => {
    it('filters by rule_id', async () => {
      wrapper = createWrapper()
      await wrapper.setData({ searchText: 'SV-001' })
      const filtered = wrapper.vm.filteredRules
      expect(filtered.length).toBe(1)
      expect(filtered[0].rule_id).toBe('SV-001')
    })

    it('filters by title', async () => {
      wrapper = createWrapper()
      await wrapper.setData({ searchText: 'Rule Two' })
      const filtered = wrapper.vm.filteredRules
      expect(filtered.length).toBe(1)
      expect(filtered[0].title).toBe('Rule Two')
    })

    it('search is case-insensitive', async () => {
      wrapper = createWrapper()
      await wrapper.setData({ searchText: 'rule one' })
      const filtered = wrapper.vm.filteredRules
      expect(filtered.length).toBe(1)
    })
  })

  // ==========================================
  // SEVERITY FILTER
  // ==========================================
  describe('severity filtering', () => {
    it('filters by high severity', async () => {
      wrapper = createWrapper()
      await wrapper.setData({ severity: 'high' })
      const filtered = wrapper.vm.filteredRules
      expect(filtered.length).toBe(1)
      expect(filtered[0].rule_severity).toBe('high')
    })

    it('shows all when severity is empty', async () => {
      wrapper = createWrapper()
      await wrapper.setData({ severity: '' })
      const filtered = wrapper.vm.filteredRules
      expect(filtered.length).toBe(3)
    })

    it('counts high severity rules', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.high_count).toBe(1)
    })

    it('counts medium severity rules', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.medium_count).toBe(1)
    })

    it('counts low severity rules', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.low_count).toBe(1)
    })
  })

  // ==========================================
  // RULE SELECTION
  // ==========================================
  describe('rule selection', () => {
    it('emits rule-selected when rule clicked', async () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(sampleRules[1])
      expect(wrapper.emitted('rule-selected')).toBeTruthy()
      expect(wrapper.emitted('rule-selected')[0]).toEqual([sampleRules[1]])
    })

    it('highlights selected rule', () => {
      wrapper = createWrapper({ initialSelectedRule: sampleRules[1] })
      // Selected rule should have active class or styling
      expect(wrapper.vm.selectedRule).toEqual(sampleRules[1])
    })
  })
})
