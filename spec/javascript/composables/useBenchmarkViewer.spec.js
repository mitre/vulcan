import { describe, it, expect, beforeEach } from 'vitest'
import { useBenchmarkViewer } from '@/composables/useBenchmarkViewer'

/**
 * useBenchmarkViewer Composable Tests
 *
 * REQUIREMENTS:
 *
 * 1. TYPE-AGNOSTIC STATE:
 *    - selectedItem: Currently selected rule/requirement/control
 *    - items: List of all items from benchmark
 *    - filteredItems: Filtered/searched items
 *    - searchTerm: Current search query
 *
 * 2. NAVIGATION:
 *    - selectItem(item): Set selected item
 *    - selectNext(): Navigate to next item
 *    - selectPrevious(): Navigate to previous item
 *
 * 3. FILTERING:
 *    - setSearch(term): Filter items by search term
 *    - Searches across configured fields based on type
 *
 * 4. TYPE CONFIGURATION:
 *    - Accepts type ('stig' | 'srg' | 'cis')
 *    - Uses config to adapt to benchmark structure
 *    - Config defines: itemsKey, searchFields, displayFields
 *
 * 5. REUSABLE:
 *    - Works for STIG, SRG, CIS without code changes
 *    - Configuration-driven adaptation
 *
 * NOTE: Composable expects ADAPTED data (after stigToBenchmark/srgToBenchmark).
 * Test data uses "rules" property, NOT "rules" or "requirements".
 */
describe('useBenchmarkViewer', () => {
  let composable

  // ADAPTED STIG data (after stigToBenchmark adapter)
  const stigBenchmark = {
    id: 1,
    title: 'Test STIG',
    version: 'V1R1',
    rules: [
      { id: 1, rule_id: 'SV-001', title: 'Rule One', severity: 'high' },
      { id: 2, rule_id: 'SV-002', title: 'Rule Two', severity: 'medium' },
      { id: 3, rule_id: 'SV-003', title: 'Another Rule', severity: 'low' }
    ]
  }

  // ADAPTED SRG data (after srgToBenchmark adapter)
  const srgBenchmark = {
    id: 1,
    title: 'Test SRG',
    version: 'V2R1',
    rules: [
      { id: 1, rule_id: 'SRG-001', title: 'Requirement One' },
      { id: 2, rule_id: 'SRG-002', title: 'Requirement Two' }
    ]
  }

  beforeEach(() => {
    composable = useBenchmarkViewer(stigBenchmark, 'stig')
  })

  // ==========================================
  // INITIAL STATE
  // ==========================================
  describe('initial state', () => {
    it('initializes with benchmark data', () => {
      expect(composable.benchmark.value).toEqual(stigBenchmark)
    })

    it('extracts items from benchmark based on type config', () => {
      expect(composable.items.value.length).toBe(3)
      expect(composable.items.value).toEqual(stigBenchmark.rules)
    })

    it('selects first item by default', () => {
      expect(composable.selectedItem.value).toEqual(stigBenchmark.rules[0])
    })

    it('searchTerm starts empty', () => {
      expect(composable.searchTerm.value).toBe('')
    })

    it('filteredItems equals all items when no search', () => {
      expect(composable.filteredItems.value.length).toBe(3)
    })
  })

  // ==========================================
  // ITEM SELECTION
  // ==========================================
  describe('item selection', () => {
    it('selectItem sets the selected item', () => {
      const secondItem = stigBenchmark.rules[1]
      composable.selectItem(secondItem)
      expect(composable.selectedItem.value).toEqual(secondItem)
    })

    it('selectNext moves to next item', () => {
      expect(composable.selectedItem.value.id).toBe(1)
      composable.selectNext()
      expect(composable.selectedItem.value.id).toBe(2)
    })

    it('selectNext wraps to first item at end', () => {
      composable.selectItem(stigBenchmark.rules[2]) // Last item
      composable.selectNext()
      expect(composable.selectedItem.value.id).toBe(1) // Wraps to first
    })

    it('selectPrevious moves to previous item', () => {
      composable.selectItem(stigBenchmark.rules[1]) // Second item
      composable.selectPrevious()
      expect(composable.selectedItem.value.id).toBe(1) // First item
    })

    it('selectPrevious wraps to last item at start', () => {
      composable.selectItem(stigBenchmark.rules[0]) // First item
      composable.selectPrevious()
      expect(composable.selectedItem.value.id).toBe(3) // Wraps to last
    })
  })

  // ==========================================
  // SEARCH/FILTERING
  // ==========================================
  describe('search and filtering', () => {
    it('setSearch updates searchTerm', () => {
      composable.setSearch('rule')
      expect(composable.searchTerm.value).toBe('rule')
    })

    it('filters items based on search term', () => {
      composable.setSearch('Rule One')
      expect(composable.filteredItems.value.length).toBe(1)
      expect(composable.filteredItems.value[0].title).toBe('Rule One')
    })

    it('search is case-insensitive', () => {
      composable.setSearch('RULE ONE')
      expect(composable.filteredItems.value.length).toBe(1)
    })

    it('searches across multiple fields (title, rule_id)', () => {
      composable.setSearch('SV-002')
      expect(composable.filteredItems.value.length).toBe(1)
      expect(composable.filteredItems.value[0].rule_id).toBe('SV-002')
    })

    it('clears search shows all items', () => {
      composable.setSearch('Rule One')
      expect(composable.filteredItems.value.length).toBe(1)
      composable.setSearch('')
      expect(composable.filteredItems.value.length).toBe(3)
    })
  })

  // ==========================================
  // TYPE CONFIGURATION
  // ==========================================
  describe('type-specific configuration', () => {
    it('works with STIG type', () => {
      composable = useBenchmarkViewer(stigBenchmark, 'stig')
      expect(composable.items.value).toEqual(stigBenchmark.rules)
    })

    it('works with SRG type', () => {
      composable = useBenchmarkViewer(srgBenchmark, 'srg')
      expect(composable.items.value).toEqual(srgBenchmark.rules)
    })

    it('provides type info', () => {
      composable = useBenchmarkViewer(stigBenchmark, 'stig')
      expect(composable.benchmarkType.value).toBe('stig')
    })

    it('provides item type name from config', () => {
      composable = useBenchmarkViewer(stigBenchmark, 'stig')
      expect(composable.itemTypeName.value).toBe('rule')

      composable = useBenchmarkViewer(srgBenchmark, 'srg')
      expect(composable.itemTypeName.value).toBe('requirement')
    })
  })
})
