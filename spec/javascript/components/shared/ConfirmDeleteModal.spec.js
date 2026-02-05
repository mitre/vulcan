import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import ConfirmDeleteModal from '@/components/shared/ConfirmDeleteModal.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * ConfirmDeleteModal Component Tests
 *
 * REQUIREMENTS:
 *
 * 1. REUSABLE ACROSS APP:
 *    - Works for projects, components, any item type
 *    - Configurable messages and button text
 *
 * 2. CONFIRMATION STATE:
 *    - Shows item name
 *    - Shows warning message
 *    - Cancel closes modal
 *    - Confirm emits event
 *
 * 3. LOADING STATE:
 *    - Shows spinner when isDeleting=true
 *    - Shows "Removing..." message
 *    - Disables buttons during delete
 *
 * 4. V-MODEL SUPPORT:
 *    - Controlled by visible prop
 *    - Emits update:visible
 */
describe('ConfirmDeleteModal', () => {
  let wrapper

  const createWrapper = (props = {}) => {
    return mount(ConfirmDeleteModal, {
      localVue,
      propsData: {
        visible: true,
        itemName: 'Test Item',
        itemType: 'project',
        ...props
      },
      stubs: {
        'b-modal': {
          template: `
            <div class="modal" :class="{ 'd-block': visible, 'd-none': !visible }">
              <div class="modal-header">{{ title }}</div>
              <slot></slot>
              <slot name="modal-footer"></slot>
            </div>
          `,
          props: ['visible', 'title', 'centered', 'headerBgVariant', 'headerTextVariant']
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
  // CONFIRMATION STATE
  // ==========================================
  describe('confirmation state', () => {
    it('shows item name', () => {
      wrapper = createWrapper({ itemName: 'My Project' })
      expect(wrapper.text()).toContain('My Project')
    })

    it('computes default confirmation message based on item type', () => {
      wrapper = createWrapper({ itemType: 'project' })
      expect(wrapper.vm.displayConfirmMessage).toContain('Are you sure you want to remove this project')
    })

    it('shows custom confirmation message', () => {
      wrapper = createWrapper({ confirmMessage: 'Custom warning here' })
      expect(wrapper.text()).toContain('Custom warning here')
    })

    it('shows warning message when provided', () => {
      wrapper = createWrapper({ warningMessage: 'This cannot be undone!' })
      expect(wrapper.text()).toContain('This cannot be undone!')
    })

    it('Cancel button emits cancel and closes modal', async () => {
      wrapper = createWrapper()
      const cancelBtn = wrapper.find('[data-testid="cancel-delete-btn"]')
      await cancelBtn.trigger('click')

      expect(wrapper.emitted('cancel')).toBeTruthy()
      expect(wrapper.emitted('update:visible')[0]).toEqual([false])
    })

    it('Confirm button emits confirm', async () => {
      wrapper = createWrapper()
      const confirmBtn = wrapper.find('[data-testid="confirm-delete-btn"]')
      await confirmBtn.trigger('click')

      expect(wrapper.emitted('confirm')).toBeTruthy()
    })
  })

  // ==========================================
  // LOADING STATE
  // ==========================================
  describe('loading state', () => {
    it('computes displayDeletingMessage based on itemType', () => {
      wrapper = createWrapper({ itemType: 'project' })
      expect(wrapper.vm.displayDeletingMessage).toBe('Removing project...')
    })

    it('uses custom deleting message when provided', () => {
      wrapper = createWrapper({ deletingMessage: 'Please wait...' })
      expect(wrapper.vm.displayDeletingMessage).toBe('Please wait...')
    })

    it('disables Cancel button when isDeleting', () => {
      wrapper = createWrapper({ isDeleting: true })
      const cancelBtn = wrapper.find('[data-testid="cancel-delete-btn"]')
      expect(cancelBtn.attributes('disabled')).toBeDefined()
    })

    it('disables Confirm button when isDeleting', () => {
      wrapper = createWrapper({ isDeleting: true })
      const confirmBtn = wrapper.find('[data-testid="confirm-delete-btn"]')
      expect(confirmBtn.attributes('disabled')).toBeDefined()
    })

    it('shows Removing... text on button when isDeleting', () => {
      wrapper = createWrapper({ isDeleting: true })
      const confirmBtn = wrapper.find('[data-testid="confirm-delete-btn"]')
      expect(confirmBtn.text()).toContain('Removing')
    })
  })

  // ==========================================
  // TITLE
  // ==========================================
  describe('title', () => {
    it('shows default title based on item type', () => {
      wrapper = createWrapper({ itemType: 'project' })
      expect(wrapper.vm.modalTitle).toBe('Remove Project')
    })

    it('shows custom title when provided', () => {
      wrapper = createWrapper({ title: 'Delete Component?' })
      expect(wrapper.vm.modalTitle).toBe('Delete Component?')
    })

    it('capitalizes item type in default title', () => {
      wrapper = createWrapper({ itemType: 'component' })
      expect(wrapper.vm.modalTitle).toBe('Remove Component')
    })
  })

  // ==========================================
  // BUTTON TEXT
  // ==========================================
  describe('button text', () => {
    it('shows default button text', () => {
      wrapper = createWrapper()
      const confirmBtn = wrapper.find('[data-testid="confirm-delete-btn"]')
      expect(confirmBtn.text()).toContain('Remove')
    })

    it('shows custom button text', () => {
      wrapper = createWrapper({ confirmButtonText: 'Delete Forever' })
      const confirmBtn = wrapper.find('[data-testid="confirm-delete-btn"]')
      expect(confirmBtn.text()).toContain('Delete Forever')
    })

    it('shows "Removing..." when isDeleting', () => {
      wrapper = createWrapper({ isDeleting: true })
      const confirmBtn = wrapper.find('[data-testid="confirm-delete-btn"]')
      expect(confirmBtn.text()).toContain('Removing')
    })
  })

  // ==========================================
  // V-MODEL
  // ==========================================
  describe('v-model support', () => {
    it('modal is visible when visible prop is true', () => {
      wrapper = createWrapper({ visible: true })
      expect(wrapper.find('.modal').classes()).toContain('d-block')
    })

    it('modal is hidden when visible prop is false', () => {
      wrapper = createWrapper({ visible: false })
      expect(wrapper.find('.modal').classes()).toContain('d-none')
    })
  })
})
