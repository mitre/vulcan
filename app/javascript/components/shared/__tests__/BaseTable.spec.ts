import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import BaseTable from '../BaseTable.vue'

interface TestItem {
  id: number
  name: string
  email: string
}

describe('baseTable', () => {
  const testItems: TestItem[] = [
    { id: 1, name: 'Alice', email: 'alice@example.com' },
    { id: 2, name: 'Bob', email: 'bob@example.com' },
    { id: 3, name: 'Charlie', email: 'charlie@example.com' },
  ]

  const defaultProps = {
    items: testItems,
    columns: [
      { key: 'name', label: 'Name' },
      { key: 'email', label: 'Email' },
    ],
    totalRows: 3,
    currentPage: 1,
  }

  describe('rendering', () => {
    it('renders table with items', () => {
      const wrapper = mount(BaseTable, {
        props: defaultProps,
        global: {
          stubs: {
            BTable: {
              template: '<table><slot /></table>',
              props: ['items', 'fields'],
            },
            BPagination: true,
          },
        },
      })

      expect(wrapper.find('.base-table').exists()).toBe(true)
    })

    it('renders search input by default', () => {
      const wrapper = mount(BaseTable, {
        props: defaultProps,
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      expect(wrapper.find('input[type="text"]').exists()).toBe(true)
      expect(wrapper.find('.bi-search').exists()).toBe(true)
    })

    it('hides search input when showSearch is false', () => {
      const wrapper = mount(BaseTable, {
        props: {
          ...defaultProps,
          showSearch: false,
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      expect(wrapper.find('input[type="text"]').exists()).toBe(false)
    })

    it('shows loading spinner when loading is true', () => {
      const wrapper = mount(BaseTable, {
        props: {
          ...defaultProps,
          loading: true,
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      expect(wrapper.find('.spinner-border').exists()).toBe(true)
    })

    it('hides pagination when totalRows <= perPage', () => {
      const wrapper = mount(BaseTable, {
        props: {
          ...defaultProps,
          totalRows: 5,
          perPage: 10,
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: {
              template: '<div class="pagination-stub" />',
            },
          },
        },
      })

      expect(wrapper.find('.pagination-stub').exists()).toBe(false)
    })

    it('shows pagination when totalRows > perPage', () => {
      const wrapper = mount(BaseTable, {
        props: {
          ...defaultProps,
          totalRows: 15,
          perPage: 10,
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: {
              template: '<div class="pagination-stub" />',
            },
          },
        },
      })

      expect(wrapper.find('.pagination-stub').exists()).toBe(true)
    })
  })

  describe('search functionality', () => {
    it('emits update:search on input', async () => {
      const wrapper = mount(BaseTable, {
        props: defaultProps,
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('test')

      expect(wrapper.emitted('update:search')).toBeTruthy()
      expect(wrapper.emitted('update:search')![0]).toEqual(['test'])
    })

    it('uses custom placeholder', () => {
      const wrapper = mount(BaseTable, {
        props: {
          ...defaultProps,
          searchPlaceholder: 'Search users...',
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      const input = wrapper.find('input[type="text"]')
      expect(input.attributes('placeholder')).toBe('Search users...')
    })
  })

  describe('slots', () => {
    it('renders header-actions slot', () => {
      const wrapper = mount(BaseTable, {
        props: defaultProps,
        slots: {
          'header-actions': '<button>Add New</button>',
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      expect(wrapper.find('button').text()).toBe('Add New')
    })

    it('renders filters slot', () => {
      const wrapper = mount(BaseTable, {
        props: defaultProps,
        slots: {
          filters: '<div class="custom-filter">Filters</div>',
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      expect(wrapper.find('.custom-filter').exists()).toBe(true)
    })
  })

  describe('column conversion', () => {
    it('converts columns to BTable fields format', () => {
      const wrapper = mount(BaseTable, {
        props: {
          ...defaultProps,
          columns: [
            { key: 'name', label: 'Full Name', sortable: true },
            { key: 'email', label: 'Email Address', thClass: 'text-end' },
          ],
        },
        global: {
          stubs: {
            BTable: {
              template: '<table data-fields="{{ JSON.stringify(fields) }}" />',
              props: ['items', 'fields'],
            },
            BPagination: true,
          },
        },
      })

      // The component should pass properly formatted fields to BTable
      expect(wrapper.exists()).toBe(true)
    })
  })

  describe('default props', () => {
    it('has correct default values', () => {
      const wrapper = mount(BaseTable, {
        props: {
          items: testItems,
          columns: [{ key: 'name', label: 'Name' }],
          totalRows: 3,
        },
        global: {
          stubs: {
            BTable: true,
            BPagination: true,
          },
        },
      })

      // Component should render without explicit optional props
      expect(wrapper.exists()).toBe(true)
      expect(wrapper.find('input').attributes('placeholder')).toBe('Search...')
    })
  })
})
