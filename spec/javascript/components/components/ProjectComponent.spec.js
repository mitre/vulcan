import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import ProjectComponent from '@/components/components/ProjectComponent.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

// Mock axios
vi.mock('axios', () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} }))
  }
}))

describe('ProjectComponent', () => {
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
      reviews: [],
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
      reviews: [],
      version: 'SV-002'
    }
  ]

  const defaultProps = {
    effective_permissions: 'admin',
    current_user_id: 1,
    project: { id: 1, name: 'Test Project' },
    initialComponentState: {
      id: 41,
      name: 'Test Component',
      prefix: 'TEST',
      title: 'Test Title',
      description: 'Test Description',
      version: '1.0',
      release: 'R1',
      released: false,
      releasable: true,
      advanced_fields: false,
      additional_questions: [],
      admin_name: 'Admin',
      admin_email: 'admin@test.com',
      metadata: {},
      rules: mockRules,
      memberships: [],
      memberships_count: 0,
      inherited_memberships: [],
      available_members: [],
      histories: [],
      reviews: []
    },
    statuses: [
      'Not Yet Determined',
      'Applicable - Configurable',
      'Applicable - Inherently Meets',
      'Applicable - Does Not Meet',
      'Not Applicable'
    ],
    severities: ['low', 'medium', 'high'],
    severities_map: { low: 'CAT III', medium: 'CAT II', high: 'CAT I' },
    available_roles: ['admin', 'author', 'viewer']
  }

  const createWrapper = (props = {}) => {
    return shallowMount(ProjectComponent, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props
      },
      stubs: {
        ControlsPageLayout: true,
        ComponentCommandBar: true,
        RuleNavigator: true,
        RuleEditor: true,
        RuleSatisfactions: true,
        RuleReviews: true,
        RuleHistories: true,
        RelatedRulesModal: true,
        MembersModal: true,
        BSidebar: true,
        BModal: true,
        BIcon: true
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

    it('renders ComponentCommandBar', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'ComponentCommandBar' }).exists()).toBe(true)
    })

    it('renders RuleNavigator', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'RuleNavigator' }).exists()).toBe(true)
    })

    it('renders MembersModal', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'MembersModal' }).exists()).toBe(true)
    })
  })

  describe('useRuleSelection composable integration', () => {
    it('has selectedRuleId in component state', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.selectedRuleId).toBeDefined()
    })

    it('has openRuleIds in component state', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.openRuleIds).toBeDefined()
    })

    it('has selectedRule computed property', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.selectedRule).toBeDefined()
    })

    it('selectRule method updates selectedRuleId', () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(1)
      expect(wrapper.vm.selectedRuleId).toBe(1)
    })

    it('persists selectedRuleId to localStorage', () => {
      wrapper = createWrapper()
      wrapper.vm.selectRule(1)
      expect(localStorage.getItem('selectedRuleId-41')).toBe('1')
    })
  })

  describe('useSidebar composable integration', () => {
    it('has activePanel in component state', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.activePanel).toBeDefined()
    })

    it('togglePanel opens a panel', () => {
      wrapper = createWrapper()
      wrapper.vm.togglePanel('details')
      expect(wrapper.vm.activePanel).toBe('details')
    })

    it('togglePanel closes panel when toggled again', () => {
      wrapper = createWrapper()
      wrapper.vm.togglePanel('details')
      wrapper.vm.togglePanel('details')
      expect(wrapper.vm.activePanel).toBeNull()
    })
  })

  describe('component panels', () => {
    it('has details slideover', () => {
      wrapper = createWrapper()
      // Component should have slideover for details
      expect(wrapper.vm.componentPanels).toContain('details')
    })

    it('has metadata slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.componentPanels).toContain('metadata')
    })

    it('has questions slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.componentPanels).toContain('questions')
    })

    it('has comp-history slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.componentPanels).toContain('comp-history')
    })

    it('has comp-reviews slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.componentPanels).toContain('comp-reviews')
    })
  })

  describe('rule panels (enabled when rule selected)', () => {
    it('has satisfies slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.rulePanels).toContain('satisfies')
    })

    it('has reviews slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.rulePanels).toContain('reviews')
    })

    it('has history slideover', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.rulePanels).toContain('history')
    })
  })

  describe('no tabs or right sidebar', () => {
    it('does not have tabs', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'BTabs' }).exists()).toBe(false)
    })

    it('uses slideovers instead of right sidebar column', () => {
      wrapper = createWrapper()
      // The component uses b-sidebar for panels, not a fixed column
      const sidebars = wrapper.findAllComponents({ name: 'BSidebar' })
      expect(sidebars.length).toBeGreaterThan(0)
    })
  })
})
