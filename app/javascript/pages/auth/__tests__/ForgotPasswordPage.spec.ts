/**
 * ForgotPasswordPage Integration Tests
 *
 * Requirements:
 * - Page uses PageContainer for consistent layout with rest of SPA
 * - Centered card (max-width 28rem) with shadow
 * - Shield-lock icon, "Forgot Password?" title, instructional text
 * - Renders ForgotPasswordForm for email submission
 * - No standalone AuthHeader/AuthFooter (SPA layout provides those)
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import ForgotPasswordPage from '../ForgotPasswordPage.vue'

// Mock the toast composable
vi.mock('@/composables/useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

// Mock child components
vi.mock('@/components/shared/PageContainer.vue', () => ({
  default: {
    name: 'PageContainer',
    template: '<div class="page-container-mock"><slot /></div>',
  },
}))

vi.mock('@/components/auth/ForgotPasswordForm.vue', () => ({
  default: {
    name: 'ForgotPasswordForm',
    template: '<form class="forgot-password-form-mock"><input type="email" /><button>Submit</button></form>',
  },
}))

describe('forgotPasswordPage', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('page structure', () => {
    it('uses PageContainer for layout', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.find('.page-container-mock').exists()).toBe(true)
    })

    it('has centered flex layout', () => {
      wrapper = mount(ForgotPasswordPage)
      const flexContainer = wrapper.find('.d-flex.align-items-center.justify-content-center')
      expect(flexContainer.exists()).toBe(true)
    })
  })

  describe('main content', () => {
    it('renders card with correct max-width', () => {
      wrapper = mount(ForgotPasswordPage)
      const card = wrapper.find('.card.shadow-sm')
      expect(card.exists()).toBe(true)
      expect(card.attributes('style')).toContain('max-width: 28rem')
    })

    it('card has full width class', () => {
      wrapper = mount(ForgotPasswordPage)
      const card = wrapper.find('.card')
      expect(card.classes()).toContain('w-100')
    })

    it('displays shield lock icon', () => {
      wrapper = mount(ForgotPasswordPage)
      const html = wrapper.html()
      expect(html).toContain('<svg')
      expect(html).toContain('viewBox="0 0 16 16"')
    })

    it('displays "Forgot Password?" title', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.text()).toContain('Forgot Password?')
    })

    it('displays instructional text', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.text()).toContain('Enter your email to receive reset instructions')
    })

    it('renders ForgotPasswordForm component', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.find('.forgot-password-form-mock').exists()).toBe(true)
    })
  })

  describe('accessibility', () => {
    it('has h4 heading with page title', () => {
      wrapper = mount(ForgotPasswordPage)
      const heading = wrapper.find('h4')
      expect(heading.exists()).toBe(true)
      expect(heading.text()).toContain('Forgot Password?')
    })

    it('has centered text section for title and instructions', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.find('.text-center').exists()).toBe(true)
    })
  })
})
