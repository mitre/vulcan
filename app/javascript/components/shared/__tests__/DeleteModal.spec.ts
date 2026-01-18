import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import DeleteModal from '../DeleteModal.vue'

describe('deleteModal', () => {
  const defaultProps = {
    modelValue: true,
  }

  const BModalStub = {
    template: `
      <div v-if="modelValue" class="modal-stub">
        <div class="modal-title">{{ title }}</div>
        <slot />
        <div class="modal-footer"><slot name="footer" /></div>
      </div>
    `,
    props: ['modelValue', 'title'],
    emits: ['update:modelValue', 'hidden'],
  }

  describe('rendering', () => {
    it('renders when modelValue is true', () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.modal-stub').exists()).toBe(true)
    })

    it('shows default delete message', () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.text()).toContain('Are you sure you want to delete')
      expect(wrapper.text()).toContain('this item')
    })

    it('shows item name when provided', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          itemName: 'Test Project',
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.text()).toContain('Test Project')
    })

    it('shows custom message when provided', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          message: 'Custom delete message',
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.text()).toContain('Custom delete message')
    })

    it('shows danger text when provided', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          dangerText: 'This will delete all related data!',
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.text()).toContain('This will delete all related data!')
    })

    it('shows cannot be undone warning', () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.text()).toContain('This action cannot be undone')
    })
  })

  describe('buttons', () => {
    it('shows default button text', () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.btn-secondary').text()).toBe('Cancel')
      expect(wrapper.find('.btn-danger').text()).toBe('Delete')
    })

    it('uses custom button text', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          confirmButtonText: 'Remove',
          cancelButtonText: 'Go Back',
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.btn-secondary').text()).toBe('Go Back')
      expect(wrapper.find('.btn-danger').text()).toBe('Remove')
    })

    it('disables confirm button when loading', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          loading: true,
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.btn-danger').attributes('disabled')).toBeDefined()
    })

    it('shows spinner when loading', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          loading: true,
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.spinner-border').exists()).toBe(true)
    })
  })

  describe('events', () => {
    it('emits confirm on confirm button click', async () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      await wrapper.find('.btn-danger').trigger('click')
      expect(wrapper.emitted('confirm')).toBeTruthy()
    })

    it('emits cancel and update:modelValue on cancel button click', async () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      await wrapper.find('.btn-secondary').trigger('click')
      expect(wrapper.emitted('cancel')).toBeTruthy()
      expect(wrapper.emitted('update:modelValue')).toBeTruthy()
      expect(wrapper.emitted('update:modelValue')![0]).toEqual([false])
    })
  })

  describe('title', () => {
    it('uses default title', () => {
      const wrapper = mount(DeleteModal, {
        props: defaultProps,
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.modal-title').text()).toBe('Confirm Delete')
    })

    it('uses custom title', () => {
      const wrapper = mount(DeleteModal, {
        props: {
          ...defaultProps,
          title: 'Remove Project',
        },
        global: {
          stubs: {
            BModal: BModalStub,
          },
        },
      })

      expect(wrapper.find('.modal-title').text()).toBe('Remove Project')
    })
  })
})
