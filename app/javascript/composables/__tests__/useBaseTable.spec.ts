import { beforeEach, describe, expect, it } from 'vitest'
import { computed, ref } from 'vue'
import { useBaseTable } from '../useBaseTable'

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value
    },
    removeItem: (key: string) => {
      delete store[key]
    },
    clear: () => {
      store = {}
    },
  }
})()

Object.defineProperty(window, 'localStorage', { value: localStorageMock })

interface TestItem {
  id: number
  name: string
  email: string
  role: string
}

describe('useBaseTable', () => {
  const testItems: TestItem[] = [
    { id: 1, name: 'Alice', email: 'alice@example.com', role: 'admin' },
    { id: 2, name: 'Bob', email: 'bob@example.com', role: 'user' },
    { id: 3, name: 'Charlie', email: 'charlie@example.com', role: 'user' },
    { id: 4, name: 'Diana', email: 'diana@example.com', role: 'admin' },
    { id: 5, name: 'Eve', email: 'eve@example.com', role: 'user' },
    { id: 6, name: 'Frank', email: 'frank@example.com', role: 'user' },
    { id: 7, name: 'Grace', email: 'grace@example.com', role: 'admin' },
    { id: 8, name: 'Henry', email: 'henry@example.com', role: 'user' },
    { id: 9, name: 'Ivy', email: 'ivy@example.com', role: 'user' },
    { id: 10, name: 'Jack', email: 'jack@example.com', role: 'admin' },
    { id: 11, name: 'Kate', email: 'kate@example.com', role: 'user' },
    { id: 12, name: 'Liam', email: 'liam@example.com', role: 'user' },
  ]

  beforeEach(() => {
    localStorageMock.clear()
  })

  describe('initialization', () => {
    it('initializes with default values', () => {
      const items = ref(testItems)
      const { search, currentPage, perPage, totalRows } = useBaseTable({
        items,
        searchFields: ['name', 'email'],
      })

      expect(search.value).toBe('')
      expect(currentPage.value).toBe(1)
      expect(perPage.value).toBe(10)
      expect(totalRows.value).toBe(12)
    })

    it('accepts custom perPage', () => {
      const items = ref(testItems)
      const { perPage } = useBaseTable({
        items,
        searchFields: ['name'],
        perPage: 5,
      })

      expect(perPage.value).toBe(5)
    })
  })

  describe('filtering', () => {
    it('filters items by search term', () => {
      const items = ref(testItems)
      const { search, filteredItems } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      search.value = 'alice'
      expect(filteredItems.value).toHaveLength(1)
      expect(filteredItems.value[0].name).toBe('Alice')
    })

    it('filters across multiple fields', () => {
      const items = ref(testItems)
      const { search, filteredItems } = useBaseTable({
        items,
        searchFields: ['name', 'email'],
      })

      search.value = 'charlie'
      expect(filteredItems.value).toHaveLength(1)

      search.value = '@example'
      expect(filteredItems.value).toHaveLength(12)
    })

    it('is case insensitive', () => {
      const items = ref(testItems)
      const { search, filteredItems } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      search.value = 'ALICE'
      expect(filteredItems.value).toHaveLength(1)
      expect(filteredItems.value[0].name).toBe('Alice')
    })

    it('handles empty search', () => {
      const items = ref(testItems)
      const { search, filteredItems } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      search.value = ''
      expect(filteredItems.value).toHaveLength(12)
    })

    it('handles null/undefined values in items', () => {
      const itemsWithNull = [
        { id: 1, name: 'Test', email: null },
        { id: 2, name: null, email: 'test@example.com' },
      ]
      const items = ref(itemsWithNull)
      const { search, filteredItems } = useBaseTable({
        items,
        searchFields: ['name', 'email'] as (keyof typeof itemsWithNull[0])[],
      })

      search.value = 'test'
      expect(filteredItems.value).toHaveLength(2)
    })
  })

  describe('pagination', () => {
    it('paginates filtered items', () => {
      const items = ref(testItems)
      const { paginatedItems, currentPage, perPage } = useBaseTable({
        items,
        searchFields: ['name'],
        perPage: 5,
      })

      expect(paginatedItems.value).toHaveLength(5)
      expect(paginatedItems.value[0].name).toBe('Alice')
      expect(paginatedItems.value[4].name).toBe('Eve')

      currentPage.value = 2
      expect(paginatedItems.value).toHaveLength(5)
      expect(paginatedItems.value[0].name).toBe('Frank')

      currentPage.value = 3
      expect(paginatedItems.value).toHaveLength(2)
      expect(paginatedItems.value[0].name).toBe('Kate')
    })

    it('resets to page 1 when search changes', async () => {
      const items = ref(testItems)
      const { search, currentPage } = useBaseTable({
        items,
        searchFields: ['name'],
        perPage: 5,
      })

      currentPage.value = 2
      expect(currentPage.value).toBe(2)

      search.value = 'alice'
      // Wait for watch to trigger
      await new Promise(resolve => setTimeout(resolve, 0))
      expect(currentPage.value).toBe(1)
    })

    it('calculates totalPages correctly', () => {
      const items = ref(testItems)
      const { totalPages } = useBaseTable({
        items,
        searchFields: ['name'],
        perPage: 5,
      })

      expect(totalPages.value).toBe(3)
    })
  })

  describe('computed properties', () => {
    it('isEmpty is true when no results', () => {
      const items = ref(testItems)
      const { search, isEmpty, hasResults } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      search.value = 'nonexistent'
      expect(isEmpty.value).toBe(true)
      expect(hasResults.value).toBe(false)
    })

    it('hasResults is true when there are results', () => {
      const items = ref(testItems)
      const { isEmpty, hasResults } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      expect(isEmpty.value).toBe(false)
      expect(hasResults.value).toBe(true)
    })
  })

  describe('helper methods', () => {
    it('resetPage resets to page 1', () => {
      const items = ref(testItems)
      const { currentPage, resetPage } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      currentPage.value = 3
      resetPage()
      expect(currentPage.value).toBe(1)
    })

    it('clearSearch clears search and resets page', () => {
      const items = ref(testItems)
      const { search, currentPage, clearSearch } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      search.value = 'test'
      currentPage.value = 3
      clearSearch()
      expect(search.value).toBe('')
      expect(currentPage.value).toBe(1)
    })
  })

  describe('localStorage persistence', () => {
    it('persists search and perPage to localStorage', async () => {
      const items = ref(testItems)
      const { search, perPage } = useBaseTable({
        items,
        searchFields: ['name'],
        persistKey: 'testTable',
      })

      search.value = 'alice'
      perPage.value = 20

      // Wait for watch to trigger
      await new Promise(resolve => setTimeout(resolve, 0))

      const stored = JSON.parse(localStorage.getItem('testTable')!)
      expect(stored.search).toBe('alice')
      expect(stored.perPage).toBe(20)
    })

    it('restores state from localStorage', () => {
      localStorage.setItem('testTable2', JSON.stringify({
        search: 'bob',
        perPage: 15,
      }))

      const items = ref(testItems)
      const { search, perPage } = useBaseTable({
        items,
        searchFields: ['name'],
        persistKey: 'testTable2',
      })

      expect(search.value).toBe('bob')
      expect(perPage.value).toBe(15)
    })

    it('handles invalid JSON in localStorage', () => {
      localStorage.setItem('testTable3', 'invalid json')

      const items = ref(testItems)
      const { search, perPage } = useBaseTable({
        items,
        searchFields: ['name'],
        persistKey: 'testTable3',
      })

      // Should use defaults
      expect(search.value).toBe('')
      expect(perPage.value).toBe(10)
    })
  })

  describe('reactive source', () => {
    it('updates when source items change', () => {
      const items = ref<TestItem[]>([])
      const { filteredItems, totalRows } = useBaseTable({
        items,
        searchFields: ['name'],
      })

      expect(totalRows.value).toBe(0)

      items.value = testItems
      expect(totalRows.value).toBe(12)
      expect(filteredItems.value).toHaveLength(12)
    })

    it('works with computed source', () => {
      const allItems = ref(testItems)
      const filterRole = ref('admin')
      const filteredByRole = computed(() =>
        allItems.value.filter(item => item.role === filterRole.value),
      )

      const { filteredItems, totalRows } = useBaseTable({
        items: filteredByRole,
        searchFields: ['name'],
      })

      expect(totalRows.value).toBe(4) // 4 admins

      filterRole.value = 'user'
      expect(totalRows.value).toBe(8) // 8 users
    })
  })
})
