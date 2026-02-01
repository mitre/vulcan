import { describe, it, expect, afterEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import FilterBar from '@/components/shared/FilterBar.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * FilterBar Component Requirements:
 *
 * 1. Container that holds 0-3 FilterGroup components horizontally
 * 2. Props control which groups to show: showStatus, showReview, showDisplay
 * 3. Passes filter state to each FilterGroup
 * 4. Emits 'update:filters' when any filter changes
 * 5. Handles reset for individual groups and all groups
 */
describe('FilterBar', () => {
  let wrapper

  const defaultFilters = {
    // Status filters
    acFilterChecked: true,
    aimFilterChecked: true,
    adnmFilterChecked: false,
    naFilterChecked: true,
    nydFilterChecked: true,
    // Review filters
    nurFilterChecked: true,
    urFilterChecked: true,
    lckFilterChecked: true,
    // Display filters
    nestSatisfiedRulesChecked: true,
    showSRGIdChecked: false,
    sortBySRGIdChecked: true
  }

  const defaultCounts = {
    ac: 264,
    aim: 0,
    adnm: 0,
    na: 0,
    nyd: 0,
    nur: 264,
    ur: 0,
    lck: 0
  }

  const createWrapper = (props = {}) => {
    return shallowMount(FilterBar, {
      localVue,
      propsData: {
        filters: defaultFilters,
        counts: defaultCounts,
        showStatus: true,
        showReview: true,
        showDisplay: true,
        ...props
      },
      stubs: {
        FilterGroup: true
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  describe('rendering', () => {
    it('renders the filter bar container', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.filter-bar').exists()).toBe(true)
    })

    it('renders all three FilterGroups by default', () => {
      wrapper = createWrapper()
      const groups = wrapper.findAllComponents({ name: 'FilterGroup' })
      expect(groups.length).toBe(3)
    })

    it('renders only Status group when others are hidden', () => {
      wrapper = createWrapper({
        showStatus: true,
        showReview: false,
        showDisplay: false
      })
      const groups = wrapper.findAllComponents({ name: 'FilterGroup' })
      expect(groups.length).toBe(1)
      expect(groups.at(0).props('title')).toBe('Status')
    })

    it('renders only Display group when others are hidden', () => {
      wrapper = createWrapper({
        showStatus: false,
        showReview: false,
        showDisplay: true
      })
      const groups = wrapper.findAllComponents({ name: 'FilterGroup' })
      expect(groups.length).toBe(1)
      expect(groups.at(0).props('title')).toBe('Display')
    })

    it('renders no groups when all are hidden', () => {
      wrapper = createWrapper({
        showStatus: false,
        showReview: false,
        showDisplay: false
      })
      const groups = wrapper.findAllComponents({ name: 'FilterGroup' })
      expect(groups.length).toBe(0)
    })
  })

  describe('group order', () => {
    it('renders groups in order: Status, Review, Display', () => {
      wrapper = createWrapper()
      const groups = wrapper.findAllComponents({ name: 'FilterGroup' })
      expect(groups.at(0).props('title')).toBe('Status')
      expect(groups.at(1).props('title')).toBe('Review')
      expect(groups.at(2).props('title')).toBe('Display')
    })
  })

  describe('filter state', () => {
    it('passes status items to Status group', () => {
      wrapper = createWrapper()
      const statusGroup = wrapper.findAllComponents({ name: 'FilterGroup' }).at(0)
      const items = statusGroup.props('items')
      expect(items.length).toBe(5)
      expect(items[0].key).toBe('acFilterChecked')
      expect(items[0].checked).toBe(true)
      expect(items[0].count).toBe(264)
    })

    it('passes review items to Review group', () => {
      wrapper = createWrapper()
      const reviewGroup = wrapper.findAllComponents({ name: 'FilterGroup' }).at(1)
      const items = reviewGroup.props('items')
      expect(items.length).toBe(3)
      expect(items[0].key).toBe('nurFilterChecked')
    })

    it('passes display items to Display group', () => {
      wrapper = createWrapper()
      const displayGroup = wrapper.findAllComponents({ name: 'FilterGroup' }).at(2)
      const items = displayGroup.props('items')
      expect(items.length).toBe(3)
      expect(items[0].key).toBe('nestSatisfiedRulesChecked')
      // Display items should not have counts
      expect(items[0].count).toBeUndefined()
    })
  })

  describe('events', () => {
    it('emits update:filters when a FilterGroup updates', async () => {
      wrapper = createWrapper()
      const statusGroup = wrapper.findComponent({ name: 'FilterGroup' })

      // Simulate FilterGroup emitting update:items
      const updatedItems = [
        { key: 'acFilterChecked', checked: false }
      ]
      await statusGroup.vm.$emit('update:items', updatedItems)

      expect(wrapper.emitted('update:filters')).toBeTruthy()
      const emittedFilters = wrapper.emitted('update:filters')[0][0]
      expect(emittedFilters.acFilterChecked).toBe(false)
    })

    it('emits update:filters with all filters reset when group reset is triggered', async () => {
      wrapper = createWrapper({
        filters: {
          ...defaultFilters,
          acFilterChecked: false,
          aimFilterChecked: false
        }
      })
      const statusGroup = wrapper.findComponent({ name: 'FilterGroup' })
      await statusGroup.vm.$emit('reset')

      expect(wrapper.emitted('update:filters')).toBeTruthy()
      const emittedFilters = wrapper.emitted('update:filters')[0][0]
      // Status filters should be reset to true
      expect(emittedFilters.acFilterChecked).toBe(true)
      expect(emittedFilters.aimFilterChecked).toBe(true)
    })
  })

  describe('layout', () => {
    it('uses flexbox for horizontal layout', () => {
      wrapper = createWrapper()
      const container = wrapper.find('.filter-bar')
      expect(container.classes()).toContain('d-flex')
    })
  })
})
