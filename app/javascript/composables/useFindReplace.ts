/**
 * Find & Replace Composable
 * THIN wrapper around the Pinia store
 *
 * Architecture: Layer 4 (Composable) - convenience wrapper, NO business logic
 * All state and logic lives in stores/findReplace.store.ts
 *
 * See docs-spa/FIND-REPLACE-ARCHITECTURE.md for full architecture.
 */

import { storeToRefs } from 'pinia'
import { useAppToast } from '@/composables/useToast'
import { useFindReplaceStore } from '@/stores/findReplace.store'

// Re-export types from API and store for convenience
export type { FieldMatch, MatchInstance, RuleMatch } from '@/apis/findReplace.api'
export type { FlatMatch, UndoEntry } from '@/stores/findReplace.store'

/**
 * Available fields for find/replace operations
 * Maps to Rails FindReplaceService::SEARCHABLE_FIELDS
 */
export const FIND_REPLACE_FIELDS = [
  'title',
  'fixtext',
  'vendor_comments',
  'status_justification',
  'artifact_description',
  'check',
  'vuln_discussion',
  'mitigations',
] as const

/**
 * Human-readable field labels
 */
export const FIELD_LABELS: Record<string, string> = {
  title: 'Title',
  fixtext: 'Fix',
  vendor_comments: 'Vendor Comments',
  status_justification: 'Status Justification',
  artifact_description: 'Artifact Description',
  check: 'Check',
  vuln_discussion: 'Vulnerability Discussion',
  mitigations: 'Mitigations',
}

/**
 * Find & Replace composable
 * Re-exports store state and actions with toast integration
 */
export function useFindReplace() {
  const store = useFindReplaceStore()
  const toast = useAppToast()

  // Get all reactive state from store
  const {
    searchText,
    replaceText,
    caseSensitive,
    selectedFields,
    rawMatches,
    totalMatches,
    totalRules,
    matches,
    currentIndex,
    loop,
    isSearching,
    isReplacing,
    undoStack,
    isOpen,
    // Computed
    currentMatch,
    hasNext,
    hasPrev,
    progress,
    summary,
    canUndo,
    hasResults,
    isLoading,
  } = storeToRefs(store)

  /**
   * Execute search with toast feedback
   */
  async function executeSearch(componentId: number): Promise<void> {
    if (!searchText.value || searchText.value.length < 2) {
      toast.warning('Please enter at least 2 characters to search')
      return
    }

    try {
      await store.search(componentId)
      if (matches.value.length === 0) {
        toast.info('No matches found')
      }
    }
    catch (error) {
      toast.error('Search failed')
      throw error
    }
  }

  /**
   * Replace current match with toast feedback
   */
  async function executeReplaceOne(componentId: number): Promise<void> {
    try {
      await store.replaceOne(componentId)
      toast.success('Replacement successful')
    }
    catch (error: any) {
      toast.error(error.message || 'Replace failed')
      throw error
    }
  }

  /**
   * Replace current match with custom text
   */
  async function executeReplaceOneWithCustom(
    componentId: number,
    customText: string,
  ): Promise<void> {
    try {
      await store.replaceOneWithCustom(componentId, customText)
      toast.success('Replacement successful')
    }
    catch (error: any) {
      toast.error(error.message || 'Replace failed')
      throw error
    }
  }

  /**
   * Replace all matches with toast feedback and confirmation
   */
  async function executeReplaceAll(
    componentId: number,
    auditComment?: string,
  ): Promise<void> {
    try {
      const result = await store.replaceAllMatches(componentId, auditComment)
      toast.success(
        `Replaced ${result.matchesReplaced} matches in ${result.rulesUpdated} rules`,
      )
    }
    catch (error: any) {
      toast.error(error.message || 'Replace all failed')
      throw error
    }
  }

  /**
   * Undo last replace with toast feedback
   */
  async function executeUndo(componentId: number): Promise<void> {
    try {
      await store.undoLast(componentId)
      toast.success('Undo successful')
    }
    catch (error: any) {
      toast.error(error.message || 'Undo failed')
      throw error
    }
  }

  return {
    // State (reactive refs from store)
    searchText,
    replaceText,
    caseSensitive,
    selectedFields,
    rawMatches,
    totalMatches,
    totalRules,
    matches,
    currentIndex,
    loop,
    isSearching,
    isReplacing,
    undoStack,
    isOpen,

    // Computed (reactive refs from store)
    currentMatch,
    hasNext,
    hasPrev,
    progress,
    summary,
    canUndo,
    hasResults,
    isLoading,

    // Navigation actions (direct from store, no toast needed)
    nextMatch: store.nextMatch,
    prevMatch: store.prevMatch,
    firstMatch: store.firstMatch,
    lastMatch: store.lastMatch,
    goToMatch: store.goToMatch,
    skip: store.skip,

    // Modal actions (direct from store)
    open: store.open,
    close: store.close,
    toggle: store.toggle,

    // State management actions (direct from store)
    reset: store.reset,
    resetAll: store.resetAll,
    setSearchText: store.setSearchText,
    setReplaceText: store.setReplaceText,
    toggleCaseSensitive: store.toggleCaseSensitive,
    setSelectedFields: store.setSelectedFields,
    toggleLoop: store.toggleLoop,

    // Actions with toast feedback (wrapped)
    executeSearch,
    executeReplaceOne,
    executeReplaceOneWithCustom,
    executeReplaceAll,
    executeUndo,

    // Aliases for common naming conventions
    findText: searchText, // Alternative name
    matchCase: caseSensitive, // Alternative name
    loading: isLoading, // Alternative name
  }
}
