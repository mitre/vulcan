/**
 * AuthFooter Component Tests
 *
 * Requirements:
 * - AuthFooter is a thin wrapper around AppFooter (DRY pattern)
 * - It renders the shared AppFooter which includes AppBanner + FooterCopyright
 * - Used on standalone auth pages for layout consistency
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import AuthFooter from '../AuthFooter.vue'

// Mock AppFooter (AuthFooter's only dependency)
vi.mock('@/components/shared/AppFooter.vue', () => ({
  default: {
    name: 'AppFooter',
    template: '<footer class="app-footer-mock">Footer Content</footer>',
  },
}))

describe('authFooter', () => {
  let wrapper: VueWrapper

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders AppFooter component', () => {
      wrapper = mount(AuthFooter)
      expect(wrapper.find('.app-footer-mock').exists()).toBe(true)
    })

    it('delegates all rendering to AppFooter', () => {
      wrapper = mount(AuthFooter)
      // AuthFooter is just a wrapper — all content comes from AppFooter
      expect(wrapper.text()).toContain('Footer Content')
    })
  })

  describe('structure', () => {
    it('renders a footer element', () => {
      wrapper = mount(AuthFooter)
      expect(wrapper.find('footer').exists()).toBe(true)
    })
  })
})
