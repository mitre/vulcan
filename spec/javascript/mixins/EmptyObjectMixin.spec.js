import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { localVue } from '@test/testHelper'
import EmptyObjectMixin from '@/mixins/EmptyObjectMixin.vue'

/**
 * EmptyObjectMixin Tests
 *
 * REQUIREMENTS:
 *
 * isEmpty(o) determines if a value is "empty":
 * - Returns true for null
 * - Returns true for undefined
 * - Returns true for empty object {}
 * - Returns false for object with properties
 * - Returns true for falsy values (0, '', false) due to `if (!o)` guard
 *
 * This mixin is used throughout the application to check if API responses
 * or data objects are empty before rendering.
 */

const HostComponent = {
  mixins: [EmptyObjectMixin],
  template: '<div></div>',
}

function createWrapper() {
  return mount(HostComponent, { localVue })
}

describe('EmptyObjectMixin', () => {
  describe('isEmpty', () => {
    // ==========================================
    // TRUE CASES — null / undefined / empty
    // ==========================================
    it('returns true for null', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty(null)).toBe(true)
    })

    it('returns true for undefined', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty(undefined)).toBe(true)
    })

    it('returns true for empty object {}', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty({})).toBe(true)
    })

    // ==========================================
    // TRUE CASES — falsy values (due to !o guard)
    // ==========================================
    it('returns true for 0', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty(0)).toBe(true)
    })

    it('returns true for empty string', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty('')).toBe(true)
    })

    it('returns true for false', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty(false)).toBe(true)
    })

    // ==========================================
    // FALSE CASES — non-empty objects
    // ==========================================
    it('returns false for object with one key', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty({ a: 1 })).toBe(false)
    })

    it('returns false for object with multiple keys', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty({ a: 1, b: 2, c: 3 })).toBe(false)
    })

    it('returns false for object with nested structure', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.isEmpty({ data: { nested: true } })).toBe(false)
    })

    it('returns false for object with null value property', () => {
      const wrapper = createWrapper()
      // Object has a key (even though value is null), so it is not empty
      expect(wrapper.vm.isEmpty({ key: null })).toBe(false)
    })
  })
})
