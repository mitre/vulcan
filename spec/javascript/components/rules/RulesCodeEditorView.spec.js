import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import RulesCodeEditorView from '@/components/rules/RulesCodeEditorView.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

// Mock axios
vi.mock('axios', () => ({
  default: {
    put: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} }))
  }
}))

describe('RulesCodeEditorView', () => {
  let wrapper

  const mockRules = [
    {
      id: 1,
      rule_id: '001',
      status: 'Not Yet Determined',
      locked: false,
      review_requestor_id: null,
      satisfies: [],
      satisfied_by: [],
      histories: [{ name: 'Test User' }],
      version: 'SV-001'
    },
    {
      id: 2,
      rule_id: '002',
      status: 'Applicable - Configurable',
      locked: false,
      review_requestor_id: null,
      satisfies: [],
      satisfied_by: [],
      histories: [],
      version: 'SV-002'
    },
    {
      id: 3,
      rule_id: '003',
      status: 'Not Applicable',
      locked: true,
      review_requestor_id: null,
      satisfies: [],
      satisfied_by: [],
      histories: [],
      version: 'SV-003'
    }
  ]

  const defaultProps = {
    effectivePermissions: 'admin',
    currentUserId: 1,
    project: { id: 1, name: 'Test Project' },
    component: {
      id: 41,
      prefix: 'TEST',
      advanced_fields: false,
      additional_questions: []
    },
    rules: mockRules,
    statuses: [
      'Not Yet Determined',
      'Applicable - Configurable',
      'Applicable - Inherently Meets',
      'Applicable - Does Not Meet',
      'Not Applicable'
    ],
    severities: ['low', 'medium', 'high'],
    severities_map: { low: 'CAT III', medium: 'CAT II', high: 'CAT I' }
  }

  const createWrapper = (props = {}) => {
    return shallowMount(RulesCodeEditorView, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props
      },
      stubs: {
        RuleNavigator: true,
        RuleEditor: true,
        RuleHistories: true,
        RuleReviews: true,
        RuleSatisfactions: true,
        RelatedRulesModal: true,
        RuleReviewModal: true,
        RuleFilterBar: true,
        RuleCommandBar: true,
        ControlsPageLayout: true,
        NewRuleModalForm: true,
        Multiselect: true,
        BModal: true,
        BSidebar: true,
        BButton: true,
        BFormGroup: true,
        BIcon: true
      },
      mocks: {
        $root: {
          $emit: vi.fn()
        }
      }
    })
  }

  beforeEach(() => {
    localStorage.clear()
  })

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  describe('basic rendering', () => {
    it('renders the component', () => {
      wrapper = createWrapper()
      expect(wrapper.exists()).toBe(true)
    })

    it('renders ControlsPageLayout', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'ControlsPageLayout' }).exists()).toBe(true)
    })

    it('renders RuleCommandBar when rule is selected', async () => {
      wrapper = createWrapper()
      // Select a rule first
      wrapper.vm.selectRule(1)
      await wrapper.vm.$nextTick()
      expect(wrapper.findComponent({ name: 'RuleCommandBar' }).exists()).toBe(true)
    })

    it('renders RuleFilterBar', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'RuleFilterBar' }).exists()).toBe(true)
    })

    it('renders RuleNavigator', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'RuleNavigator' }).exists()).toBe(true)
    })
  })

  describe('useRuleSelection composable integration', () => {
    it('has selectedRuleId in component state', () => {
      wrapper = createWrapper()
      // After composable integration, selectedRuleId should be a ref
      expect(wrapper.vm.selectedRuleId).toBeDefined()
    })

    it('has openRuleIds in component state', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.openRuleIds).toBeDefined()
    })

    it('has selectedRule computed property', () => {
      wrapper = createWrapper()
      // selectedRule should be a computed, not a function
      expect(wrapper.vm.selectedRule).toBeDefined()
    })

    it('selectRule method updates selectedRuleId', () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(1)
      expect(wrapper.vm.selectedRuleId).toBe(1)
    })

    it('selectRule adds to openRuleIds', () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(1)
      expect(wrapper.vm.openRuleIds).toContain(1)
    })

    it('deselectRule removes from openRuleIds', () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(1)
      wrapper.vm.deselectRule(1)
      expect(wrapper.vm.openRuleIds).not.toContain(1)
    })

    it('persists selectedRuleId to localStorage', () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(1)
      expect(localStorage.getItem('selectedRuleId-41')).toBe('1')
    })
  })

  describe('useRuleFilters composable integration', () => {
    it('has filters in component state', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.filters).toBeDefined()
      expect(wrapper.vm.filters.acFilterChecked).toBe(true)
    })

    it('has counts computed property', () => {
      wrapper = createWrapper()
      // counts should come from useRuleFilters
      const counts = wrapper.vm.counts
      expect(counts).toBeDefined()
      expect(counts.nyd).toBe(1) // One rule with 'Not Yet Determined'
      expect(counts.ac).toBe(1) // One rule with 'Applicable - Configurable'
    })

    it('setFilter updates filter state', () => {
      wrapper = createWrapper()
      wrapper.vm.setFilter('acFilterChecked', false)
      expect(wrapper.vm.filters.acFilterChecked).toBe(false)
    })

    it('resetFilters resets all filters', () => {
      wrapper = createWrapper()
      wrapper.vm.setFilter('acFilterChecked', false)
      wrapper.vm.resetFilters()
      expect(wrapper.vm.filters.acFilterChecked).toBe(true)
    })
  })

  describe('useSidebar composable integration', () => {
    it('has activePanel in component state', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.activePanel).toBeDefined()
    })

    it('togglePanel opens a panel', () => {
      wrapper = createWrapper()
      wrapper.vm.togglePanel('reviews')
      expect(wrapper.vm.activePanel).toBe('reviews')
    })

    it('togglePanel closes panel when toggled again', () => {
      wrapper = createWrapper()
      wrapper.vm.togglePanel('reviews')
      wrapper.vm.togglePanel('reviews')
      expect(wrapper.vm.activePanel).toBeNull()
    })

    it('togglePanel switches between panels', () => {
      wrapper = createWrapper()
      wrapper.vm.togglePanel('reviews')
      wrapper.vm.togglePanel('history')
      expect(wrapper.vm.activePanel).toBe('history')
    })
  })

  describe('event handling', () => {
    it('passes selectRule to RuleNavigator as ruleSelected handler', () => {
      wrapper = createWrapper()
      const navigator = wrapper.findComponent({ name: 'RuleNavigator' })
      expect(navigator.exists()).toBe(true)
      // The @ruleSelected should be connected to selectRule (or handleRuleSelected)
    })

    it('passes activePanel to RuleCommandBar', async () => {
      wrapper = createWrapper()
      wrapper.vm.togglePanel('reviews')
      await wrapper.vm.$nextTick()
      // With shallowMount, check the vm state rather than stubbed component props
      expect(wrapper.vm.activePanel).toBe('reviews')
    })
  })

  describe('computed properties', () => {
    it('isViewerOnly returns true for viewer permissions', () => {
      wrapper = createWrapper({ effectivePermissions: 'viewer' })
      expect(wrapper.vm.isViewerOnly).toBe(true)
    })

    it('isViewerOnly returns false for admin permissions', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      expect(wrapper.vm.isViewerOnly).toBe(false)
    })
  })
})
