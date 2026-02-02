import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import RuleCommandBar from '@/components/rules/RuleCommandBar.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * RuleCommandBar Component Tests
 *
 * REQUIREMENTS:
 * RuleCommandBar displays rule-level context information and provides
 * access to related rules. It contains:
 * - Context group: Rule ID, version, status icons, last editor
 * - Related button: Opens modal to view related rules
 *
 * NOTE: Satisfies, Reviews, History buttons were moved to ComponentCommandBar
 * as part of the DRY refactor to eliminate duplication between VIEW and EDIT pages.
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

  describe('Related button', () => {
    // REQUIREMENT: RuleCommandBar shows Related button to open RelatedRulesModal
    it('shows Related button', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Related')
    })

    it('emits open-related-modal when Related button is clicked', async () => {
      wrapper = createWrapper()
      const relatedButton = wrapper.findAll('b-button-stub').wrappers.find(
        btn => btn.text().includes('Related')
      )
      await relatedButton.trigger('click')
      expect(wrapper.emitted('open-related-modal')).toBeTruthy()
    })

    // REQUIREMENT: Satisfies, Reviews, History are NOT in RuleCommandBar
    // They are in ComponentCommandBar (single source of truth)
    it('does NOT show Satisfies button (moved to ComponentCommandBar)', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).not.toContain('Satisfies')
    })

    it('does NOT show Reviews button (moved to ComponentCommandBar)', () => {
      wrapper = createWrapper()
      // Should not contain standalone "Reviews" button
      // Note: "Related" contains these letters but is different
      const buttons = wrapper.findAll('b-button-stub')
      const reviewsButton = buttons.wrappers.find(btn => btn.text().trim() === 'Reviews')
      expect(reviewsButton).toBeUndefined()
    })

    it('does NOT show History button (moved to ComponentCommandBar)', () => {
      wrapper = createWrapper()
      const buttons = wrapper.findAll('b-button-stub')
      const historyButton = buttons.wrappers.find(btn => btn.text().trim() === 'History')
      expect(historyButton).toBeUndefined()
    })
  })

  describe('computed properties', () => {
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
