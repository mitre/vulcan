import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import LockProgress from './LockProgress.vue'

describe('lockProgress', () => {
  describe('with single locked boolean', () => {
    it('shows all unlocked when locked=false', () => {
      const wrapper = mount(LockProgress, {
        props: { locked: false },
      })

      const unlockIcons = wrapper.findAll('.bi-unlock')
      const lockIcons = wrapper.findAll('.bi-lock-fill')

      expect(unlockIcons.length).toBe(4)
      expect(lockIcons.length).toBe(0)
      expect(wrapper.text()).toContain('(0/4)')
    })

    it('shows all locked when locked=true', () => {
      const wrapper = mount(LockProgress, {
        props: { locked: true },
      })

      const unlockIcons = wrapper.findAll('.bi-unlock')
      const lockIcons = wrapper.findAll('.bi-lock-fill')

      expect(unlockIcons.length).toBe(0)
      expect(lockIcons.length).toBe(4)
    })

    it('shows checkmark when fully locked', () => {
      const wrapper = mount(LockProgress, {
        props: { locked: true, showCount: true },
      })

      expect(wrapper.find('.bi-check-circle-fill').exists()).toBe(true)
      expect(wrapper.text()).not.toContain('(4/4)')
    })
  })

  describe('with field-level locks', () => {
    it('shows partial locks correctly', () => {
      const wrapper = mount(LockProgress, {
        props: {
          titleLocked: true,
          vulnLocked: true,
          checkLocked: false,
          fixLocked: false,
        },
      })

      const lockIcons = wrapper.findAll('.bi-lock-fill')
      const unlockIcons = wrapper.findAll('.bi-unlock')

      expect(lockIcons.length).toBe(2)
      expect(unlockIcons.length).toBe(2)
      expect(wrapper.text()).toContain('(2/4)')
    })

    it('shows 3/4 locks correctly', () => {
      const wrapper = mount(LockProgress, {
        props: {
          titleLocked: true,
          vulnLocked: true,
          checkLocked: true,
          fixLocked: false,
        },
      })

      expect(wrapper.text()).toContain('(3/4)')
    })

    it('shows checkmark when all 4 fields locked', () => {
      const wrapper = mount(LockProgress, {
        props: {
          titleLocked: true,
          vulnLocked: true,
          checkLocked: true,
          fixLocked: true,
        },
      })

      expect(wrapper.find('.bi-check-circle-fill').exists()).toBe(true)
      expect(wrapper.find('.fully-locked').exists()).toBe(true)
    })

    it('handles mixed defined and undefined field locks', () => {
      const wrapper = mount(LockProgress, {
        props: {
          titleLocked: true,
          // Others undefined - will be treated as false
        },
      })

      const lockIcons = wrapper.findAll('.bi-lock-fill')
      expect(lockIcons.length).toBe(1) // Only title locked
      expect(wrapper.text()).toContain('(1/4)')
    })
  })

  describe('display options', () => {
    it('hides count when showCount=false', () => {
      const wrapper = mount(LockProgress, {
        props: { locked: false, showCount: false },
      })

      expect(wrapper.find('.lock-count').exists()).toBe(false)
    })

    it('applies compact class when compact=true', () => {
      const wrapper = mount(LockProgress, {
        props: { locked: false, compact: true },
      })

      expect(wrapper.find('.compact').exists()).toBe(true)
    })

    it('has correct tooltip on container', () => {
      const wrapper = mount(LockProgress, {
        props: {
          titleLocked: true,
          vulnLocked: false,
          checkLocked: false,
          fixLocked: false,
        },
      })

      expect(wrapper.attributes('title')).toBe('1/4 fields locked')
    })

    it('has correct tooltip on individual lock icons', () => {
      const wrapper = mount(LockProgress, {
        props: {
          titleLocked: true,
          vulnLocked: false,
          checkLocked: false,
          fixLocked: false,
        },
      })

      const icons = wrapper.findAll('.lock-icons .bi')
      expect(icons[0].attributes('title')).toBe('Title: Locked')
      expect(icons[1].attributes('title')).toBe('Vuln Discussion: Unlocked')
      expect(icons[2].attributes('title')).toBe('Check: Unlocked')
      expect(icons[3].attributes('title')).toBe('Fix: Unlocked')
    })
  })

  describe('styling', () => {
    it('applies success color to locked icons', () => {
      const wrapper = mount(LockProgress, {
        props: { titleLocked: true, vulnLocked: false, checkLocked: false, fixLocked: false },
      })

      const lockedIcon = wrapper.find('.bi-lock-fill')
      expect(lockedIcon.classes()).toContain('text-success')
    })

    it('applies muted color to unlocked icons', () => {
      const wrapper = mount(LockProgress, {
        props: { titleLocked: true, vulnLocked: false, checkLocked: false, fixLocked: false },
      })

      const unlockedIcon = wrapper.find('.bi-unlock')
      expect(unlockedIcon.classes()).toContain('text-muted')
    })
  })
})
