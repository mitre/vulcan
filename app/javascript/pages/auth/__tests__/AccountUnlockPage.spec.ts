/**
 * AccountUnlockPage Integration Tests
 * Tests for the complete account unlock page
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import AccountUnlockPage from '../AccountUnlockPage.vue'

// Mock child components
vi.mock('@/components/auth/AccountUnlockForm.vue', () => ({
  default: {
    name: 'AccountUnlockForm',
    template: '<form class="account-unlock-form-mock"><input type="email" /><button>Submit</button></form>',
  },
}))

vi.mock('@/components/shared/PageContainer.vue', () => ({
  default: {
    name: 'PageContainer',
    template: '<div class="page-container-mock"><slot /></div>',
  },
}))

describe('accountUnlockPage', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    vi.clearAllMocks()
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('page structure', () => {
    it('renders PageContainer wrapper', () => {
      wrapper = mount(AccountUnlockPage)
      expect(wrapper.find('.page-container-mock').exists()).toBe(true)
    })

    it('has centered card layout', () => {
      wrapper = mount(AccountUnlockPage)

      const centerContainer = wrapper.find('.d-flex.align-items-center.justify-content-center')
      expect(centerContainer.exists()).toBe(true)
      expect(centerContainer.attributes('style')).toContain('min-height: 60vh')
    })

    it('renders card with correct max-width', () => {
      wrapper = mount(AccountUnlockPage)

      const card = wrapper.find('.card.shadow-sm')
      expect(card.exists()).toBe(true)
      expect(card.attributes('style')).toContain('max-width: 28rem')
    })
  })

  describe('content', () => {
    it('displays unlock icon', () => {
      wrapper = mount(AccountUnlockPage)

      // Icon should be present (rendered as SVG)
      const html = wrapper.html()
      expect(html).toContain('<svg')
      expect(html).toContain('viewBox="0 0 16 16"')
    })

    it('displays "Unlock Account" title', () => {
      wrapper = mount(AccountUnlockPage)
      expect(wrapper.text()).toContain('Unlock Account')
    })

    it('displays instructional text', () => {
      wrapper = mount(AccountUnlockPage)
      expect(wrapper.text()).toContain('Enter your email to receive unlock instructions')
    })

    it('renders AccountUnlockForm component', () => {
      wrapper = mount(AccountUnlockPage)
      expect(wrapper.find('.account-unlock-form-mock').exists()).toBe(true)
    })
  })

  describe('styling', () => {
    it('uses primary color for icon', () => {
      wrapper = mount(AccountUnlockPage)

      const icon = wrapper.find('.text-primary')
      expect(icon.exists()).toBe(true)
    })

    it('has proper card padding', () => {
      wrapper = mount(AccountUnlockPage)

      const cardBody = wrapper.find('.card-body')
      expect(cardBody.classes()).toContain('p-4')
    })

    it('has responsive card width', () => {
      wrapper = mount(AccountUnlockPage)

      const card = wrapper.find('.card')
      expect(card.classes()).toContain('w-100')
    })
  })

  describe('accessibility', () => {
    it('has appropriate heading hierarchy', () => {
      wrapper = mount(AccountUnlockPage)

      expect(wrapper.find('h4').exists()).toBe(true)
      expect(wrapper.find('h4').text()).toContain('Unlock Account')
    })

    it('uses semantic HTML structure', () => {
      wrapper = mount(AccountUnlockPage)
      expect(wrapper.find('form').exists()).toBe(true)
    })
  })
})
