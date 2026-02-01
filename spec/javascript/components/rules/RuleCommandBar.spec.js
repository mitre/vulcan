import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import RuleCommandBar from '@/components/rules/RuleCommandBar.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * RuleCommandBar Component Tests
 *
 * After refactoring, RuleCommandBar only contains:
 * - Context group: Rule ID, version, status icons, last editor
 * - Panels group: Related, Satisfies, Reviews, History buttons
 *
 * Action buttons (Clone, Delete, Save, Comment, Review, Lock/Unlock)
 * have been moved to RuleActionsToolbar.vue
 */
describe('RuleCommandBar', () => {
  let wrapper

  const mockRule = {
    id: 1,
    rule_id: '00001',
    version: 'SV-12345r1',
    component_id: 41,
    status: 'Not Yet Determined',
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    reviews: [{ id: 1 }, { id: 2 }],
    histories: [{ name: 'John Doe', created_at: '2024-01-15' }],
    updated_at: '2024-01-15T10:00:00Z'
  }

  const createWrapper = (props = {}) => {
    return shallowMount(RuleCommandBar, {
      localVue,
      propsData: {
        rule: mockRule,
        componentPrefix: 'TEST',
        activePanel: null,
        ...props
      },
      stubs: {
        BIcon: true
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  describe('rendering', () => {
    it('renders the command bar container', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.command-bar').exists()).toBe(true)
    })

    it('displays the rule ID with component prefix', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('TEST-00001')
    })

    it('displays the rule version', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('SV-12345r1')
    })

    it('shows lock icon when rule is locked', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, locked: true }
      })
      const lockIcon = wrapper.find('[icon="lock"]')
      expect(lockIcon.exists()).toBe(true)
    })

    it('shows review icon when rule is under review', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, review_requestor_id: 123 }
      })
      const reviewIcon = wrapper.find('[icon="file-earmark-search"]')
      expect(reviewIcon.exists()).toBe(true)
    })

    it('shows warning icon when changes are requested', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, changes_requested: true }
      })
      const warningIcon = wrapper.find('[icon="exclamation-triangle"]')
      expect(warningIcon.exists()).toBe(true)
    })
  })

  describe('last editor display', () => {
    it('shows last editor name when histories exist', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('John Doe')
    })

    it('does not show last editor when no histories', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, histories: [] }
      })
      expect(wrapper.text()).not.toContain('Updated')
    })
  })

  describe('panel toggle buttons', () => {
    it('shows Related button', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Related')
    })

    it('shows Satisfies button', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Satisfies')
    })

    it('shows Reviews button with count badge', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Reviews')
      // Badge should show count of 2
      const badge = wrapper.find('.badge')
      expect(badge.exists()).toBe(true)
      expect(badge.text()).toBe('2')
    })

    it('shows History button', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('History')
    })

    it('highlights active panel button', () => {
      wrapper = createWrapper({ activePanel: 'reviews' })
      const reviewsButton = wrapper.findAll('b-button-stub').wrappers.find(
        btn => btn.text().includes('Reviews')
      )
      expect(reviewsButton.attributes('variant')).toBe('secondary')
    })
  })

  describe('events', () => {
    it('emits toggle-panel with panel name when panel button is clicked', async () => {
      wrapper = createWrapper()
      const satisfiesButton = wrapper.findAll('b-button-stub').wrappers.find(
        btn => btn.text().includes('Satisfies')
      )
      await satisfiesButton.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['satisfies'])
    })

    it('emits open-related-modal when Related button is clicked', async () => {
      wrapper = createWrapper()
      const relatedButton = wrapper.findAll('b-button-stub').wrappers.find(
        btn => btn.text().includes('Related')
      )
      await relatedButton.trigger('click')
      expect(wrapper.emitted('open-related-modal')).toBeTruthy()
    })
  })

  describe('computed properties', () => {
    it('computes reviewCount from rule.reviews', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.reviewCount).toBe(2)
    })

    it('computes reviewCount as 0 when no reviews', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, reviews: [] }
      })
      expect(wrapper.vm.reviewCount).toBe(0)
    })

    it('computes lastEditor from histories', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.lastEditor).toBe('John Doe')
    })

    it('computes lastEditor as null when no histories', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, histories: [] }
      })
      expect(wrapper.vm.lastEditor).toBeNull()
    })
  })
})
