/**
 * ProviderButton Component Tests
 * Tests for OAuth/OIDC/LDAP provider button (Rails form POST, not SPA)
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import ProviderButton from '../ProviderButton.vue'

describe('providerButton', () => {
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
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'OIDC',
        },
      })

      const form = wrapper.find('form')
      expect(form.exists()).toBe(true)
      expect(form.attributes('action')).toBe('/users/auth/oidc')
      expect(form.attributes('method')).toBe('post')
    })

    it('renders CSRF token input', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'OIDC',
        },
      })

      const csrfInput = wrapper.find('input[name="authenticity_token"]')
      expect(csrfInput.exists()).toBe(true)
      expect(csrfInput.attributes('type')).toBe('hidden')
      expect(csrfInput.attributes('value')).toBe('test-csrf-token')
    })

    it('renders submit button with title', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'Okta',
        },
      })

      const button = wrapper.find('button[type="submit"]')
      expect(button.exists()).toBe(true)
      expect(button.text()).toContain('Sign in with Okta')
    })

    it('renders icon when provided', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'Okta',
          icon: '/assets/okta-icon.png',
        },
      })

      const img = wrapper.find('img')
      expect(img.exists()).toBe(true)
      expect(img.attributes('src')).toBe('/assets/okta-icon.png')
      expect(img.attributes('height')).toBe('24')
      expect(img.attributes('width')).toBe('24')
    })

    it('does not render icon when not provided', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'OIDC',
        },
      })

      expect(wrapper.find('img').exists()).toBe(false)
    })
  })

  describe('props', () => {
    it('uses custom provider title', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/github',
          title: 'GitHub',
        },
      })

      expect(wrapper.find('button').text()).toContain('Sign in with GitHub')
    })

    it('uses custom provider path', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/google',
          title: 'Google',
        },
      })

      expect(wrapper.find('form').attributes('action')).toBe('/users/auth/google')
    })
  })

  describe('styling', () => {
    it('applies Bootstrap button classes', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'OIDC',
        },
      })

      const button = wrapper.find('button')
      expect(button.classes()).toContain('btn')
      expect(button.classes()).toContain('btn-primary')
      expect(button.classes()).toContain('btn-lg')
      expect(button.classes()).toContain('w-100')
    })

    it('applies correct icon styling', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'OIDC',
          icon: '/assets/icon.png',
        },
      })

      const img = wrapper.find('img')
      expect(img.attributes('style')).toContain('vertical-align: middle')
      expect(img.attributes('style')).toContain('margin-right: 10px')
    })
  })

  describe('bootstrap Icon Components', () => {
    it('renders GitHub icon component when providerId is github', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/github',
          title: 'GitHub',
          providerId: 'github',
        },
      })

      // Check for icon component via aria-label
      const iconComponent = wrapper.find('[aria-label="GitHub icon"]')
      expect(iconComponent.exists()).toBe(true)
    })

    it('renders Google icon component when providerId is google', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/google',
          title: 'Google',
          providerId: 'google',
        },
      })

      const iconComponent = wrapper.find('[aria-label="Google icon"]')
      expect(iconComponent.exists()).toBe(true)
    })

    it('renders OIDC shield icon component when providerId is oidc', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'Okta',
          providerId: 'oidc',
        },
      })

      const iconComponent = wrapper.find('[aria-label="Okta icon"]')
      expect(iconComponent.exists()).toBe(true)
    })

    it('renders LDAP building icon component when providerId is ldap', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/ldap',
          title: 'Active Directory',
          providerId: 'ldap',
        },
      })

      const iconComponent = wrapper.find('[aria-label="Active Directory icon"]')
      expect(iconComponent.exists()).toBe(true)
    })

    it('renders fallback key icon component for unknown provider', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/unknown',
          title: 'Custom SSO',
          providerId: 'unknown-provider',
        },
      })

      const iconComponent = wrapper.find('[aria-label="Custom SSO icon"]')
      expect(iconComponent.exists()).toBe(true)
    })

    it('prefers custom icon URL over icon component', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/github',
          title: 'GitHub Enterprise',
          providerId: 'github',
          customIcon: '/assets/custom-github.png',
        },
      })

      // Should render img tag, not icon component
      expect(wrapper.find('img').exists()).toBe(true)
      expect(wrapper.find('img').attributes('src')).toBe('/assets/custom-github.png')
      expect(wrapper.find('[aria-label="GitHub Enterprise icon"]').exists()).toBe(false)
    })

    it('supports backward compatibility with icon prop', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/oidc',
          title: 'OIDC',
          icon: '/assets/okta.png', // Old prop name
        },
      })

      const img = wrapper.find('img')
      expect(img.exists()).toBe(true)
      expect(img.attributes('src')).toBe('/assets/okta.png')
    })

    it('renders no icon when providerId not specified and no custom icon', () => {
      wrapper = mount(ProviderButton, {
        props: {
          path: '/users/auth/custom',
          title: 'Custom Auth',
        },
      })

      expect(wrapper.find('img').exists()).toBe(false)
      expect(wrapper.find('[aria-label]').exists()).toBe(false)
    })
  })
})
