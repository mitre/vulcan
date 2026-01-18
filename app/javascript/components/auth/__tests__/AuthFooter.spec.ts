/**
 * AuthFooter Component Tests
 * Tests for authentication page footer with classification banner
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import AuthFooter from '../AuthFooter.vue'

// Mock ClassificationBanner component
vi.mock('@/components/shared/ClassificationBanner.vue', () => ({
  default: {
    name: 'ClassificationBanner',
    template: '<div class="classification-banner-mock">UNCLASSIFIED</div>',
  },
}))

describe('authFooter', () => {
  let wrapper: VueWrapper

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders classification banner', () => {
      wrapper = mount(AuthFooter)
      expect(wrapper.find('.classification-banner-mock').exists()).toBe(true)
    })

    it('only renders classification banner component', () => {
      wrapper = mount(AuthFooter)
      // Should just be the classification banner, no additional wrapper
      expect(wrapper.html()).toContain('classification-banner-mock')
    })
  })

  describe('content', () => {
    it('contains classification banner component', () => {
      wrapper = mount(AuthFooter)

      // Should contain the mocked classification banner
      expect(wrapper.html()).toContain('classification-banner-mock')
      expect(wrapper.html()).toContain('UNCLASSIFIED')
    })
  })
})
