/**
 * EmailConfirmationForm Component Tests
 * Tests for resend confirmation instructions form
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import EmailConfirmationForm from '../EmailConfirmationForm.vue'

// Mock the useAuth composable
const mockResendConfirmation = vi.fn()
const mockLoading = vi.fn(() => false)

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    resendConfirmation: mockResendConfirmation,
    get loading() { return mockLoading() },
  }),
}))

describe('emailConfirmationForm', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
    mockLoading.mockReturnValue(false)
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders email input', () => {
      wrapper = mount(EmailConfirmationForm)
      expect(wrapper.find('input[type="email"]').exists()).toBe(true)
    })

    it('renders submit button', () => {
      wrapper = mount(EmailConfirmationForm)
      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.exists()).toBe(true)
      expect(submitButton.text()).toContain('Resend Confirmation')
    })

    it('renders back to sign in link', () => {
      wrapper = mount(EmailConfirmationForm)
      const link = wrapper.find('a[href="/users/sign_in"]')
      expect(link.exists()).toBe(true)
      expect(link.text()).toContain('Back to sign in')
    })

    it('displays helper text', () => {
      wrapper = mount(EmailConfirmationForm)
      expect(wrapper.text()).toContain('We\'ll send confirmation instructions to this email address')
    })

    it('has autocomplete enabled', () => {
      wrapper = mount(EmailConfirmationForm)
      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('autocomplete')).toBe('email')
    })
  })

  describe('form validation', () => {
    it('requires email field', () => {
      wrapper = mount(EmailConfirmationForm)
      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('required')).toBeDefined()
    })
  })

  describe('form submission', () => {
    it('calls resendConfirmation with email on submit', async () => {
      mockResendConfirmation.mockResolvedValue(undefined)

      wrapper = mount(EmailConfirmationForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('test@example.com')
      await wrapper.find('form').trigger('submit.prevent')

      expect(mockResendConfirmation).toHaveBeenCalledWith('test@example.com')
    })

    it('clears email field after submission', async () => {
      mockResendConfirmation.mockResolvedValue(undefined)

      wrapper = mount(EmailConfirmationForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('test@example.com')
      await wrapper.find('form').trigger('submit.prevent')

      await wrapper.vm.$nextTick()

      expect((emailInput.element as HTMLInputElement).value).toBe('')
    })

    it('shows loading state during submission', async () => {
      mockLoading.mockReturnValue(true)

      wrapper = mount(EmailConfirmationForm)

      const submitButton = wrapper.find('button[type="submit"]')

      expect(submitButton.text()).toContain('Sending')
      expect(submitButton.attributes('disabled')).toBeDefined()
    })
  })

  describe('accessibility', () => {
    it('has label for email input', () => {
      wrapper = mount(EmailConfirmationForm)

      const emailLabel = wrapper.find('label[for="email"]')
      expect(emailLabel.exists()).toBe(true)
      expect(emailLabel.text()).toContain('Email')
    })

    it('has placeholder text', () => {
      wrapper = mount(EmailConfirmationForm)

      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('placeholder')).toBe('Enter your email')
    })
  })
})
