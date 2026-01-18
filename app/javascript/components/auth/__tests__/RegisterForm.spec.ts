/**
 * RegisterForm Component Tests
 * Tests for SPA registration form
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuthStore } from '@/stores'
import RegisterForm from '../RegisterForm.vue'

// Mock the toast composable
vi.mock('@/composables/useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

describe('registerForm', () => {
  let wrapper: VueWrapper
  let authStore: ReturnType<typeof useAuthStore>

  beforeEach(() => {
    setActivePinia(createPinia())
    authStore = useAuthStore()
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders name input', () => {
      wrapper = mount(RegisterForm)
      expect(wrapper.find('input[id="register-name"]').exists()).toBe(true)
    })

    it('renders email input', () => {
      wrapper = mount(RegisterForm)
      expect(wrapper.find('input[type="email"]').exists()).toBe(true)
    })

    it('renders password input', () => {
      wrapper = mount(RegisterForm)
      expect(wrapper.find('input[id="register-password"]').exists()).toBe(true)
    })

    it('renders password confirmation input', () => {
      wrapper = mount(RegisterForm)
      expect(wrapper.find('input[id="register-password-confirmation"]').exists()).toBe(true)
    })

    it('renders slack user id input', () => {
      wrapper = mount(RegisterForm)
      expect(wrapper.find('input[id="slack-user-id"]').exists()).toBe(true)
    })

    it('renders submit button', () => {
      wrapper = mount(RegisterForm)
      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.exists()).toBe(true)
      expect(submitButton.text()).toContain('Sign Up')
    })

    it('has autocomplete enabled', () => {
      wrapper = mount(RegisterForm)
      const nameInput = wrapper.find('input[id="register-name"]')
      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[id="register-password"]')
      const passwordConfirmInput = wrapper.find('input[id="register-password-confirmation"]')

      expect(nameInput.attributes('autocomplete')).toBe('name')
      expect(emailInput.attributes('autocomplete')).toBe('email')
      expect(passwordInput.attributes('autocomplete')).toBe('new-password')
      expect(passwordConfirmInput.attributes('autocomplete')).toBe('new-password')
    })
  })

  describe('form validation', () => {
    it('requires name field', () => {
      wrapper = mount(RegisterForm)
      const nameInput = wrapper.find('input[id="register-name"]')
      expect(nameInput.attributes('required')).toBeDefined()
    })

    it('requires email field', () => {
      wrapper = mount(RegisterForm)
      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('required')).toBeDefined()
    })

    it('requires password field', () => {
      wrapper = mount(RegisterForm)
      const passwordInput = wrapper.find('input[id="register-password"]')
      expect(passwordInput.attributes('required')).toBeDefined()
    })

    it('requires password confirmation field', () => {
      wrapper = mount(RegisterForm)
      const passwordConfirmInput = wrapper.find('input[id="register-password-confirmation"]')
      expect(passwordConfirmInput.attributes('required')).toBeDefined()
    })

    it('slack user id is optional', () => {
      wrapper = mount(RegisterForm)
      const slackInput = wrapper.find('input[id="slack-user-id"]')
      expect(slackInput.attributes('required')).toBeUndefined()
    })
  })

  describe('form submission', () => {
    it('calls authStore.register on submit', async () => {
      const registerSpy = vi.spyOn(authStore, 'register').mockResolvedValue({
        data: { success: true, user: { id: 1, email: 'test@example.com', admin: false, name: 'Test User' } },
        status: 201,
      })

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')
      await wrapper.find('form').trigger('submit.prevent')

      expect(registerSpy).toHaveBeenCalledWith({
        name: 'Test User',
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        slack_user_id: undefined,
      })
    })

    it('includes slack_user_id if provided', async () => {
      const registerSpy = vi.spyOn(authStore, 'register').mockResolvedValue({
        data: { success: true, user: { id: 1, email: 'test@example.com', admin: false, name: 'Test User' } },
        status: 201,
      })

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')
      await wrapper.find('input[id="slack-user-id"]').setValue('U12345678')
      await wrapper.find('form').trigger('submit.prevent')

      expect(registerSpy).toHaveBeenCalledWith({
        name: 'Test User',
        email: 'test@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        slack_user_id: 'U12345678',
      })
    })

    it('shows loading state during submission', async () => {
      vi.spyOn(authStore, 'register').mockImplementation(() => new Promise(() => {}))

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')

      const submitButton = wrapper.find('button[type="submit"]')
      await wrapper.find('form').trigger('submit.prevent')

      expect(submitButton.text()).toContain('Creating account')
      expect(submitButton.attributes('disabled')).toBeDefined()
    })

    it('clears form on successful registration', async () => {
      vi.spyOn(authStore, 'register').mockResolvedValue({
        data: { success: true, user: { id: 1, email: 'test@example.com', admin: false, name: 'Test User' } },
        status: 201,
      })

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')
      await wrapper.find('input[id="slack-user-id"]').setValue('U12345678')
      await wrapper.find('form').trigger('submit.prevent')

      await wrapper.vm.$nextTick()
      await wrapper.vm.$nextTick()

      expect((wrapper.find('input[id="register-name"]').element as HTMLInputElement).value).toBe('')
      expect((wrapper.find('input[type="email"]').element as HTMLInputElement).value).toBe('')
      expect((wrapper.find('input[id="register-password"]').element as HTMLInputElement).value).toBe('')
      expect((wrapper.find('input[id="register-password-confirmation"]').element as HTMLInputElement).value).toBe('')
      expect((wrapper.find('input[id="slack-user-id"]').element as HTMLInputElement).value).toBe('')
    })

    it('emits switchToLogin on successful registration', async () => {
      vi.spyOn(authStore, 'register').mockResolvedValue({
        data: { success: true, user: { id: 1, email: 'test@example.com', admin: false, name: 'Test User' } },
        status: 201,
      })

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')
      await wrapper.find('form').trigger('submit.prevent')

      await wrapper.vm.$nextTick()
      await wrapper.vm.$nextTick()

      expect(wrapper.emitted('switchToLogin')).toBeTruthy()
    })

    it('keeps loading false on error', async () => {
      vi.spyOn(authStore, 'register').mockRejectedValue({
        response: { data: { error: 'Email already taken' } },
      })

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')
      await wrapper.find('form').trigger('submit.prevent')

      await wrapper.vm.$nextTick()
      await wrapper.vm.$nextTick()

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.attributes('disabled')).toBeFalsy()
    })
  })

  describe('client-side validation', () => {
    it('validates name is not empty', async () => {
      const registerSpy = vi.spyOn(authStore, 'register')

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('   ')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('password123')
      await wrapper.find('form').trigger('submit.prevent')

      expect(registerSpy).not.toHaveBeenCalled()
    })

    it('validates passwords match', async () => {
      const registerSpy = vi.spyOn(authStore, 'register')

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('password123')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('different')
      await wrapper.find('form').trigger('submit.prevent')

      expect(registerSpy).not.toHaveBeenCalled()
    })

    it('validates password length (min 6 characters)', async () => {
      const registerSpy = vi.spyOn(authStore, 'register')

      wrapper = mount(RegisterForm)

      await wrapper.find('input[id="register-name"]').setValue('Test User')
      await wrapper.find('input[type="email"]').setValue('test@example.com')
      await wrapper.find('input[id="register-password"]').setValue('pass')
      await wrapper.find('input[id="register-password-confirmation"]').setValue('pass')
      await wrapper.find('form').trigger('submit.prevent')

      expect(registerSpy).not.toHaveBeenCalled()
    })
  })

  describe('accessibility', () => {
    it('has labels for all inputs', () => {
      wrapper = mount(RegisterForm)

      expect(wrapper.find('label[for="register-name"]').exists()).toBe(true)
      expect(wrapper.find('label[for="register-email"]').exists()).toBe(true)
      expect(wrapper.find('label[for="register-password"]').exists()).toBe(true)
      expect(wrapper.find('label[for="register-password-confirmation"]').exists()).toBe(true)
      expect(wrapper.find('label[for="slack-user-id"]').exists()).toBe(true)
    })

    it('has placeholder text', () => {
      wrapper = mount(RegisterForm)

      expect(wrapper.find('input[id="register-name"]').attributes('placeholder')).toBe('Enter your full name')
      expect(wrapper.find('input[type="email"]').attributes('placeholder')).toBe('Enter email')
      // Password inputs are wrapped in PasswordInput component
      expect(wrapper.find('input[id="register-password"]').attributes('placeholder')).toBe('Enter password')
      expect(wrapper.find('input[id="register-password-confirmation"]').attributes('placeholder')).toBe('Confirm password')
      expect(wrapper.find('input[id="slack-user-id"]').attributes('placeholder')).toBe('Enter Slack user ID (optional)')
    })
  })
})
