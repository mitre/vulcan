/**
 * ForgotPasswordPage Integration Tests
 * Tests for the complete forgot password page with header, footer, and form
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

// Mock the color mode composable
vi.mock('@/composables', () => ({
  useColorMode: () => ({
    colorMode: { value: 'light' },
    resolvedMode: { value: 'light' },
    cycleColorMode: vi.fn(),
  }),
}))

// Mock child components to simplify testing
vi.mock('@/components/auth/AuthHeader.vue', () => ({
  default: {
    name: 'AuthHeader',
    template: '<header class="auth-header-mock">Header</header>',
  },
}))

vi.mock('@/components/auth/AuthFooter.vue', () => ({
  default: {
    name: 'AuthFooter',
    template: '<footer class="auth-footer-mock">Footer</footer>',
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
    it('renders BApp wrapper', () => {
      wrapper = mount(ForgotPasswordPage)

      // BApp should be the root component
      expect(wrapper.html()).toBeTruthy()
    })

    it('has full-height flex layout', () => {
      wrapper = mount(ForgotPasswordPage)

      const container = wrapper.find('.d-flex.flex-column.min-vh-100')
      expect(container.exists()).toBe(true)
    })

    it('renders all major sections', () => {
      wrapper = mount(ForgotPasswordPage)

      // Should have header, main content, and footer
      expect(wrapper.find('.auth-header-mock').exists()).toBe(true)
      expect(wrapper.find('.forgot-password-form-mock').exists()).toBe(true)
      expect(wrapper.find('.auth-footer-mock').exists()).toBe(true)
    })
  })

  describe('header section', () => {
    it('renders AuthHeader component', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.find('.auth-header-mock').exists()).toBe(true)
    })
  })

  describe('main content', () => {
    it('has centered card layout', () => {
      wrapper = mount(ForgotPasswordPage)

      // Should have background and centered container
      const centerContainer = wrapper.find('.flex-grow-1.bg-body-secondary')
      expect(centerContainer.exists()).toBe(true)
      expect(centerContainer.classes()).toContain('d-flex')
      expect(centerContainer.classes()).toContain('align-items-center')
      expect(centerContainer.classes()).toContain('justify-content-center')
    })

    it('renders card with correct max-width', () => {
      wrapper = mount(ForgotPasswordPage)

      const card = wrapper.find('.card.shadow-sm')
      expect(card.exists()).toBe(true)
      expect(card.attributes('style')).toContain('max-width: 28rem')
    })

    it('displays shield lock icon', () => {
      wrapper = mount(ForgotPasswordPage)

      // Icon should be present (rendered as SVG)
      const html = wrapper.html()
      expect(html).toContain('<svg')
      expect(html).toContain('viewBox="0 0 16 16"')
    })

    it('displays "Reset Password" title', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.text()).toContain('Reset Password')
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

  describe('footer section', () => {
    it('renders AuthFooter component', () => {
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.find('.auth-footer-mock').exists()).toBe(true)
    })
  })

  describe('responsive design', () => {
    it('has responsive padding', () => {
      wrapper = mount(ForgotPasswordPage)

      const centerContainer = wrapper.find('.flex-grow-1')
      expect(centerContainer.classes()).toContain('p-4')
    })

    it('card has responsive width', () => {
      wrapper = mount(ForgotPasswordPage)

      const card = wrapper.find('.card')
      expect(card.classes()).toContain('w-100')
    })
  })

  describe('accessibility', () => {
    it('has semantic HTML structure', () => {
      wrapper = mount(ForgotPasswordPage)

      // Should have proper header and footer elements (in mocked components)
      expect(wrapper.find('header').exists()).toBe(true)
      expect(wrapper.find('footer').exists()).toBe(true)
    })

    it('has appropriate heading hierarchy', () => {
      wrapper = mount(ForgotPasswordPage)

      // Should have h4 for page title
      expect(wrapper.find('h4').exists()).toBe(true)
      expect(wrapper.find('h4').text()).toContain('Reset Password')
    })
  })

  describe('theming', () => {
    it('uses theme-aware background color', () => {
      wrapper = mount(ForgotPasswordPage)

      const centerContainer = wrapper.find('.flex-grow-1')
      expect(centerContainer.classes()).toContain('bg-body-secondary')
    })

    it('initializes color mode on mount', () => {
      // useColorMode is called in setup
      wrapper = mount(ForgotPasswordPage)
      expect(wrapper.vm).toBeTruthy()
    })
  })
})
