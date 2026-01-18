/**
 * PasswordResetEditPage Integration Tests
 * Tests for the complete password reset page
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import PasswordResetEditPage from '../PasswordResetEditPage.vue'

// Mock child components
vi.mock('@/components/auth/PasswordResetForm.vue', () => ({
  default: {
    name: 'PasswordResetForm',
    template: '<form class="password-reset-form-mock"><input type="password" /><button>Submit</button></form>',
  },
}))

vi.mock('@/components/shared/PageContainer.vue', () => ({
  default: {
    name: 'PageContainer',
    template: '<div class="page-container-mock"><slot /></div>',
  },
}))

describe('passwordResetEditPage', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('page structure', () => {
    it('renders PageContainer wrapper', () => {
      wrapper = mount(PasswordResetEditPage)
      expect(wrapper.find('.page-container-mock').exists()).toBe(true)
    })

    it('has centered card layout', () => {
      wrapper = mount(PasswordResetEditPage)

      const centerContainer = wrapper.find('.d-flex.align-items-center.justify-content-center')
      expect(centerContainer.exists()).toBe(true)
      expect(centerContainer.attributes('style')).toContain('min-height: 60vh')
    })

    it('renders card with correct max-width', () => {
      wrapper = mount(PasswordResetEditPage)

      const card = wrapper.find('.card.shadow-sm')
      expect(card.exists()).toBe(true)
      expect(card.attributes('style')).toContain('max-width: 28rem')
    })
  })

  describe('content', () => {
    it('displays key icon', () => {
      wrapper = mount(PasswordResetEditPage)

      // Icon should be present (rendered as SVG)
      const html = wrapper.html()
      expect(html).toContain('<svg')
      expect(html).toContain('viewBox="0 0 16 16"')
    })

    it('displays "Reset Password" title', () => {
      wrapper = mount(PasswordResetEditPage)
      expect(wrapper.text()).toContain('Reset Password')
    })

    it('displays instructional text', () => {
      wrapper = mount(PasswordResetEditPage)
      expect(wrapper.text()).toContain('Choose a new password for your account')
    })

    it('renders PasswordResetForm component', () => {
      wrapper = mount(PasswordResetEditPage)
      expect(wrapper.find('.password-reset-form-mock').exists()).toBe(true)
    })
  })

  describe('styling', () => {
    it('uses primary color for icon', () => {
      wrapper = mount(PasswordResetEditPage)

      const icon = wrapper.find('.text-primary')
      expect(icon.exists()).toBe(true)
    })

    it('has proper card padding', () => {
      wrapper = mount(PasswordResetEditPage)

      const cardBody = wrapper.find('.card-body')
      expect(cardBody.classes()).toContain('p-4')
    })

    it('has responsive card width', () => {
      wrapper = mount(PasswordResetEditPage)

      const card = wrapper.find('.card')
      expect(card.classes()).toContain('w-100')
    })
  })

  describe('accessibility', () => {
    it('has appropriate heading hierarchy', () => {
      wrapper = mount(PasswordResetEditPage)

      expect(wrapper.find('h4').exists()).toBe(true)
      expect(wrapper.find('h4').text()).toContain('Reset Password')
    })

    it('uses semantic HTML structure', () => {
      wrapper = mount(PasswordResetEditPage)
      expect(wrapper.find('form').exists()).toBe(true)
    })
  })
})
