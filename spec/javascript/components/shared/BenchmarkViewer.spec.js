import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import BenchmarkViewer from '@/components/shared/BenchmarkViewer.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * BenchmarkViewer Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. BREADCRUMB:
 *    - Shows benchmark type and title
 *    - Links back to list page
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar
 *    - LEFT: Download button, Back to list
 *    - RIGHT: Empty for now
 *
 * 3. THREE-COLUMN LAYOUT:
 *    - LEFT: Item list (rules/requirements/controls)
 *    - MIDDLE: Item details
 *    - RIGHT: Item overview/metadata
 *
 * 4. USES useBenchmarkViewer COMPOSABLE:
 *    - Navigation, search, filtering handled by composable
 *    - Component focuses on presentation
 *
 * 5. TYPE-AGNOSTIC:
 *    - Works for STIG, SRG, CIS via type prop
 *    - Adapts labels and fields based on type
 */
describe('BenchmarkViewer', () => {
  let wrapper

  // ADAPTED STIG data (after stigToBenchmark adapter)
  const stigBenchmark = {
    id: 1,
    title: 'Test STIG',
    version: 'V1R1',
    rules: [
      { id: 1, rule_id: 'SV-001', title: 'Rule One', severity: 'high' },
      { id: 2, rule_id: 'SV-002', title: 'Rule Two', severity: 'medium' }
    ]
  }

  const createWrapper = (props = {}) => {
    return shallowMount(BenchmarkViewer, {
      localVue,
      propsData: {
        benchmark: stigBenchmark,
        type: 'stig',
        ...props
      },
      stubs: {
        BBreadcrumb: true,
        BaseCommandBar: true,
        RuleList: true,
        RuleDetails: true,
        RuleOverview: true
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  describe('breadcrumb', () => {
    it('renders breadcrumb', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'BBreadcrumb' }).exists()).toBe(true)
    })

    it('breadcrumb shows type and title for STIG', () => {
      wrapper = createWrapper({ type: 'stig' })
      const crumbs = wrapper.vm.breadcrumbs
      expect(crumbs.some(c => c.text === 'STIGs')).toBe(true)
      expect(crumbs.some(c => c.text.includes('Test STIG'))).toBe(true)
    })

    it('breadcrumb shows type and title for SRG', () => {
      const srgBenchmark = { ...stigBenchmark, title: 'Test SRG', rules: [] }
      wrapper = createWrapper({ benchmark: srgBenchmark, type: 'srg' })
      const crumbs = wrapper.vm.breadcrumbs
      expect(crumbs.some(c => c.text === 'SRGs')).toBe(true)
    })
  })

  describe('command bar', () => {
    it('renders BaseCommandBar', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'BaseCommandBar' }).exists()).toBe(true)
    })

    it('has Download button', () => {
      wrapper = createWrapper()
      // Should have download functionality
      expect(wrapper.vm.openExportModal).toBeDefined()
    })
  })

  describe('three-column layout', () => {
    it('renders RuleList component for list column', () => {
      wrapper = createWrapper({ type: 'stig' })
      expect(wrapper.findComponent({ name: 'RuleList' }).exists()).toBe(true)
    })

    it('renders RuleDetails component for details column', () => {
      wrapper = createWrapper({ type: 'stig' })
      expect(wrapper.findComponent({ name: 'RuleDetails' }).exists()).toBe(true)
    })

    it('renders RuleOverview component for overview column', () => {
      wrapper = createWrapper({ type: 'stig' })
      expect(wrapper.findComponent({ name: 'RuleOverview' }).exists()).toBe(true)
    })
  })

  describe('uses composable', () => {
    it('initializes useBenchmarkViewer composable', () => {
      wrapper = createWrapper()
      // Composable provides selectedItem
      expect(wrapper.vm.selectedItem).toBeDefined()
    })

    it('provides filteredItems from composable', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.filteredItems).toBeDefined()
      expect(wrapper.vm.filteredItems.length).toBe(2)
    })
  })

  describe('type adaptation', () => {
    it('adapts for STIG type', () => {
      wrapper = createWrapper({ type: 'stig' })
      expect(wrapper.vm.benchmarkType).toBe('stig')
      expect(wrapper.vm.itemTypeName).toBe('rule')
    })

    it('adapts for SRG type', () => {
      const srgBenchmark = { ...stigBenchmark, rules: [] }
      wrapper = createWrapper({ benchmark: srgBenchmark, type: 'srg' })
      expect(wrapper.vm.benchmarkType).toBe('srg')
      expect(wrapper.vm.itemTypeName).toBe('requirement')
    })
  })
})
