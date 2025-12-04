import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import RequirementsToolbar from './RequirementsToolbar.vue'

describe('requirementsToolbar', () => {
  const defaultProps = {
    totalCount: 100,
    filteredCount: 50,
    showNestedRules: false,
    hasSatisfiesRelationships: true, // Enable toggle by default in tests
  }

  describe('rendering', () => {
    it('renders search input', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      expect(wrapper.find('input[type="text"]').exists()).toBe(true)
    })

    it('renders status filter dropdown', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const statusSelect = selects.find(s => s.text().includes('All Statuses'))
      expect(statusSelect).toBeDefined()
    })

    it('renders severity filter dropdown', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const severitySelect = selects.find(s => s.text().includes('All Severities'))
      expect(severitySelect).toBeDefined()
    })

    it('renders lock filter dropdown', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const lockSelect = selects.find(s => s.text().includes('All Locks'))
      expect(lockSelect).toBeDefined()
    })

    it('renders review filter dropdown', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const reviewSelect = selects.find(s => s.text().includes('All Reviews'))
      expect(reviewSelect).toBeDefined()
    })

    it('renders satisfies filter dropdown', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const satisfiesSelect = selects.find(s => s.text().includes('All Satisfies'))
      expect(satisfiesSelect).toBeDefined()
    })

    it('displays count statistics', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      expect(wrapper.text()).toContain('50 of 100')
    })
  })

  describe('lock filter options', () => {
    it('has all lock filter options', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const lockSelect = selects.find(s => s.text().includes('All Locks'))!
      const options = lockSelect.findAll('option')

      expect(options.length).toBe(3)
      expect(options[0].text()).toBe('All Locks')
      expect(options[1].text()).toBe('Locked')
      expect(options[2].text()).toBe('Unlocked')
    })

    it('emits update when lock filter changes', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const lockSelect = selects.find(s => s.text().includes('All Locks'))!
      await lockSelect.setValue('locked')

      expect(wrapper.emitted('update:filterLock')).toBeTruthy()
      expect(wrapper.emitted('update:filterLock')![0]).toEqual(['locked'])
    })
  })

  describe('review filter options', () => {
    it('has all review filter options', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const reviewSelect = selects.find(s => s.text().includes('All Reviews'))!
      const options = reviewSelect.findAll('option')

      expect(options.length).toBe(5)
      expect(options[0].text()).toBe('All Reviews')
      expect(options[1].text()).toBe('Pending Review')
      expect(options[2].text()).toBe('Changes Requested')
      expect(options[3].text()).toBe('Approved')
      expect(options[4].text()).toBe('No Review')
    })

    it('emits update when review filter changes', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const reviewSelect = selects.find(s => s.text().includes('All Reviews'))!
      await reviewSelect.setValue('pending')

      expect(wrapper.emitted('update:filterReview')).toBeTruthy()
      expect(wrapper.emitted('update:filterReview')![0]).toEqual(['pending'])
    })
  })

  describe('satisfies filter options', () => {
    it('has all satisfies filter options', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const satisfiesSelect = selects.find(s => s.text().includes('All Satisfies'))!
      const options = satisfiesSelect.findAll('option')

      expect(options.length).toBe(4)
      expect(options[0].text()).toBe('All Satisfies')
      expect(options[1].text()).toBe('Satisfies Others')
      expect(options[2].text()).toBe('Satisfied By')
      expect(options[3].text()).toBe('No Satisfaction')
    })

    it('emits update when satisfies filter changes', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const selects = wrapper.findAll('select')
      const satisfiesSelect = selects.find(s => s.text().includes('All Satisfies'))!
      await satisfiesSelect.setValue('satisfies_others')

      expect(wrapper.emitted('update:filterSatisfies')).toBeTruthy()
      expect(wrapper.emitted('update:filterSatisfies')![0]).toEqual(['satisfies_others'])
    })
  })

  describe('toggles', () => {
    it('renders group by status checkbox', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const checkbox = wrapper.find('#groupByStatus')
      expect(checkbox.exists()).toBe(true)
    })

    it('renders show nested rules checkbox', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const checkbox = wrapper.find('#showNested')
      expect(checkbox.exists()).toBe(true)
    })

    it('emits toggleNested when checkbox changes', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const checkbox = wrapper.find('#showNested')
      await checkbox.setValue(true)

      expect(wrapper.emitted('toggleNested')).toBeTruthy()
    })

    it('disables show satisfied toggle when no satisfaction relationships', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          hasSatisfiesRelationships: false,
        },
      })

      const checkbox = wrapper.find('#showNested')
      expect((checkbox.element as HTMLInputElement).disabled).toBe(true)
    })

    it('enables show satisfied toggle when satisfaction relationships exist', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          hasSatisfiesRelationships: true,
        },
      })

      const checkbox = wrapper.find('#showNested')
      expect((checkbox.element as HTMLInputElement).disabled).toBe(false)
    })

    it('uses switch styling for toggles', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const groupToggleContainer = wrapper.find('#groupByStatus').element.closest('.form-check')
      const nestedToggleContainer = wrapper.find('#showNested').element.closest('.form-check')

      expect(groupToggleContainer?.classList.contains('form-switch')).toBe(true)
      expect(nestedToggleContainer?.classList.contains('form-switch')).toBe(true)
    })

    it('shows muted label when toggle is disabled', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          hasSatisfiesRelationships: false,
        },
      })

      const label = wrapper.find('label[for="showNested"]')
      expect(label.classes()).toContain('text-muted')
    })
  })

  describe('find replace button', () => {
    it('does not show find replace button by default', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const buttons = wrapper.findAll('button')
      const findButton = buttons.find(b => b.text().includes('Find'))
      expect(findButton).toBeUndefined()
    })

    it('shows find replace button when showFindReplace is true', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          showFindReplace: true,
        },
      })

      const buttons = wrapper.findAll('button')
      const findButton = buttons.find(b => b.text().includes('Find'))
      expect(findButton).toBeDefined()
    })

    it('emits openFindReplace when button clicked', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          showFindReplace: true,
        },
      })

      const buttons = wrapper.findAll('button')
      const findButton = buttons.find(b => b.text().includes('Find'))!
      await findButton.trigger('click')

      expect(wrapper.emitted('openFindReplace')).toBeTruthy()
    })
  })

  describe('pagination', () => {
    it('displays page info when pagination provided', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          pagination: {
            page: 2,
            total_pages: 5,
            total_count: 100,
            has_prev: true,
            has_next: true,
          },
        },
      })

      expect(wrapper.text()).toContain('Page 2 of 5')
      expect(wrapper.text()).toContain('100 total')
    })

    it('shows pagination buttons when pagination provided', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          pagination: {
            page: 2,
            total_pages: 5,
            total_count: 100,
            has_prev: true,
            has_next: true,
          },
        },
      })

      const buttons = wrapper.findAll('.btn-group button')
      expect(buttons.length).toBe(4) // First, Prev, Next, Last
    })

    it('disables prev buttons on first page', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          pagination: {
            page: 1,
            total_pages: 5,
            total_count: 100,
            has_prev: false,
            has_next: true,
          },
        },
      })

      const buttons = wrapper.findAll('.btn-group button')
      expect(buttons[0].attributes('disabled')).toBeDefined()
      expect(buttons[1].attributes('disabled')).toBeDefined()
    })

    it('disables next buttons on last page', () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          pagination: {
            page: 5,
            total_pages: 5,
            total_count: 100,
            has_prev: true,
            has_next: false,
          },
        },
      })

      const buttons = wrapper.findAll('.btn-group button')
      expect(buttons[2].attributes('disabled')).toBeDefined()
      expect(buttons[3].attributes('disabled')).toBeDefined()
    })

    it('emits pageChange on button click', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: {
          ...defaultProps,
          pagination: {
            page: 2,
            total_pages: 5,
            total_count: 100,
            has_prev: true,
            has_next: true,
          },
        },
      })

      const buttons = wrapper.findAll('.btn-group button')
      await buttons[0].trigger('click') // First page

      expect(wrapper.emitted('pageChange')).toBeTruthy()
      expect(wrapper.emitted('pageChange')![0]).toEqual([1])
    })
  })

  describe('search', () => {
    it('emits update when search changes', async () => {
      const wrapper = mount(RequirementsToolbar, {
        props: defaultProps,
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('test search')

      expect(wrapper.emitted('update:search')).toBeTruthy()
      expect(wrapper.emitted('update:search')![0]).toEqual(['test search'])
    })
  })
})
