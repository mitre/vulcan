/**
 * ForgotPasswordForm Component Tests
 * Tests for forgot password form functionality
 */

import type { VueWrapper } from '@vue/test-utils'
import { flushPromises, mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import ForgotPasswordForm from '../ForgotPasswordForm.vue'

// Mock the toast composable
const mockToast = {
  success: vi.fn(),
  error: vi.fn(),
  info: vi.fn(),
  warning: vi.fn(),
}

vi.mock('@/composables/useToast', () => ({
  useAppToast: () => mockToast,
}))

// Mock fetch
global.fetch = vi.fn()

describe('forgotPasswordForm', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
    // Setup default CSRF token
    document.head.innerHTML = '<meta name="csrf-token" content="test-token">'
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders email input field', () => {
      wrapper = mount(ForgotPasswordForm)

      expect(wrapper.find('input[type="email"]').exists()).toBe(true)
      expect(wrapper.find('label').text()).toBe('Email')
    })

    it('renders submit button with correct text', () => {
      wrapper = mount(ForgotPasswordForm)

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.exists()).toBe(true)
      expect(submitButton.text()).toBe('Send Reset Instructions')
    })

    it('renders back to sign in link', () => {
      wrapper = mount(ForgotPasswordForm)

      const link = wrapper.find('a[href="/users/sign_in"]')
      expect(link.exists()).toBe(true)
      expect(link.text()).toBe('Back to sign in')
    })

    it('shows helper text', () => {
      wrapper = mount(ForgotPasswordForm)

      expect(wrapper.html()).toContain('We\'ll send password reset instructions to this email address')
    })
  })

  describe('form submission', () => {
    it('sends password reset request on submit', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: async () => ({}),
      } as Response)

      wrapper = mount(ForgotPasswordForm)

      // Fill in email
      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      // Submit form
      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      // Verify fetch was called with correct params
      expect(global.fetch).toHaveBeenCalledWith('/users/password', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': 'test-token',
        },
        body: JSON.stringify({
          user: {
            email: 'user@example.com',
          },
        }),
      })
    })

    it('shows success toast on successful request', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: async () => ({}),
      } as Response)

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect(mockToast.success).toHaveBeenCalledWith(
        'Password reset instructions sent to your email',
        'Check Your Email',
      )
    })

    it('clears email field after successful submission', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: async () => ({}),
      } as Response)

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect((emailInput.element as HTMLInputElement).value).toBe('')
    })

    it('shows error toast on failed request', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Email not found' }),
      } as Response)

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('unknown@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect(mockToast.error).toHaveBeenCalledWith(
        'Email not found',
        'Error',
      )
    })

    it('shows generic error on network failure', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockRejectedValueOnce(
        new Error('Network error'),
      )

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect(mockToast.error).toHaveBeenCalledWith(
        'Network error. Please try again.',
        'Error',
      )
    })
  })

  describe('loading state', () => {
    it('disables button while submitting', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockImplementationOnce(
        () => new Promise(resolve => setTimeout(resolve, 100)),
      )

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')

      // Button should be disabled during submission
      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.attributes('disabled')).toBeDefined()
    })

    it('shows loading text while submitting', async () => {
      ;(global.fetch as ReturnType<typeof vi.fn>).mockImplementationOnce(
        () => new Promise(resolve => setTimeout(resolve, 100)),
      )

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.text()).toBe('Sending...')
    })
  })

  describe('validation', () => {
    it('requires email field', () => {
      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('required')).toBeDefined()
    })

    it('has email type validation', () => {
      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('type')).toBe('email')
    })

    it('has autocomplete attribute', () => {
      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('autocomplete')).toBe('email')
    })
  })
})
