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
        effectivePermissions: 'admin',
        readOnly: false,
        advanced_fields: false,
        additional_questions: [],
        ...props
      },
      stubs: {
        UnifiedRuleForm: true,
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

  // ==========================================
  // ADVANCED FIELDS TOGGLE
  // ==========================================
  describe('Advanced Fields toggle', () => {
    /**
     * REQUIREMENTS:
     * 1. Toggle is ALWAYS visible (not conditional on advanced_fields prop)
     * 2. Toggle reflects component.advanced_fields state (from props)
     * 3. When enabling, show confirmation dialog with warning
     * 4. When confirmed, emit toggle-advanced-fields event
     * 5. When canceled, do not emit event
     * 6. Passes advancedMode to UnifiedRuleForm based on advanced_fields prop
     * 7. Helper text explains most users don't need this
     */

    it('always shows Advanced Fields toggle regardless of advanced_fields prop', () => {
      // Even when advanced_fields is false, toggle should be visible
      wrapper = createWrapper({ advanced_fields: false })
      const toggle = wrapper.find('[data-testid="advanced-fields-toggle"]')
      expect(toggle.exists()).toBe(true)
    })

    it('toggle reflects current advanced_fields prop value', async () => {
      wrapper = createWrapper({ advanced_fields: true })
      const checkbox = wrapper.find('[data-testid="advanced-fields-toggle"] input[type="checkbox"]')
      expect(checkbox.element.checked).toBe(true)
    })

    it('toggle is unchecked when advanced_fields is false', () => {
      wrapper = createWrapper({ advanced_fields: false })
      const checkbox = wrapper.find('[data-testid="advanced-fields-toggle"] input[type="checkbox"]')
      expect(checkbox.element.checked).toBe(false)
    })

    it('shows confirmation dialog when enabling advanced fields', async () => {
      wrapper = createWrapper({ advanced_fields: false })
      // Call the method directly to simulate checkbox change
      wrapper.vm.onAdvancedFieldsToggle(true)
      await wrapper.vm.$nextTick()

      // Modal should be shown
      expect(wrapper.vm.showConfirmModal).toBe(true)
    })

    it('emits toggle-advanced-fields when confirmation is accepted', async () => {
      wrapper = createWrapper({ advanced_fields: false })
      // Trigger the toggle
      wrapper.vm.onAdvancedFieldsToggle(true)
      await wrapper.vm.$nextTick()

      // Confirm
      wrapper.vm.confirmEnableAdvanced()
      await wrapper.vm.$nextTick()

      expect(wrapper.emitted('toggle-advanced-fields')).toBeTruthy()
      expect(wrapper.emitted('toggle-advanced-fields')[0]).toEqual([true])
    })

    it('does not emit event when confirmation is canceled', async () => {
      wrapper = createWrapper({ advanced_fields: false })
      // Trigger the toggle
      wrapper.vm.onAdvancedFieldsToggle(true)
      await wrapper.vm.$nextTick()

      // Cancel
      wrapper.vm.cancelEnableAdvanced()
      await wrapper.vm.$nextTick()

      expect(wrapper.emitted('toggle-advanced-fields')).toBeFalsy()
    })

    it('resets checkbox state when confirmation is canceled', async () => {
      wrapper = createWrapper({ advanced_fields: false })
      // Simulate checkbox being clicked (which sets localAdvancedFields to true)
      wrapper.vm.localAdvancedFields = true
      wrapper.vm.onAdvancedFieldsToggle(true)
      await wrapper.vm.$nextTick()

      // Cancel should reset local state back to prop value
      wrapper.vm.cancelEnableAdvanced()
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.localAdvancedFields).toBe(false)
    })

    it('emits toggle-advanced-fields immediately when disabling (no confirmation needed)', async () => {
      wrapper = createWrapper({ advanced_fields: true })
      // Call method directly - disabling should emit immediately
      wrapper.vm.onAdvancedFieldsToggle(false)
      await wrapper.vm.$nextTick()

      // Should emit immediately without confirmation
      expect(wrapper.emitted('toggle-advanced-fields')).toBeTruthy()
      expect(wrapper.emitted('toggle-advanced-fields')[0]).toEqual([false])
    })

    it('passes advancedMode=true to UnifiedRuleForm when advanced_fields is true', () => {
      wrapper = createWrapper({ advanced_fields: true })
      const form = wrapper.findComponent({ name: 'UnifiedRuleForm' })
      expect(form.exists()).toBe(true)
      expect(form.props('advancedMode')).toBe(true)
    })

    it('passes advancedMode=false to UnifiedRuleForm when advanced_fields is false', () => {
      wrapper = createWrapper({ advanced_fields: false })
      const form = wrapper.findComponent({ name: 'UnifiedRuleForm' })
      expect(form.exists()).toBe(true)
      expect(form.props('advancedMode')).toBe(false)
    })

    it('shows helper text explaining advanced fields are not needed by most users', () => {
      wrapper = createWrapper({ advanced_fields: false })
      const helperText = wrapper.find('[data-testid="advanced-fields-helper"]')
      expect(helperText.exists()).toBe(true)
      expect(helperText.text().toLowerCase()).toContain('most users')
    })

    // REGRESSION: Session 169 — @hidden on b-modal fires AFTER @ok,
    // calling cancelEnableAdvanced and resetting localAdvancedFields to false.
    // Fix: use @close instead of @hidden. This test catches that regression.
    it('keeps toggle ON after confirmation is accepted (regression: @hidden bug)', async () => {
      wrapper = createWrapper({ advanced_fields: false })

      // User clicks the toggle ON
      wrapper.vm.localAdvancedFields = true
      wrapper.vm.onAdvancedFieldsToggle(true)
      await wrapper.vm.$nextTick()

      // User clicks OK in the confirmation modal
      wrapper.vm.confirmEnableAdvanced()
      await wrapper.vm.$nextTick()

      // Toggle MUST still be ON — the @hidden bug would reset it to false here
      expect(wrapper.vm.localAdvancedFields).toBe(true)
      expect(wrapper.emitted('toggle-advanced-fields')[0]).toEqual([true])
    })

    it('syncs local state when prop changes (e.g., after API update)', async () => {
      wrapper = createWrapper({ advanced_fields: false })
      expect(wrapper.vm.localAdvancedFields).toBe(false)

      // Simulate parent updating prop after API call
      await wrapper.setProps({ advanced_fields: true })

      // Local state should sync with prop
      expect(wrapper.vm.localAdvancedFields).toBe(true)
    })

    /**
     * BUG 9-10: Checkbox bound to localAdvancedFields, form bound to advanced_fields
     * This causes a temporary mismatch when toggling.
     *
     * REQUIREMENT: When user clicks checkbox to disable advanced fields,
     * both the checkbox state AND the UnifiedRuleForm's advancedMode prop
     * must be synchronized IMMEDIATELY (no mismatch).
     */
    it('checkbox and form advancedMode stay in sync when toggling off (Bug 9-10)', async () => {
      // Start with advanced fields enabled
      wrapper = createWrapper({ advanced_fields: true })

      // Verify initial state: both checkbox and form should be true
      expect(wrapper.vm.localAdvancedFields).toBe(true)
      expect(wrapper.vm.advanced_fields).toBe(true)
      const form = wrapper.findComponent({ name: 'UnifiedRuleForm' })
      expect(form.props('advancedMode')).toBe(true)

      // User clicks checkbox to toggle OFF
      const checkbox = wrapper.find('[data-testid="advanced-fields-toggle"] input[type="checkbox"]')
      await checkbox.setChecked(false)
      await wrapper.vm.$nextTick()

      // REQUIREMENT: Both checkbox AND form should reflect the change immediately
      // There should be NO temporary mismatch
      expect(wrapper.vm.localAdvancedFields).toBe(false)

      // The form's advancedMode should ALSO be false immediately
      // Bug: Line 69 passes advanced_fields prop, not localAdvancedFields
      // This causes form to still show advanced_fields=true until parent updates
      expect(form.props('advancedMode')).toBe(false)
    })

    it('checkbox and form advancedMode stay in sync when toggling on (Bug 9-10)', async () => {
      // Start with advanced fields disabled
      wrapper = createWrapper({ advanced_fields: false })

      // Verify initial state
      expect(wrapper.vm.localAdvancedFields).toBe(false)
      expect(wrapper.vm.advanced_fields).toBe(false)
      const form = wrapper.findComponent({ name: 'UnifiedRuleForm' })
      expect(form.props('advancedMode')).toBe(false)

      // User clicks checkbox to enable (which shows confirmation dialog)
      wrapper.vm.localAdvancedFields = true
      wrapper.vm.onAdvancedFieldsToggle(true)
      await wrapper.vm.$nextTick()

      // User confirms in dialog
      wrapper.vm.confirmEnableAdvanced()
      await wrapper.vm.$nextTick()

      // After confirmation, localAdvancedFields should be true
      expect(wrapper.vm.localAdvancedFields).toBe(true)

      // The form's advancedMode should ALSO reflect this immediately
      // Bug: Form still bound to advanced_fields prop, not localAdvancedFields
      expect(form.props('advancedMode')).toBe(true)
    })
  })
})
