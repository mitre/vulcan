/**
 * ForgotPasswordForm Component Tests
 * Tests for forgot password form functionality
 */

import type { VueWrapper } from '@vue/test-utils'
import { flushPromises, mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import ForgotPasswordForm from '../ForgotPasswordForm.vue'

// Mock the auth composable
const mockRequestPasswordReset = vi.fn()
let mockLoadingValue = false

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    requestPasswordReset: mockRequestPasswordReset,
    loading: {
      get value() {
        return mockLoadingValue
      },
      set value(val) {
        mockLoadingValue = val
      },
    },
  }),
}))

describe('forgotPasswordForm', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
    mockLoadingValue = false
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

    it('renders submit button', () => {
      wrapper = mount(ForgotPasswordForm)

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.exists()).toBe(true)
      expect(submitButton.attributes('type')).toBe('submit')
      // Button text is tested in 'loading state' tests
    })

    it('renders back to sign in link', () => {
      wrapper = mount(ForgotPasswordForm, {
        global: {
          stubs: {
            RouterLink: {
              template: '<a :href="to"><slot /></a>',
              props: ['to'],
            },
          },
        },
      })

      const link = wrapper.find('a')
      expect(link.exists()).toBe(true)
      expect(link.text()).toBe('Back to sign in')
    })

    it('shows helper text', () => {
      wrapper = mount(ForgotPasswordForm)

      expect(wrapper.html()).toContain('We\'ll send password reset instructions to this email address')
    })
  })

  describe('form submission', () => {
    it('calls requestPasswordReset on submit', async () => {
      mockRequestPasswordReset.mockResolvedValueOnce(true)

      wrapper = mount(ForgotPasswordForm)

      // Fill in email
      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      // Submit form
      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      // Verify composable was called with correct email
      expect(mockRequestPasswordReset).toHaveBeenCalledWith('user@example.com')
    })

    it('handles successful request', async () => {
      mockRequestPasswordReset.mockResolvedValueOnce(true)

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect(mockRequestPasswordReset).toHaveBeenCalledWith('user@example.com')
    })

    it('clears email field after submission', async () => {
      mockRequestPasswordReset.mockResolvedValueOnce(true)

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect((emailInput.element as HTMLInputElement).value).toBe('')
    })

    it('handles failed request', async () => {
      mockRequestPasswordReset.mockResolvedValueOnce(false)

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('unknown@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect(mockRequestPasswordReset).toHaveBeenCalledWith('unknown@example.com')
      // Toast error is shown by composable, not component
    })

    it('handles network errors', async () => {
      mockRequestPasswordReset.mockRejectedValueOnce(new Error('Network error'))

      wrapper = mount(ForgotPasswordForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('user@example.com')

      const form = wrapper.find('form')
      await form.trigger('submit')
      await flushPromises()

      expect(mockRequestPasswordReset).toHaveBeenCalledWith('user@example.com')
      // Toast error is shown by composable, not component
    })
  })

  describe('loading state', () => {
    it('disables button while submitting', async () => {
      mockLoadingValue = true
      wrapper = mount(ForgotPasswordForm)

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.attributes('disabled')).toBeDefined()
    })

    it('shows loading text while submitting', async () => {
      mockLoadingValue = true
      wrapper = mount(ForgotPasswordForm)

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
