import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import RuleEditor from '@/components/rules/RuleEditor.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * RuleEditor Component Tests
 *
 * REQUIREMENTS:
 * RuleEditor is the main editing interface for a rule. It must forward
 * all events from child components (RuleActionsToolbar) to parent components
 * so panels can be opened/closed.
 *
 * This is an INTEGRATION test - we test that events flow through the component
 * hierarchy correctly, not just that individual components emit events.
 */
describe('RuleEditor', () => {
  let wrapper

  const defaultRule = {
    id: 1,
    rule_id: '00001',
    locked: false,
    review_requestor_id: null,
    status: 'Not Yet Determined',
    rule_severity: 'medium'
  }

  const createWrapper = (props = {}) => {
    return mount(RuleEditor, {
      localVue,
      propsData: {
        rule: defaultRule,
        statuses: ['Not Yet Determined', 'Applicable - Configurable'],
        severities: ['low', 'medium', 'high'],
        severities_map: { low: 'CAT III', medium: 'CAT II', high: 'CAT I' },
        effectivePermissions: 'admin',
        readOnly: false,
        advanced_fields: false,
        additional_questions: [],
        ...props
      },
      stubs: {
        BasicRuleForm: true,
        AdvancedRuleForm: true,
        InspecControlEditor: true,
        CommentModal: {
          template: '<button class="comment-modal-stub" @click="$emit(\'comment\', \'test\')">{{ buttonText }}</button>',
          props: ['buttonText', 'buttonDisabled']
        }
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  // ==========================================
  // EVENT FORWARDING (Integration Tests)
  // ==========================================
  describe('event forwarding from RuleActionsToolbar', () => {
    // CRITICAL: These tests ensure events flow through the component hierarchy
    // Without proper forwarding, clicking buttons does nothing

    it('forwards toggle-panel event when Satisfies button is clicked', async () => {
      wrapper = createWrapper()
      const satisfiesBtn = wrapper.findAll('button').wrappers.find(b =>
        b.text().includes('Satisfies')
      )
      expect(satisfiesBtn).toBeDefined()
      await satisfiesBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['satisfies'])
    })

    it('forwards toggle-panel event when History button is clicked', async () => {
      wrapper = createWrapper()
      const historyBtn = wrapper.findAll('button').wrappers.find(b =>
        b.text().includes('History')
      )
      expect(historyBtn).toBeDefined()
      await historyBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['rule-history'])
    })

    it('forwards toggle-panel event when Reviews button is clicked', async () => {
      wrapper = createWrapper()
      const reviewsBtn = wrapper.findAll('button').wrappers.find(b =>
        b.text().includes('Reviews')
      )
      expect(reviewsBtn).toBeDefined()
      await reviewsBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['rule-reviews'])
    })

    it('forwards open-related-modal event when Related button is clicked', async () => {
      wrapper = createWrapper()
      const relatedBtn = wrapper.findAll('button').wrappers.find(b =>
        b.text().includes('Related')
      )
      expect(relatedBtn).toBeDefined()
      await relatedBtn.trigger('click')
      expect(wrapper.emitted('open-related-modal')).toBeTruthy()
    })
  })
})
