import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import RuleCommandBar from '@/components/rules/RuleCommandBar.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

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
        effectivePermissions: 'admin',
        currentUserId: 1,
        readOnly: false,
        activePanel: null,
        ...props
      },
      stubs: {
        CommentModal: true,
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

  describe('action buttons', () => {
    it('shows Clone button', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Clone')
    })

    it('shows Delete button for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      expect(wrapper.text()).toContain('Delete')
    })

    it('hides Delete button for non-admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'author' })
      expect(wrapper.text()).not.toContain('Delete')
    })

    it('shows Save button (via CommentModal)', () => {
      wrapper = createWrapper()
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const saveModal = modals.wrappers.find(m => m.props('buttonText') === 'Save')
      expect(saveModal).toBeTruthy()
    })

    it('shows Comment button (via CommentModal)', () => {
      wrapper = createWrapper()
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const commentModal = modals.wrappers.find(m => m.props('buttonText') === 'Comment')
      expect(commentModal).toBeTruthy()
    })

    it('shows Review button', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Review')
    })

    it('shows Lock button for admin when rule is not locked (via CommentModal)', () => {
      wrapper = createWrapper({
        effectivePermissions: 'admin',
        rule: { ...mockRule, locked: false }
      })
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const lockModal = modals.wrappers.find(m => m.props('buttonText') === 'Lock')
      expect(lockModal).toBeTruthy()
    })

    it('shows Unlock button for admin when rule is locked (via CommentModal)', () => {
      wrapper = createWrapper({
        effectivePermissions: 'admin',
        rule: { ...mockRule, locked: true }
      })
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const unlockModal = modals.wrappers.find(m => m.props('buttonText') === 'Unlock')
      expect(unlockModal).toBeTruthy()
    })

    it('hides Lock/Unlock buttons for non-admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'author' })
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const lockModal = modals.wrappers.find(
        m => m.props('buttonText') === 'Lock' || m.props('buttonText') === 'Unlock'
      )
      expect(lockModal).toBeFalsy()
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
    it('emits clone event when Clone button is clicked', async () => {
      wrapper = createWrapper()
      const cloneButton = wrapper.find('[variant="outline-info"]')
      await cloneButton.trigger('click')
      expect(wrapper.emitted('clone')).toBeTruthy()
    })

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

    it('emits open-review-modal when Review button is clicked', async () => {
      wrapper = createWrapper()
      const reviewButton = wrapper.findAll('b-button-stub').wrappers.find(
        btn => btn.text().includes('Review') && !btn.text().includes('Reviews')
      )
      await reviewButton.trigger('click')
      expect(wrapper.emitted('open-review-modal')).toBeTruthy()
    })

    it('emits delete event when Delete button is clicked', async () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      const deleteButton = wrapper.find('[variant="outline-danger"]')
      await deleteButton.trigger('click')
      expect(wrapper.emitted('delete')).toBeTruthy()
    })
  })

  describe('read-only mode', () => {
    it('disables Save button when rule is locked', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, locked: true }
      })
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const saveModal = modals.wrappers.find(m => m.props('buttonText') === 'Save')
      expect(saveModal).toBeTruthy()
      expect(saveModal.props('buttonDisabled')).toBe(true)
    })

    it('disables Save button when rule is under review', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, review_requestor_id: 123 }
      })
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const saveModal = modals.wrappers.find(m => m.props('buttonText') === 'Save')
      expect(saveModal).toBeTruthy()
      expect(saveModal.props('buttonDisabled')).toBe(true)
    })

    it('disables Delete button when rule is locked', () => {
      wrapper = createWrapper({
        effectivePermissions: 'admin',
        rule: { ...mockRule, locked: true }
      })
      const deleteButton = wrapper.find('[variant="outline-danger"]')
      expect(deleteButton.attributes('disabled')).toBe('true')
    })

    it('disables Lock button when rule is under review', () => {
      wrapper = createWrapper({
        effectivePermissions: 'admin',
        rule: { ...mockRule, review_requestor_id: 123 }
      })
      const modals = wrapper.findAllComponents({ name: 'CommentModal' })
      const lockModal = modals.wrappers.find(m => m.props('buttonText') === 'Lock')
      expect(lockModal).toBeTruthy()
      expect(lockModal.props('buttonDisabled')).toBe(true)
    })
  })

  describe('computed properties', () => {
    it('computes isReadOnly correctly when locked', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, locked: true }
      })
      expect(wrapper.vm.isReadOnly).toBe(true)
    })

    it('computes isReadOnly correctly when under review', () => {
      wrapper = createWrapper({
        rule: { ...mockRule, review_requestor_id: 123 }
      })
      expect(wrapper.vm.isReadOnly).toBe(true)
    })

    it('computes isReadOnly as false when neither locked nor under review', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.isReadOnly).toBe(false)
    })

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
