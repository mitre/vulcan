import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ReviewStatus from './ReviewStatus.vue'

describe('reviewStatus', () => {
  describe('no review state', () => {
    it('shows dash when no review activity', () => {
      const wrapper = mount(ReviewStatus, {
        props: {},
      })

      expect(wrapper.text()).toBe('—')
      expect(wrapper.find('.badge').exists()).toBe(false)
    })

    it('shows dash when explicitly set to no review', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          reviewRequestorId: null,
          changesRequested: false,
          locked: false,
        },
      })

      expect(wrapper.text()).toBe('—')
    })
  })

  describe('pending review state', () => {
    it('shows warning badge when review requested', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          reviewRequestorId: 123,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.exists()).toBe(true)
      expect(badge.classes()).toContain('bg-warning')
      expect(badge.text()).toContain('Pending')
    })

    it('includes clock icon', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          reviewRequestorId: 123,
        },
      })

      expect(wrapper.find('.bi-clock-history').exists()).toBe(true)
    })

    it('shows requestor name in tooltip when provided', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          reviewRequestorId: 123,
          reviewRequestorName: 'Alice Smith',
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.attributes('title')).toContain('Alice Smith')
    })

    it('shows generic tooltip when no requestor name', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          reviewRequestorId: 123,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.attributes('title')).toBe('Pending review')
    })
  })

  describe('changes requested state', () => {
    it('shows danger badge when changes requested', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          changesRequested: true,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.exists()).toBe(true)
      expect(badge.classes()).toContain('bg-danger')
      expect(badge.text()).toContain('Changes')
    })

    it('includes exclamation icon', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          changesRequested: true,
        },
      })

      expect(wrapper.find('.bi-exclamation-circle').exists()).toBe(true)
    })

    it('has appropriate tooltip', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          changesRequested: true,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.attributes('title')).toContain('needs author attention')
    })
  })

  describe('approved/locked state', () => {
    it('shows success badge when locked', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          locked: true,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.exists()).toBe(true)
      expect(badge.classes()).toContain('bg-success')
      expect(badge.text()).toContain('Approved')
    })

    it('includes check icon', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          locked: true,
        },
      })

      expect(wrapper.find('.bi-check-circle').exists()).toBe(true)
    })

    it('has appropriate tooltip', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          locked: true,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.attributes('title')).toContain('Approved and locked')
    })
  })

  describe('state priority', () => {
    it('locked takes precedence over pending review', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          locked: true,
          reviewRequestorId: 123,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.classes()).toContain('bg-success')
      expect(badge.text()).toContain('Approved')
    })

    it('locked takes precedence over changes requested', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          locked: true,
          changesRequested: true,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.classes()).toContain('bg-success')
    })

    it('changes requested takes precedence over pending', () => {
      const wrapper = mount(ReviewStatus, {
        props: {
          changesRequested: true,
          reviewRequestorId: 123,
        },
      })

      const badge = wrapper.find('.badge')
      expect(badge.classes()).toContain('bg-danger')
      expect(badge.text()).toContain('Changes')
    })
  })
})
