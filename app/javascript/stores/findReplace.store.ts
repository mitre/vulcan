/**
 * Find & Replace Store
 * Manages state for find and replace operations
 * Uses Pinia Setup syntax (Composition API style)
 *
 * Architecture: Layer 3 (Pinia Store) - All state and business logic
 * Navigation is client-side (no API calls for next/prev)
 * Backend provides stateless atomic operations
 *
 * See docs-spa/FIND-REPLACE-ARCHITECTURE.md for full architecture.
 * See FIND-REPLACE-REFERENCE-IMPLEMENTATIONS.md for VS Code patterns.
 */

import type {
  RuleMatch,
} from '@/apis/findReplace.api'
import type { IRule } from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as findReplaceApi from '@/apis/findReplace.api'

// ============================================================================
// Types
// ============================================================================

/**
 * Flattened match for navigation
 * Each instance gets its own entry for step-by-step navigation
 */
export interface FlatMatch {
  ruleId: number
  ruleIdentifier: string
  field: string
  index: number // Position in text
  length: number
  text: string // The matched text
  context: string // Surrounding text for display
  instanceIndex: number // Which occurrence in this field (0-based)
}

/**
 * Entry in the undo stack
 */
export interface UndoEntry {
  ruleId: number
  field: string
  previousValue: string
  timestamp: Date
}

// ============================================================================
// Store Definition
// ============================================================================

export const useFindReplaceStore = defineStore('findReplace', () => {
  // ============================================
  // State
  // ============================================

  // Search parameters
  const searchText = ref('')
  const replaceText = ref('')
  const caseSensitive = ref(false)
  const selectedFields = ref<string[]>([]) // Empty = all fields

  // Results from API
  const rawMatches = ref<RuleMatch[]>([])
  const totalMatches = ref(0)
  const totalRules = ref(0)

  // Flattened matches for navigation
  const matches = ref<FlatMatch[]>([])

  // Navigation state (client-side, no API calls)
  const currentIndex = ref(0)
  const loop = ref(true) // Wrap around at ends

  // Loading states
  const isSearching = ref(false)
  const isReplacing = ref(false)

  // Undo stack (client-side for immediate feedback)
  const undoStack = ref<UndoEntry[]>([])

  // Modal visibility
  const isOpen = ref(false)

  // ============================================
  // Getters (Computed)
  // ============================================

  /**
   * Current match at currentIndex
   */
  const currentMatch = computed<FlatMatch | null>(() => {
    if (matches.value.length === 0) return null
    return matches.value[currentIndex.value] ?? null
  })

  /**
   * Can navigate to next match
   */
  const hasNext = computed(() => {
    if (matches.value.length === 0) return false
    return loop.value || currentIndex.value < matches.value.length - 1
  })

  /**
   * Can navigate to previous match
   */
  const hasPrev = computed(() => {
    if (matches.value.length === 0) return false
    return loop.value || currentIndex.value > 0
  })

  /**
   * Progress string (e.g., "3 of 47")
   */
  const progress = computed(() => {
    if (matches.value.length === 0) return '0 of 0'
    return `${currentIndex.value + 1} of ${matches.value.length}`
  })

  /**
   * Summary string (e.g., "47 matches in 12 rules")
   */
  const summary = computed(() => {
    if (totalMatches.value === 0) return 'No matches'
    const matchWord = totalMatches.value === 1 ? 'match' : 'matches'
    const ruleWord = totalRules.value === 1 ? 'rule' : 'rules'
    return `${totalMatches.value} ${matchWord} in ${totalRules.value} ${ruleWord}`
  })

  /**
   * Can undo last operation
   */
  const canUndo = computed(() => undoStack.value.length > 0)

  /**
   * Has results to work with
   */
  const hasResults = computed(() => matches.value.length > 0)

  /**
   * Is currently loading (searching or replacing)
   */
  const isLoading = computed(() => isSearching.value || isReplacing.value)

  // ============================================
  // Private Helpers
  // ============================================

  /**
   * Flatten raw API response into individual matches for navigation
   */
  function flattenMatches(ruleMatches: RuleMatch[]): FlatMatch[] {
    const flat: FlatMatch[] = []

    for (const rule of ruleMatches) {
      for (const fieldMatch of rule.instances) {
        for (const instance of fieldMatch.instances) {
          flat.push({
            ruleId: rule.rule_id,
            ruleIdentifier: rule.rule_identifier,
            field: fieldMatch.field,
            index: instance.index,
            length: instance.length,
            text: instance.text,
            context: instance.context,
            instanceIndex: instance.instance_index ?? fieldMatch.instances.indexOf(instance),
          })
        }
      }
    }

    return flat
  }

  /**
   * Find the match closest to the previous position after refresh
   * Used to maintain position after a replace operation
   */
  function findClosestMatchIndex(
    oldMatch: FlatMatch | null,
    newMatches: FlatMatch[],
  ): number {
    if (!oldMatch || newMatches.length === 0) return 0

    // Try to find same rule + field
    const sameRuleField = newMatches.findIndex(
      m => m.ruleId === oldMatch.ruleId && m.field === oldMatch.field,
    )
    if (sameRuleField !== -1) return sameRuleField

    // Try to find same rule
    const sameRule = newMatches.findIndex(m => m.ruleId === oldMatch.ruleId)
    if (sameRule !== -1) return sameRule

    // Stay at same index if possible
    return Math.min(currentIndex.value, newMatches.length - 1)
  }

  // ============================================
  // Actions - Search
  // ============================================

  /**
   * Search for matches in a component
   * Populates the matches array for navigation
   */
  async function search(componentId: number): Promise<void> {
    if (!searchText.value || searchText.value.length < 2) {
      reset()
      return
    }

    isSearching.value = true

    try {
      const response = await findReplaceApi.find(componentId, {
        search: searchText.value,
        caseSensitive: caseSensitive.value,
        fields: selectedFields.value.length > 0 ? selectedFields.value : undefined,
      })

      // Store raw results
      rawMatches.value = response.matches
      totalMatches.value = response.total_matches
      totalRules.value = response.total_rules

      // Flatten for navigation
      matches.value = flattenMatches(response.matches)

      // Reset to first match
      currentIndex.value = 0
    }
    catch (error) {
      console.error('Find & Replace search failed:', error)
      reset()
      throw error
    }
    finally {
      isSearching.value = false
    }
  }

  // ============================================
  // Actions - Navigation (no API calls)
  // ============================================

  /**
   * Go to next match
   */
  function nextMatch(): void {
    if (matches.value.length === 0) return

    if (currentIndex.value < matches.value.length - 1) {
      currentIndex.value++
    }
    else if (loop.value) {
      currentIndex.value = 0
    }
  }

  /**
   * Go to previous match
   */
  function prevMatch(): void {
    if (matches.value.length === 0) return

    if (currentIndex.value > 0) {
      currentIndex.value--
    }
    else if (loop.value) {
      currentIndex.value = matches.value.length - 1
    }
  }

  /**
   * Jump to a specific match by index
   */
  function goToMatch(index: number): void {
    if (index >= 0 && index < matches.value.length) {
      currentIndex.value = index
    }
  }

  /**
   * Skip current match (alias for nextMatch)
   */
  function skip(): void {
    nextMatch()
  }

  /**
   * Jump to first match
   */
  function firstMatch(): void {
    if (matches.value.length === 0) return
    currentIndex.value = 0
  }

  /**
   * Jump to last match
   */
  function lastMatch(): void {
    if (matches.value.length === 0) return
    currentIndex.value = matches.value.length - 1
  }

  // ============================================
  // Actions - Replace
  // ============================================

  /**
   * Replace the current match with the global replaceText
   * Then refresh matches and advance
   */
  async function replaceOne(componentId: number): Promise<IRule | null> {
    const match = currentMatch.value
    if (!match) return null

    return replaceOneWithCustom(componentId, replaceText.value)
  }

  /**
   * Replace the current match with custom text
   * Allows per-instance replacement different from global replaceText
   */
  async function replaceOneWithCustom(
    componentId: number,
    customReplacement: string,
  ): Promise<IRule | null> {
    const match = currentMatch.value
    if (!match) return null

    isReplacing.value = true
    const previousMatch = { ...match }

    try {
      const response = await findReplaceApi.replaceInstance(componentId, {
        search: searchText.value,
        ruleId: match.ruleId,
        field: match.field,
        instanceIndex: match.instanceIndex,
        replacement: customReplacement,
        caseSensitive: caseSensitive.value,
        auditComment: `Find & Replace: "${searchText.value}" → "${customReplacement}"`,
      })

      if (!response.success) {
        throw new Error(response.error || 'Replace failed')
      }

      // Push to undo stack (client-side for immediate feedback)
      undoStack.value.push({
        ruleId: match.ruleId,
        field: match.field,
        previousValue: match.text,
        timestamp: new Date(),
      })

      // Refresh matches to get updated positions
      await search(componentId)

      // Try to stay at similar position
      const newIndex = findClosestMatchIndex(previousMatch, matches.value)
      currentIndex.value = newIndex

      return response.rule ?? null
    }
    catch (error) {
      console.error('Find & Replace replaceOne failed:', error)
      throw error
    }
    finally {
      isReplacing.value = false
    }
  }

  /**
   * Replace all matches with the global replaceText
   */
  async function replaceAllMatches(
    componentId: number,
    auditComment?: string,
  ): Promise<{ rulesUpdated: number, matchesReplaced: number }> {
    if (!searchText.value) {
      throw new Error('Search text required')
    }

    isReplacing.value = true

    try {
      const response = await findReplaceApi.replaceAll(componentId, {
        search: searchText.value,
        replacement: replaceText.value,
        caseSensitive: caseSensitive.value,
        fields: selectedFields.value.length > 0 ? selectedFields.value : undefined,
        auditComment: auditComment || `Find & Replace All: "${searchText.value}" → "${replaceText.value}"`,
      })

      if (!response.success) {
        throw new Error(response.error || 'Replace all failed')
      }

      // Clear matches after replace all
      reset()

      return {
        rulesUpdated: response.rules_updated,
        matchesReplaced: response.matches_replaced,
      }
    }
    catch (error) {
      console.error('Find & Replace replaceAll failed:', error)
      throw error
    }
    finally {
      isReplacing.value = false
    }
  }

  // ============================================
  // Actions - Undo
  // ============================================

  /**
   * Undo the last Find & Replace operation on a rule
   */
  async function undoLast(componentId: number): Promise<IRule | null> {
    const lastEntry = undoStack.value[undoStack.value.length - 1]
    if (!lastEntry) return null

    isReplacing.value = true

    try {
      const response = await findReplaceApi.undo(componentId, lastEntry.ruleId)

      if (!response.success) {
        throw new Error(response.error || 'Undo failed')
      }

      // Remove from undo stack
      undoStack.value.pop()

      // Refresh matches
      await search(componentId)

      return response.rule ?? null
    }
    catch (error) {
      console.error('Find & Replace undo failed:', error)
      throw error
    }
    finally {
      isReplacing.value = false
    }
  }

  // ============================================
  // Actions - Modal
  // ============================================

  /**
   * Open the Find & Replace modal
   */
  function open(): void {
    isOpen.value = true
  }

  /**
   * Close the Find & Replace modal
   */
  function close(): void {
    isOpen.value = false
  }

  /**
   * Toggle the modal
   */
  function toggle(): void {
    isOpen.value = !isOpen.value
  }

  // ============================================
  // Actions - State Management
  // ============================================

  /**
   * Reset all state
   */
  function reset(): void {
    rawMatches.value = []
    totalMatches.value = 0
    totalRules.value = 0
    matches.value = []
    currentIndex.value = 0
  }

  /**
   * Full reset including search parameters
   */
  function resetAll(): void {
    searchText.value = ''
    replaceText.value = ''
    caseSensitive.value = false
    selectedFields.value = []
    undoStack.value = []
    reset()
  }

  /**
   * Set search text (useful for pre-populating from selection)
   */
  function setSearchText(text: string): void {
    searchText.value = text
  }

  /**
   * Set replace text
   */
  function setReplaceText(text: string): void {
    replaceText.value = text
  }

  /**
   * Toggle case sensitivity
   */
  function toggleCaseSensitive(): void {
    caseSensitive.value = !caseSensitive.value
  }

  /**
   * Set selected fields
   */
  function setSelectedFields(fields: string[]): void {
    selectedFields.value = fields
  }

  /**
   * Toggle loop behavior
   */
  function toggleLoop(): void {
    loop.value = !loop.value
  }

  // ============================================
  // Return public API
  // ============================================
  return {
    // State
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

    // Getters
    currentMatch,
    hasNext,
    hasPrev,
    progress,
    summary,
    canUndo,
    hasResults,
    isLoading,

    // Actions - Search
    search,

    // Actions - Navigation
    nextMatch,
    prevMatch,
    firstMatch,
    lastMatch,
    goToMatch,
    skip,

    // Actions - Replace
    replaceOne,
    replaceOneWithCustom,
    replaceAllMatches,

    // Actions - Undo
    undoLast,

    // Actions - Modal
    open,
    close,
    toggle,

    // Actions - State Management
    reset,
    resetAll,
    setSearchText,
    setReplaceText,
    toggleCaseSensitive,
    setSelectedFields,
    toggleLoop,
  }
})
