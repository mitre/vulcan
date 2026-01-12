/**
 * AccountUnlockForm Component Tests
 * Tests for resend unlock instructions form
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import AccountUnlockForm from '../AccountUnlockForm.vue'

// Mock the useAuth composable
const mockResendUnlock = vi.fn()
const mockLoading = vi.fn(() => false)

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    resendUnlock: mockResendUnlock,
    get loading() { return mockLoading() },
  }),
}))

describe('accountUnlockForm', () => {
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
      wrapper = mount(AccountUnlockForm)
      expect(wrapper.find('input[type="email"]').exists()).toBe(true)
    })

    it('renders submit button', () => {
      wrapper = mount(AccountUnlockForm)
      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.exists()).toBe(true)
      expect(submitButton.text()).toContain('Resend Unlock Instructions')
    })

    it('renders back to sign in link', () => {
      wrapper = mount(AccountUnlockForm)
      const link = wrapper.find('a[href="/users/sign_in"]')
      expect(link.exists()).toBe(true)
      expect(link.text()).toContain('Back to sign in')
    })

    it('displays helper text', () => {
      wrapper = mount(AccountUnlockForm)
      expect(wrapper.text()).toContain('We\'ll send unlock instructions to this email address')
    })

    it('has autocomplete enabled', () => {
      wrapper = mount(AccountUnlockForm)
      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('autocomplete')).toBe('email')
    })
  })

  describe('form validation', () => {
    it('requires email field', () => {
      wrapper = mount(AccountUnlockForm)
      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('required')).toBeDefined()
    })
  })

  describe('form submission', () => {
    it('calls resendUnlock with email on submit', async () => {
      mockResendUnlock.mockResolvedValue(undefined)

      wrapper = mount(AccountUnlockForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('test@example.com')
      await wrapper.find('form').trigger('submit.prevent')

      expect(mockResendUnlock).toHaveBeenCalledWith('test@example.com')
    })

    it('clears email field after submission', async () => {
      mockResendUnlock.mockResolvedValue(undefined)

      wrapper = mount(AccountUnlockForm)

      const emailInput = wrapper.find('input[type="email"]')
      await emailInput.setValue('test@example.com')
      await wrapper.find('form').trigger('submit.prevent')

      await wrapper.vm.$nextTick()

      expect((emailInput.element as HTMLInputElement).value).toBe('')
    })

    it('shows loading state during submission', async () => {
      mockLoading.mockReturnValue(true)

      wrapper = mount(AccountUnlockForm)

      const submitButton = wrapper.find('button[type="submit"]')

      expect(submitButton.text()).toContain('Sending')
      expect(submitButton.attributes('disabled')).toBeDefined()
    })
  })

  describe('accessibility', () => {
    it('has label for email input', () => {
      wrapper = mount(AccountUnlockForm)

      const emailLabel = wrapper.find('label[for="email"]')
      expect(emailLabel.exists()).toBe(true)
      expect(emailLabel.text()).toContain('Email')
    })

    it('has placeholder text', () => {
      wrapper = mount(AccountUnlockForm)

      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('placeholder')).toBe('Enter your email')
    })
  })
})
