/**
 * LoginForm Component Tests
 * Tests for SPA login form (email/password)
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuthStore } from '@/stores'
import LoginForm from '../LoginForm.vue'

// Mock the toast composable
vi.mock('@/composables/useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

describe('loginForm', () => {
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
    it('renders email input', () => {
      wrapper = mount(LoginForm)
      expect(wrapper.find('input[type="email"]').exists()).toBe(true)
    })

    it('renders password input', () => {
      wrapper = mount(LoginForm)
      expect(wrapper.find('input[type="password"]').exists()).toBe(true)
    })

    it('renders submit button', () => {
      wrapper = mount(LoginForm)
      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.exists()).toBe(true)
      expect(submitButton.text()).toContain('Sign in')
    })

    it('renders forgot password link', () => {
      wrapper = mount(LoginForm)
      const link = wrapper.find('a[href="/users/password/new"]')
      expect(link.exists()).toBe(true)
      expect(link.text()).toContain('Forgot your password?')
    })

    it('has autocomplete enabled', () => {
      wrapper = mount(LoginForm)
      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[type="password"]')

      expect(emailInput.attributes('autocomplete')).toBe('email')
      expect(passwordInput.attributes('autocomplete')).toBe('current-password')
    })
  })

  describe('form validation', () => {
    it('requires email field', () => {
      wrapper = mount(LoginForm)
      const emailInput = wrapper.find('input[type="email"]')
      expect(emailInput.attributes('required')).toBeDefined()
    })

    it('requires password field', () => {
      wrapper = mount(LoginForm)
      const passwordInput = wrapper.find('input[type="password"]')
      expect(passwordInput.attributes('required')).toBeDefined()
    })
  })

  describe('form submission', () => {
    it('calls authStore.login on submit', async () => {
      const loginSpy = vi.spyOn(authStore, 'login').mockResolvedValue({
        data: { user: { id: 1, email: 'test@example.com', admin: false, name: 'Test' } },
        status: 200,
      })

      wrapper = mount(LoginForm)

      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[type="password"]')

      await emailInput.setValue('test@example.com')
      await passwordInput.setValue('password123')
      await wrapper.find('form').trigger('submit.prevent')

      expect(loginSpy).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      })
    })

    it('shows loading state during submission', async () => {
      vi.spyOn(authStore, 'login').mockImplementation(() => new Promise(() => {}))

      wrapper = mount(LoginForm)

      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[type="password"]')

      await emailInput.setValue('test@example.com')
      await passwordInput.setValue('password123')

      const submitButton = wrapper.find('button[type="submit"]')
      await wrapper.find('form').trigger('submit.prevent')

      // Should show loading text and be disabled
      expect(submitButton.text()).toContain('Signing in')
      expect(submitButton.attributes('disabled')).toBeDefined()
    })

    it('redirects to /projects on successful login', async () => {
      vi.spyOn(authStore, 'login').mockResolvedValue({
        data: { user: { id: 1, email: 'test@example.com', admin: false, name: 'Test' } },
        status: 200,
      })

      // Mock window.location
      delete (window as { location?: { href: string } }).location
      window.location = { href: '' } as Location

      wrapper = mount(LoginForm)

      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[type="password"]')

      await emailInput.setValue('test@example.com')
      await passwordInput.setValue('password123')
      await wrapper.find('form').trigger('submit.prevent')

      // Wait for async
      await wrapper.vm.$nextTick()
      await wrapper.vm.$nextTick()

      expect(window.location.href).toBe('/projects')
    })

    it('keeps loading false on error', async () => {
      vi.spyOn(authStore, 'login').mockRejectedValue({
        response: { data: { error: 'Invalid credentials' } },
      })

      wrapper = mount(LoginForm)

      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[type="password"]')

      await emailInput.setValue('test@example.com')
      await passwordInput.setValue('wrong')
      await wrapper.find('form').trigger('submit.prevent')

      // Wait for error handling
      await wrapper.vm.$nextTick()
      await wrapper.vm.$nextTick()

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.attributes('disabled')).toBeFalsy()
    })
  })

  describe('accessibility', () => {
    it('has labels for inputs', () => {
      wrapper = mount(LoginForm)

      const emailLabel = wrapper.find('label[for="email"]')
      const passwordLabel = wrapper.find('label[for="password"]')

      expect(emailLabel.exists()).toBe(true)
      expect(passwordLabel.exists()).toBe(true)
    })

    it('has placeholder text', () => {
      wrapper = mount(LoginForm)

      const emailInput = wrapper.find('input[type="email"]')
      const passwordInput = wrapper.find('input[type="password"]')

      expect(emailInput.attributes('placeholder')).toBe('Enter email')
      expect(passwordInput.attributes('placeholder')).toBe('Enter password')
    })
  })
})
