/**
 * EmailConfirmationPage Integration Tests
 * Tests for the complete email confirmation page
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import EmailConfirmationPage from '../EmailConfirmationPage.vue'

// Mock child components to simplify testing
vi.mock('@/components/auth/EmailConfirmationForm.vue', () => ({
  default: {
    name: 'EmailConfirmationForm',
    template: '<form class="email-confirmation-form-mock"><input type="email" /><button>Submit</button></form>',
  },
}))

vi.mock('@/components/shared/PageContainer.vue', () => ({
  default: {
    name: 'PageContainer',
    template: '<div class="page-container-mock"><slot /></div>',
  },
}))

describe('emailConfirmationPage', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('page structure', () => {
    it('renders PageContainer wrapper', () => {
      wrapper = mount(EmailConfirmationPage)
      expect(wrapper.find('.page-container-mock').exists()).toBe(true)
    })

    it('has centered card layout', () => {
      wrapper = mount(EmailConfirmationPage)

      const centerContainer = wrapper.find('.d-flex.align-items-center.justify-content-center')
      expect(centerContainer.exists()).toBe(true)
      expect(centerContainer.attributes('style')).toContain('min-height: 60vh')
    })

    it('renders card with correct max-width', () => {
      wrapper = mount(EmailConfirmationPage)

      const card = wrapper.find('.card.shadow-sm')
      expect(card.exists()).toBe(true)
      expect(card.attributes('style')).toContain('max-width: 28rem')
    })
  })

  describe('content', () => {
    it('displays envelope check icon', () => {
      wrapper = mount(EmailConfirmationPage)

      // Icon should be present (rendered as SVG)
      const html = wrapper.html()
      expect(html).toContain('<svg')
      expect(html).toContain('viewBox="0 0 16 16"')
    })

    it('displays "Resend Confirmation" title', () => {
      wrapper = mount(EmailConfirmationPage)
      expect(wrapper.text()).toContain('Resend Confirmation')
    })

    it('displays instructional text', () => {
      wrapper = mount(EmailConfirmationPage)
      expect(wrapper.text()).toContain('Enter your email to receive confirmation instructions')
    })

    it('renders EmailConfirmationForm component', () => {
      wrapper = mount(EmailConfirmationPage)
      expect(wrapper.find('.email-confirmation-form-mock').exists()).toBe(true)
    })
  })

  describe('styling', () => {
    it('uses primary color for icon', () => {
      wrapper = mount(EmailConfirmationPage)

      const icon = wrapper.find('.text-primary')
      expect(icon.exists()).toBe(true)
    })

    it('has proper card padding', () => {
      wrapper = mount(EmailConfirmationPage)

      const cardBody = wrapper.find('.card-body')
      expect(cardBody.classes()).toContain('p-4')
    })

    it('has responsive card width', () => {
      wrapper = mount(EmailConfirmationPage)

      const card = wrapper.find('.card')
      expect(card.classes()).toContain('w-100')
    })
  })

  describe('accessibility', () => {
    it('has appropriate heading hierarchy', () => {
      wrapper = mount(EmailConfirmationPage)

      // Should have h4 for page title
      expect(wrapper.find('h4').exists()).toBe(true)
      expect(wrapper.find('h4').text()).toContain('Resend Confirmation')
    })

    it('uses semantic HTML structure', () => {
      wrapper = mount(EmailConfirmationPage)

      // Should have form element (in mocked component)
      expect(wrapper.find('form').exists()).toBe(true)
    })
  })
})
