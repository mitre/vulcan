/**
 * Rules Composable
 * Provides reactive access to Rules data and operations with toast notifications
 *
 * Architecture: Slim data for list, full data on-demand with caching
 * - rules: ISlimRule[] - Minimal data for table (loaded once)
 * - currentRule: IRule - Full data for editor (fetched on select)
 *
 * Pattern: Component → Composable → Store → API
 *
 * Usage:
 *   const { rules, currentRule, loading, error, updateRule, createRule, ... } = useRules()
 */

import type { IRule, ISlimRule, IRuleUpdate, IReviewCreate } from '@/types'
import { storeToRefs } from 'pinia'
import { useRulesStore, RULE_STATUSES, RULE_SEVERITIES, SEVERITY_MAP } from '@/stores/rules.store'
import { useAppToast } from './useToast'

export function useRules() {
  const store = useRulesStore()
  const toast = useAppToast()

  // Use storeToRefs to maintain reactivity when destructuring
  const {
    rules,              // ISlimRule[] - list view data
    pagination,         // IPagination | null - pagination state
    fullRulesCache,     // Map<id, IRule> - full data cache
    currentRule,        // IRule | null - currently selected (full)
    currentRuleId,
    loading,
    error,
    componentId,
    showNestedRules,
    openRuleIds,
    sortedRules,
    primaryRules,
    nestedRules,
    visibleRules,
  } = storeToRefs(store)

  // Functions accessed directly from store
  const getSlimRuleById = store.getSlimRuleById
  const getFullRuleById = store.getFullRuleById
  const getChildRules = store.getChildRules

  /**
   * Fetch all rules for a component (slim data)
   */
  async function fetchRules(compId: number, page?: number, perPage?: number) {
    try {
      await store.fetchRules(compId, page, perPage)
    } catch (err) {
      toast.error('Failed to load requirements')
    }
  }

  /**
   * Fetch full data for a single rule (with caching)
   */
  async function fetchFullRule(id: number): Promise<IRule | null> {
    try {
      return await store.fetchFullRule(id)
    } catch (err) {
      toast.error('Failed to load requirement details')
      return null
    }
  }

  /**
   * Refresh a single rule from the server
   * Updates both slim list and full cache
   */
  async function refreshRule(id: number) {
    try {
      return await store.refreshRule(id)
    } catch (err) {
      toast.error('Failed to refresh requirement')
      throw err
    }
  }

  /**
   * Update a rule on the server
   */
  async function updateRule(id: number, data: IRuleUpdate): Promise<boolean> {
    try {
      await store.updateRule(id, data)
      toast.success('Requirement saved')
      return true
    } catch (err) {
      toast.error('Failed to save requirement')
      return false
    }
  }

  /**
   * Create a new rule
   */
  async function createRule(
    data: Partial<IRule>,
    successCallback?: (rule: IRule) => void
  ): Promise<boolean> {
    try {
      await store.createRule(data, successCallback)
      toast.success('Requirement created')
      return true
    } catch (err) {
      toast.error('Failed to create requirement')
      return false
    }
  }

  /**
   * Delete a rule
   */
  async function deleteRule(id: number, successCallback?: () => void): Promise<boolean> {
    try {
      await store.deleteRule(id, successCallback)
      toast.success('Requirement deleted')
      return true
    } catch (err) {
      toast.error('Failed to delete requirement')
      return false
    }
  }

  /**
   * Add a satisfaction relationship (merge rules)
   */
  async function addSatisfaction(
    ruleId: number,
    satisfiedByRuleId: number,
    successCallback?: () => void
  ): Promise<boolean> {
    try {
      await store.addSatisfaction(ruleId, satisfiedByRuleId, successCallback)
      toast.success('Requirements merged')
      return true
    } catch (err) {
      toast.error('Failed to merge requirements')
      return false
    }
  }

  /**
   * Remove a satisfaction relationship (unmerge)
   */
  async function removeSatisfaction(
    ruleId: number,
    satisfiedByRuleId: number,
    successCallback?: () => void
  ): Promise<boolean> {
    try {
      await store.removeSatisfaction(ruleId, satisfiedByRuleId, successCallback)
      toast.success('Requirements unmerged')
      return true
    } catch (err) {
      toast.error('Failed to unmerge requirements')
      return false
    }
  }

  /**
   * Create a review action
   */
  async function createReview(ruleId: number, data: IReviewCreate): Promise<boolean> {
    try {
      await store.createReview(ruleId, data)
      toast.success('Review submitted')
      return true
    } catch (err) {
      toast.error('Failed to submit review')
      return false
    }
  }

  /**
   * Lock a rule (admin action)
   */
  async function lockRule(ruleId: number, comment: string): Promise<boolean> {
    try {
      await store.lockRule(ruleId, comment)
      toast.success('Requirement locked')
      return true
    } catch (err) {
      toast.error('Failed to lock requirement')
      return false
    }
  }

  /**
   * Unlock a rule (admin action)
   */
  async function unlockRule(ruleId: number, comment: string): Promise<boolean> {
    try {
      await store.unlockRule(ruleId, comment)
      toast.success('Requirement unlocked')
      return true
    } catch (err) {
      toast.error('Failed to unlock requirement')
      return false
    }
  }

  /**
   * Revert a rule to a historical version
   */
  async function revertRule(
    ruleId: number,
    auditId: number,
    fields: string[],
    auditComment?: string
  ): Promise<boolean> {
    try {
      await store.revertRule(ruleId, auditId, fields, auditComment)
      toast.success('Requirement reverted')
      return true
    } catch (err) {
      toast.error('Failed to revert requirement')
      return false
    }
  }

  /**
   * Local mutations (no API, no toast)
   * These operate on full rule data in cache
   */
  const updateSlimRuleLocal = store.updateSlimRuleLocal
  const updateFullRuleLocal = store.updateFullRuleLocal
  const addCheck = store.addCheck
  const updateCheck = store.updateCheck
  const addRuleDescription = store.addRuleDescription
  const updateRuleDescription = store.updateRuleDescription
  const addDisaRuleDescription = store.addDisaRuleDescription
  const updateDisaRuleDescription = store.updateDisaRuleDescription

  /**
   * Selection/UI actions
   * Note: selectRule and initSelection are now async (fetch full data)
   */
  const selectRule = store.selectRule
  const closeRule = store.closeRule
  const toggleNestedRules = store.toggleNestedRules
  const initSelection = store.initSelection
  const reset = store.reset

  // Pagination
  const goToPage = store.goToPage

  return {
    // Reactive state
    rules,              // ISlimRule[] - list view data
    pagination,         // IPagination | null
    fullRulesCache,     // Map<id, IRule> - full data cache
    currentRule,        // IRule | null - currently selected (full)
    currentRuleId,
    loading,
    error,
    componentId,
    showNestedRules,
    openRuleIds,

    // Computed getters
    sortedRules,
    primaryRules,
    nestedRules,
    visibleRules,
    getSlimRuleById,
    getFullRuleById,
    getChildRules,

    // Constants
    RULE_STATUSES,
    RULE_SEVERITIES,
    SEVERITY_MAP,

    // Actions with toasts
    fetchRules,
    fetchFullRule,
    refreshRule,
    goToPage,
    updateRule,
    createRule,
    deleteRule,
    addSatisfaction,
    removeSatisfaction,
    createReview,
    lockRule,
    unlockRule,
    revertRule,

    // Local mutations (no toast)
    updateSlimRuleLocal,
    updateFullRuleLocal,
    addCheck,
    updateCheck,
    addRuleDescription,
    updateRuleDescription,
    addDisaRuleDescription,
    updateDisaRuleDescription,

    // Selection/UI (selectRule, initSelection are async)
    selectRule,
    closeRule,
    toggleNestedRules,
    initSelection,
    reset,
  }
}

// Re-export constants for convenience
export { RULE_STATUSES, RULE_SEVERITIES, SEVERITY_MAP } from '@/stores/rules.store'
