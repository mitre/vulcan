/**
 * PasswordInput Component Tests
 * Tests for password input with show/hide toggle and strength indicator
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it } from 'vitest'
import PasswordInput from '../PasswordInput.vue'

describe('passwordInput', () => {
  let wrapper: VueWrapper

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders password input field', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
        },
      })

      expect(wrapper.find('input[type="password"]').exists()).toBe(true)
      // Label includes asterisk when required (default is true)
      expect(wrapper.find('label').text()).toBe('Password *')
    })

    it('renders toggle visibility button', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
        },
      })

      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.exists()).toBe(true)
    })

    it('does not show strength indicator by default', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
        },
      })

      expect(wrapper.find('.progress').exists()).toBe(false)
    })

    it('shows strength indicator when showStrength is true', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: 'Test123!',
          showStrength: true,
        },
      })

      expect(wrapper.find('.progress').exists()).toBe(true)
    })

    it('renders hint text when provided', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          hint: 'Forgot password?',
        },
      })

      expect(wrapper.html()).toContain('Forgot password?')
    })
  })

  describe('show/hide toggle', () => {
    beforeEach(() => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: 'secret123',
        },
      })
    })

    it('starts with password hidden (type="password")', () => {
      const input = wrapper.find('input')
      expect(input.attributes('type')).toBe('password')
    })

    it('toggles to text type when button clicked', async () => {
      const toggleButton = wrapper.find('button[type="button"]')
      await toggleButton.trigger('click')

      const input = wrapper.find('input')
      expect(input.attributes('type')).toBe('text')
    })

    it('toggles back to password type when clicked again', async () => {
      const toggleButton = wrapper.find('button[type="button"]')

      // Show password
      await toggleButton.trigger('click')
      expect(wrapper.find('input').attributes('type')).toBe('text')

      // Hide password
      await toggleButton.trigger('click')
      expect(wrapper.find('input').attributes('type')).toBe('password')
    })
  })

  describe('password strength', () => {
    it('shows "weak" for short password', async () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: 'abc',
          showStrength: true,
        },
      })

      expect(wrapper.html()).toContain('Weak')
    })

    it('shows "fair" for password with 2 strength conditions', async () => {
      // 8+ chars + mixed case = strength 2 = Fair
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          showStrength: true,
        },
      })

      // Trigger input event to calculate strength
      const input = wrapper.find('input')
      await input.setValue('Abcdefgh')
      // Update the modelValue prop to simulate parent component responding to update:modelValue event
      await wrapper.setProps({ modelValue: 'Abcdefgh' })

      expect(wrapper.html()).toContain('Fair')
    })

    it('shows "good" for password with 3 strength conditions', async () => {
      // 8+ chars + mixed case + digit = strength 3 = Good
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          showStrength: true,
        },
      })

      // Trigger input event to calculate strength
      const input = wrapper.find('input')
      await input.setValue('Abcdef12')
      // Update the modelValue prop to simulate parent component responding to update:modelValue event
      await wrapper.setProps({ modelValue: 'Abcdef12' })

      expect(wrapper.html()).toContain('Good')
    })

    it('shows "strong" for complex password with 4+ conditions', async () => {
      // 8+ chars + 12+ chars + mixed case + digit + special = strength 5 = Strong
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          showStrength: true,
        },
      })

      // Trigger input event to calculate strength
      const input = wrapper.find('input')
      await input.setValue('Abcdef123!@#')
      // Update the modelValue prop to simulate parent component responding to update:modelValue event
      await wrapper.setProps({ modelValue: 'Abcdef123!@#' })

      expect(wrapper.html()).toContain('Strong')
    })

    it('shows requirements text when showStrength is true', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          showStrength: true,
        },
      })

      const html = wrapper.html()
      expect(html).toContain('8 characters')
      expect(html).toContain('Uppercase and lowercase')
      // Numbers and special characters are combined in the actual text
      expect(html).toContain('Numbers and special characters')
    })
  })

  describe('v-model binding', () => {
    it('emits update:modelValue on input', async () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
        },
      })

      const input = wrapper.find('input')
      await input.setValue('newpassword')

      expect(wrapper.emitted('update:modelValue')).toBeTruthy()
      expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['newpassword'])
    })

    it('updates input value when modelValue prop changes', async () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: 'initial',
        },
      })

      await wrapper.setProps({ modelValue: 'updated' })

      const input = wrapper.find('input')
      expect((input.element as HTMLInputElement).value).toBe('updated')
    })
  })

  describe('accessibility', () => {
    it('associates label with input via id', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
        },
      })

      const label = wrapper.find('label')
      const input = wrapper.find('input')

      expect(label.attributes('for')).toBe('test-password')
      expect(input.attributes('id')).toBe('test-password')
    })

    it('applies required attribute when prop is true', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          required: true,
        },
      })

      const input = wrapper.find('input')
      expect(input.attributes('required')).toBeDefined()
    })

    it('applies autocomplete attribute', () => {
      wrapper = mount(PasswordInput, {
        props: {
          id: 'test-password',
          label: 'Password',
          modelValue: '',
          autocomplete: 'current-password',
        },
      })

      const input = wrapper.find('input')
      expect(input.attributes('autocomplete')).toBe('current-password')
    })
  })
})
