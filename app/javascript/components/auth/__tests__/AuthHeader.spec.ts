/**
 * AuthHeader Component Tests
 * Tests for authentication page header with classification banner and dark mode
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import AuthHeader from '../AuthHeader.vue'

// Mock the composable
const mockCycleColorMode = vi.fn()
const mockColorMode = { value: 'light' }
const mockResolvedMode = { value: 'light' }

vi.mock('@/composables', () => ({
  useColorMode: () => ({
    colorMode: mockColorMode,
    resolvedMode: mockResolvedMode,
    cycleColorMode: mockCycleColorMode,
  }),
}))

// Mock ClassificationBanner component
vi.mock('@/components/shared/ClassificationBanner.vue', () => ({
  default: {
    name: 'ClassificationBanner',
    template: '<div class="classification-banner-mock">UNCLASSIFIED</div>',
  },
}))

describe('authHeader', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
    mockColorMode.value = 'light'
    mockResolvedMode.value = 'light'
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('rendering', () => {
    it('renders classification banner', () => {
      wrapper = mount(AuthHeader)
      expect(wrapper.find('.classification-banner-mock').exists()).toBe(true)
    })

    it('renders Vulcan logo and name', () => {
      wrapper = mount(AuthHeader)
      expect(wrapper.text()).toContain('Vulcan')
    })

    it('renders dark mode toggle button', () => {
      wrapper = mount(AuthHeader)
      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.exists()).toBe(true)
    })
  })

  describe('dark mode cycle', () => {
    it('shows sun icon in light mode', () => {
      mockColorMode.value = 'light'
      mockResolvedMode.value = 'light'

      wrapper = mount(AuthHeader)

      // Sun icon should be visible (rendered as SVG)
      const html = wrapper.html()
      // Icons are rendered as SVG, so check for viewBox which is unique to each icon
      expect(html).toContain('viewBox="0 0 16 16"')
      expect(html).toContain('<svg')
    })

    it('shows moon icon in dark mode', () => {
      mockColorMode.value = 'dark'
      mockResolvedMode.value = 'dark'

      wrapper = mount(AuthHeader)

      // Moon icon should be visible (rendered as SVG)
      const html = wrapper.html()
      expect(html).toContain('viewBox="0 0 16 16"')
      expect(html).toContain('<svg')
    })

    it('shows circle-half icon in auto mode', () => {
      mockColorMode.value = 'auto'
      mockResolvedMode.value = 'light' // Could resolve to either

      wrapper = mount(AuthHeader)

      // Circle-half icon should be visible (rendered as SVG)
      const html = wrapper.html()
      expect(html).toContain('viewBox="0 0 16 16"')
      expect(html).toContain('<svg')
    })

    it('cycles color mode when button clicked', async () => {
      wrapper = mount(AuthHeader)

      const toggleButton = wrapper.find('button[type="button"]')
      await toggleButton.trigger('click')

      expect(mockCycleColorMode).toHaveBeenCalledTimes(1)
    })

    it('has appropriate title attribute for light mode', () => {
      mockColorMode.value = 'light'

      wrapper = mount(AuthHeader)

      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.attributes('title')).toBe('Light mode')
    })

    it('has appropriate title attribute for dark mode', () => {
      mockColorMode.value = 'dark'

      wrapper = mount(AuthHeader)

      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.attributes('title')).toBe('Dark mode')
    })

    it('has appropriate title attribute for auto mode', () => {
      mockColorMode.value = 'auto'

      wrapper = mount(AuthHeader)

      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.attributes('title')).toBe('System preference')
    })
  })

  describe('layout', () => {
    it('has proper header structure', () => {
      wrapper = mount(AuthHeader)

      // Should have header element
      expect(wrapper.find('header').exists()).toBe(true)

      // Should have container with flex layout
      const container = wrapper.find('.container-fluid')
      expect(container.exists()).toBe(true)
      expect(container.classes()).toContain('d-flex')
      expect(container.classes()).toContain('justify-content-between')
    })

    it('positions logo and toggle button correctly', () => {
      wrapper = mount(AuthHeader)

      // Logo should be in left section
      const leftSection = wrapper.find('.d-flex.align-items-center.gap-2')
      expect(leftSection.exists()).toBe(true)
      expect(leftSection.text()).toContain('Vulcan')

      // Toggle should be on the right
      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.exists()).toBe(true)
    })
  })

  describe('accessibility', () => {
    it('button has type="button" to prevent form submission', () => {
      wrapper = mount(AuthHeader)

      const toggleButton = wrapper.find('button')
      expect(toggleButton.attributes('type')).toBe('button')
    })

    it('button has title for screen readers', () => {
      wrapper = mount(AuthHeader)

      const toggleButton = wrapper.find('button[type="button"]')
      expect(toggleButton.attributes('title')).toBeTruthy()
    })
  })
})
