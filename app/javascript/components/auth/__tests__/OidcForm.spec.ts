/**
 * OidcForm Component Tests
 * Tests for OIDC provider button (Rails form POST, not SPA)
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import OidcForm from '../OidcForm.vue'

describe('oidcForm', () => {
  let wrapper: VueWrapper

  // Mock CSRF token meta tag
  beforeEach(() => {
    const metaTag = document.createElement('meta')
    metaTag.setAttribute('name', 'csrf-token')
    metaTag.setAttribute('content', 'test-csrf-token')
    document.head.appendChild(metaTag)
  })

  afterEach(() => {
    wrapper?.unmount()
    // Clean up meta tags
    const metaTags = document.querySelectorAll('meta[name="csrf-token"]')
    metaTags.forEach(tag => tag.remove())
  })

  describe('rendering', () => {
    it('renders form with correct action', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'OIDC',
        },
      })

      const form = wrapper.find('form')
      expect(form.exists()).toBe(true)
      expect(form.attributes('action')).toBe('/users/auth/oidc')
      expect(form.attributes('method')).toBe('post')
    })

    it('renders CSRF token input', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'OIDC',
        },
      })

      const csrfInput = wrapper.find('input[name="authenticity_token"]')
      expect(csrfInput.exists()).toBe(true)
      expect(csrfInput.attributes('type')).toBe('hidden')
      expect(csrfInput.attributes('value')).toBe('test-csrf-token')
    })

    it('renders submit button with title', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'Okta',
        },
      })

      const button = wrapper.find('button[type="submit"]')
      expect(button.exists()).toBe(true)
      expect(button.text()).toContain('Sign in with Okta')
    })

    it('renders icon when provided', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'Okta',
          oidcIconPath: '/assets/okta-icon.png',
        },
      })

      const img = wrapper.find('img')
      expect(img.exists()).toBe(true)
      expect(img.attributes('src')).toBe('/assets/okta-icon.png')
      expect(img.attributes('height')).toBe('40')
      expect(img.attributes('width')).toBe('40')
    })

    it('does not render icon when not provided', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'OIDC',
        },
      })

      expect(wrapper.find('img').exists()).toBe(false)
    })
  })

  describe('props', () => {
    it('uses custom OIDC title', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/github',
          oidcTitle: 'GitHub',
        },
      })

      expect(wrapper.find('button').text()).toContain('Sign in with GitHub')
    })

    it('uses custom OIDC path', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/google',
          oidcTitle: 'Google',
        },
      })

      expect(wrapper.find('form').attributes('action')).toBe('/users/auth/google')
    })
  })

  describe('styling', () => {
    it('applies Bootstrap button classes', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'OIDC',
        },
      })

      const button = wrapper.find('button')
      expect(button.classes()).toContain('btn')
      expect(button.classes()).toContain('btn-primary')
      expect(button.classes()).toContain('btn-lg')
      expect(button.classes()).toContain('w-100')
    })

    it('applies correct icon styling', () => {
      wrapper = mount(OidcForm, {
        props: {
          oidcPath: '/users/auth/oidc',
          oidcTitle: 'OIDC',
          oidcIconPath: '/assets/icon.png',
        },
      })

      const img = wrapper.find('img')
      expect(img.attributes('style')).toContain('vertical-align: middle')
      expect(img.attributes('style')).toContain('margin-right: 10px')
    })
  })
})
