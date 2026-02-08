import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import BenchmarkViewer from '@/components/shared/BenchmarkViewer.vue'
import { stigToBenchmark, srgToBenchmark } from '@/adapters/benchmark'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * BenchmarkViewer Integration Tests
 *
 * REQUIREMENTS:
 *
 * These tests verify the COMPLETE DATA FLOW from raw DB data through
 * adapters, composable, and into components. Unit tests test pieces
 * in isolation - integration tests verify they work together.
 *
 * CONTRACT VERIFICATION:
 * 1. Adapter output structure matches composable expectations
 * 2. Composable config matches adapter output
 * 3. Components receive non-null data when rules exist
 * 4. Full STIG and SRG flows work end-to-end
 *
 * CRITICAL: These tests would have caught the stig_rules vs rules bug.
 */
describe('BenchmarkViewer Integration', () => {
  let wrapper

  // Realistic STIG data as it comes from Rails
  const rawStigData = {
    id: 1,
    stig_id: 'TEST_STIG',
    title: 'Test STIG',
    version: 'V1R1',
    benchmark_date: '2024-01-15',
    stig_rules: [
      {
        id: 1,
        rule_id: 'SV-001',
        version: 'r1',
        title: 'Rule One',
        rule_severity: 'high',
        vuln_id: 'V-001'
      },
      {
        id: 2,
        rule_id: 'SV-002',
        version: 'r1',
        title: 'Rule Two',
        rule_severity: 'medium',
        vuln_id: 'V-002'
      }
    ]
  }

  // Realistic SRG data as it comes from Rails
  const rawSrgData = {
    id: 2,
    srg_id: 'TEST_SRG',
    title: 'Test SRG',
    version: 'V2R1',
    release_date: '2024-02-20',
    srg_rules: [
      {
        id: 10,
        rule_id: 'SRG-001',
        version: 'r1',
        title: 'Requirement One',
        rule_severity: 'high'
      },
      {
        id: 11,
        rule_id: 'SRG-002',
        version: 'r1',
        title: 'Requirement Two',
        rule_severity: 'medium'
      }
    ]
  }

  const createWrapper = (rawData, type) => {
    // Apply adapter (simulating what Stig.vue/Srg.vue do)
    const adapter = type === 'stig' ? stigToBenchmark : srgToBenchmark
    const normalizedData = adapter(rawData)

    return mount(BenchmarkViewer, {
      localVue,
      propsData: {
        benchmark: normalizedData,
        type: type
      },
      stubs: {
        BaseCommandBar: true,
        ExportModal: true
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  // ==========================================
  // ADAPTER → COMPOSABLE CONTRACT
  // ==========================================
  describe('adapter to composable contract', () => {
    it('STIG: adapter output has "rules" property that composable expects', () => {
      const adapted = stigToBenchmark(rawStigData)

      // CRITICAL CONTRACT: Adapter must produce "rules" property
      expect(adapted).toHaveProperty('rules')
      expect(Array.isArray(adapted.rules)).toBe(true)
      expect(adapted.rules.length).toBe(2)

      // Composable config expects "rules" (not "stig_rules")
      expect(adapted).not.toHaveProperty('stig_rules')
    })

    it('SRG: adapter output has "rules" property that composable expects', () => {
      const adapted = srgToBenchmark(rawSrgData)

      // CRITICAL CONTRACT: Adapter must produce "rules" property
      expect(adapted).toHaveProperty('rules')
      expect(Array.isArray(adapted.rules)).toBe(true)
      expect(adapted.rules.length).toBe(2)

      // Composable config expects "rules" (not "srg_rules")
      expect(adapted).not.toHaveProperty('srg_rules')
    })

    it('adapted STIG and SRG have identical structure', () => {
      const stigAdapted = stigToBenchmark(rawStigData)
      const srgAdapted = srgToBenchmark(rawSrgData)

      // Both must have same keys after adaptation
      expect(Object.keys(stigAdapted).sort((a, b) => a.localeCompare(b))).toEqual(Object.keys(srgAdapted).sort((a, b) => a.localeCompare(b)))

      // Both must have "rules" array
      expect(stigAdapted.rules).toBeDefined()
      expect(srgAdapted.rules).toBeDefined()
    })
  })

  // ==========================================
  // COMPOSABLE INITIALIZATION
  // ==========================================
  describe('composable initializes selectedItem', () => {
    it('STIG: selectedItem is NOT null when rules exist', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      // CRITICAL: If rules exist, selectedItem should be auto-selected
      expect(wrapper.vm.selectedItem).not.toBeNull()
      expect(wrapper.vm.selectedItem).toBeDefined()
      expect(wrapper.vm.selectedItem.id).toBe(1)
    })

    it('SRG: selectedItem is NOT null when rules exist', () => {
      wrapper = createWrapper(rawSrgData, 'srg')

      // CRITICAL: If rules exist, selectedItem should be auto-selected
      expect(wrapper.vm.selectedItem).not.toBeNull()
      expect(wrapper.vm.selectedItem).toBeDefined()
      expect(wrapper.vm.selectedItem.id).toBe(10)
    })

    it('composable extracts items from adapted data', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      // Composable should find rules in adapted data
      expect(wrapper.vm.items.length).toBe(2)
      expect(wrapper.vm.filteredItems.length).toBe(2)
    })
  })

  // ==========================================
  // COMPONENT RECEIVES VALID DATA
  // ==========================================
  describe('components receive valid data (not null)', () => {
    it('STIG: RuleList receives non-null selected rule', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      const ruleList = wrapper.findComponent({ name: 'RuleList' })
      expect(ruleList.exists()).toBe(true)
      expect(ruleList.props('initialSelectedRule')).not.toBeNull()
      expect(ruleList.props('initialSelectedRule').id).toBe(1)
    })

    it('STIG: RuleDetails receives non-null selected rule', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      const ruleDetails = wrapper.findComponent({ name: 'RuleDetails' })
      expect(ruleDetails.exists()).toBe(true)
      expect(ruleDetails.props('selectedRule')).not.toBeNull()
      expect(ruleDetails.props('selectedRule').title).toBe('Rule One')
    })

    it('STIG: RuleOverview receives non-null selected rule', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      const ruleOverview = wrapper.findComponent({ name: 'RuleOverview' })
      expect(ruleOverview.exists()).toBe(true)
      expect(ruleOverview.props('selectedRule')).not.toBeNull()
      expect(ruleOverview.props('selectedRule').vuln_id).toBe('V-001')
    })

    it('SRG: RuleDetails receives non-null selected rule', () => {
      wrapper = createWrapper(rawSrgData, 'srg')

      const ruleDetails = wrapper.findComponent({ name: 'RuleDetails' })
      expect(ruleDetails.exists()).toBe(true)
      expect(ruleDetails.props('selectedRule')).not.toBeNull()
      expect(ruleDetails.props('selectedRule').title).toBe('Requirement One')
    })
  })

  // ==========================================
  // END-TO-END RENDERING
  // ==========================================
  describe('end-to-end rendering', () => {
    it('STIG: renders without errors', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      // Should not throw errors during render
      expect(wrapper.exists()).toBe(true)
      // Should display STIG title
      expect(wrapper.text()).toContain('Test STIG')
    })

    it('SRG: renders without errors', () => {
      wrapper = createWrapper(rawSrgData, 'srg')

      // Should not throw errors during render
      expect(wrapper.exists()).toBe(true)
      // Should display SRG title
      expect(wrapper.text()).toContain('Test SRG')
    })

    it('STIG: displays first rule by default', () => {
      wrapper = createWrapper(rawStigData, 'stig')

      // First rule should be selected and displayed
      expect(wrapper.vm.selectedItem.title).toBe('Rule One')
      expect(wrapper.text()).toContain('Rule One')
    })

    it('SRG: displays first requirement by default', () => {
      wrapper = createWrapper(rawSrgData, 'srg')

      // First requirement should be selected and displayed
      expect(wrapper.vm.selectedItem.title).toBe('Requirement One')
      expect(wrapper.text()).toContain('Requirement One')
    })
  })

  // ==========================================
  // EMPTY STATE HANDLING
  // ==========================================
  describe('handles empty benchmarks gracefully', () => {
    it('STIG with no rules does not crash', () => {
      const emptySTIG = { ...rawStigData, stig_rules: [] }
      wrapper = createWrapper(emptySTIG, 'stig')

      expect(wrapper.exists()).toBe(true)
      expect(wrapper.vm.selectedItem).toBeNull()
    })

    it('SRG with no rules does not crash', () => {
      const emptySRG = { ...rawSrgData, srg_rules: [] }
      wrapper = createWrapper(emptySRG, 'srg')

      expect(wrapper.exists()).toBe(true)
      expect(wrapper.vm.selectedItem).toBeNull()
    })
  })
})
