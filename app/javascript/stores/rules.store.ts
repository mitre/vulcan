/**
 * Rules Store
 * Manages rule state for the Controls page
 * Uses Pinia Setup syntax (Composition API style) for full modernization
 *
 * Architecture: Slim data for list, full data on-demand with caching
 * - rules: ISlimRule[] - Minimal fields for table view (loaded once)
 * - fullRulesCache: Map<id, IRule> - Full data cached when user opens a rule
 * - currentRule: IRule - Currently selected rule (full data)
 *
 * Note: This store does NOT handle toasts directly - use the useRules() composable
 * for operations that need toast notifications.
 */

import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import type {
  IRule,
  ISlimRule,
  IRuleUpdate,
  ICheck,
  IDisaRuleDescription,
  IRuleDescription,
  IReviewCreate,
  IPagination,
} from '@/types'
import * as rulesApi from '@/apis/rules.api'

/**
 * Rule status constants
 */
export const RULE_STATUSES = [
  'Not Yet Determined',
  'Applicable - Configurable',
  'Applicable - Inherently Meets',
  'Applicable - Does Not Meet',
  'Not Applicable',
] as const

/**
 * Rule severity constants
 */
export const RULE_SEVERITIES = ['low', 'medium', 'high'] as const

/**
 * Severity display mapping
 */
export const SEVERITY_MAP: Record<string, string> = {
  low: 'CAT III',
  medium: 'CAT II',
  high: 'CAT I',
}

export const useRulesStore = defineStore('rules', () => {
  // ============================================
  // State
  // ============================================

  // Slim data for list view - loaded per page
  const rules = ref<ISlimRule[]>([])

  // Pagination state
  const pagination = ref<IPagination | null>(null)

  // Full data cache - populated on-demand when user opens a rule
  const fullRulesCache = ref<Map<number, IRule>>(new Map())

  // Currently selected rule (full data)
  const currentRule = ref<IRule | null>(null)

  const loading = ref(false)
  const error = ref<string | null>(null)
  const componentId = ref<number | null>(null)

  // UI state
  const showNestedRules = ref(true)
  const openRuleIds = ref<number[]>([])

  // ============================================
  // Getters (Computed)
  // ============================================

  /**
   * Sort rules by rule_id (e.g., "000001", "000002")
   */
  const sortedRules = computed(() => {
    return [...rules.value].sort((a, b) => a.rule_id.localeCompare(b.rule_id))
  })

  /**
   * Primary rules (not merged into another rule)
   * Uses is_merged boolean from slim data
   */
  const primaryRules = computed(() => {
    return sortedRules.value.filter(r => !r.is_merged)
  })

  /**
   * Nested rules (merged into another rule)
   * Uses is_merged boolean from slim data
   */
  const nestedRules = computed(() => {
    return sortedRules.value.filter(r => r.is_merged)
  })

  /**
   * Visible rules based on showNestedRules toggle
   */
  const visibleRules = computed(() => {
    return showNestedRules.value ? sortedRules.value : primaryRules.value
  })

  /**
   * Currently selected rule ID
   */
  const currentRuleId = computed(() => currentRule.value?.id ?? null)

  /**
   * Get slim rule by ID (for list operations)
   */
  function getSlimRuleById(id: number): ISlimRule | undefined {
    return rules.value.find(r => r.id === id)
  }

  /**
   * Get full rule by ID from cache (may be undefined if not loaded)
   */
  function getFullRuleById(id: number): IRule | undefined {
    return fullRulesCache.value.get(id)
  }

  /**
   * Get rules that satisfy a given rule (its children)
   * Requires full rule data to access satisfies array
   */
  function getChildRules(ruleId: number): ISlimRule[] {
    const fullRule = fullRulesCache.value.get(ruleId)
    if (!fullRule?.satisfies?.length) return []
    return fullRule.satisfies
      .map(sat => rules.value.find(r => r.rule_id === sat.rule_id))
      .filter(Boolean) as ISlimRule[]
  }

  // ============================================
  // Actions - Data fetching
  // ============================================

  /**
   * Fetch rules for a component (slim data)
   * Supports optional pagination via page/perPage params
   */
  async function fetchRules(compId: number, page?: number, perPage?: number) {
    loading.value = true
    error.value = null

    // Clear cache if switching to different component
    if (componentId.value !== compId) {
      fullRulesCache.value.clear()
      currentRule.value = null
      pagination.value = null
    }
    componentId.value = compId

    try {
      if (page) {
        // Paginated request
        const response = await rulesApi.getComponentRules(compId, { page, per_page: perPage })
        const data = response.data as { rules: ISlimRule[]; pagination: IPagination }
        rules.value = data.rules
        pagination.value = data.pagination
      } else {
        // Non-paginated (load all)
        const response = await rulesApi.getComponentRules(compId)
        rules.value = response.data as ISlimRule[]
        pagination.value = null
      }
      return rules.value
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to fetch rules'
      throw err
    }
    finally {
      loading.value = false
    }
  }

  /**
   * Go to specific page
   */
  async function goToPage(page: number) {
    if (!componentId.value) return
    await fetchRules(componentId.value, page, pagination.value?.per_page || 50)
  }

  /**
   * Fetch full data for a single rule
   * Caches the result for subsequent access
   */
  async function fetchFullRule(id: number): Promise<IRule> {
    // Check cache first
    const cached = fullRulesCache.value.get(id)
    if (cached) {
      return cached
    }

    try {
      const response = await rulesApi.getRule(id)
      const fullRule = response.data

      // Cache the full data
      fullRulesCache.value.set(id, fullRule)

      return fullRule
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to fetch rule'
      throw err
    }
  }

  /**
   * Refresh a single rule from the server
   * Updates both slim list and full cache
   */
  async function refreshRule(id: number) {
    try {
      const response = await rulesApi.getRule(id)
      const fullRule = response.data

      // Update full cache
      fullRulesCache.value.set(id, fullRule)

      // Update slim list with relevant fields
      const index = rules.value.findIndex(r => r.id === id)
      if (index !== -1) {
        rules.value.splice(index, 1, {
          id: fullRule.id,
          rule_id: fullRule.rule_id,
          version: fullRule.version,
          title: fullRule.title,
          status: fullRule.status,
          rule_severity: fullRule.rule_severity,
          locked: fullRule.locked,
          review_requestor_id: fullRule.review_requestor_id,
          is_merged: fullRule.satisfied_by?.length ? true : false,
        })
      }

      // Update currentRule if it's the one being refreshed
      if (currentRule.value?.id === id) {
        currentRule.value = fullRule
      }

      return fullRule
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to refresh rule'
      throw err
    }
  }

  // ============================================
  // Actions - CRUD operations
  // ============================================

  /**
   * Update a rule locally (optimistic update for slim data)
   * Used for immediate UI feedback before server confirms
   */
  function updateSlimRuleLocal(id: number, updates: Partial<ISlimRule>) {
    const index = rules.value.findIndex(r => r.id === id)
    if (index !== -1) {
      rules.value.splice(index, 1, { ...rules.value[index], ...updates })
    }
  }

  /**
   * Update full rule in cache
   */
  function updateFullRuleLocal(rule: IRule) {
    fullRulesCache.value.set(rule.id, rule)
    if (currentRule.value?.id === rule.id) {
      currentRule.value = rule
    }
  }

  /**
   * Update a rule on the server
   * Updates both slim list and full cache with response
   */
  async function updateRule(id: number, data: IRuleUpdate) {
    loading.value = true
    error.value = null

    try {
      const response = await rulesApi.updateRule(id, data)
      const fullRule = response.data.rule

      // Update full cache
      fullRulesCache.value.set(id, fullRule)

      // Update slim list with relevant fields
      const index = rules.value.findIndex(r => r.id === id)
      if (index !== -1) {
        rules.value.splice(index, 1, {
          id: fullRule.id,
          rule_id: fullRule.rule_id,
          version: fullRule.version,
          title: fullRule.title,
          status: fullRule.status,
          rule_severity: fullRule.rule_severity,
          locked: fullRule.locked,
          review_requestor_id: fullRule.review_requestor_id,
          is_merged: fullRule.satisfied_by?.length ? true : false,
        })
      }

      // Update currentRule
      if (currentRule.value?.id === id) {
        currentRule.value = fullRule
      }

      return response
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to update rule'
      throw err
    }
    finally {
      loading.value = false
    }
  }

  /**
   * Create a new rule
   * Adds to both slim list and full cache
   */
  async function createRule(data: Partial<IRule>, successCallback?: (rule: IRule) => void) {
    if (!componentId.value) {
      throw new Error('Component ID not set')
    }

    loading.value = true
    error.value = null

    try {
      const response = await rulesApi.createRule(componentId.value, data)
      const fullRule = response.data

      // Add to full cache
      fullRulesCache.value.set(fullRule.id, fullRule)

      // Add to slim list
      rules.value.push({
        id: fullRule.id,
        rule_id: fullRule.rule_id,
        version: fullRule.version,
        title: fullRule.title,
        status: fullRule.status,
        rule_severity: fullRule.rule_severity,
        locked: fullRule.locked,
        review_requestor_id: fullRule.review_requestor_id,
        is_merged: fullRule.satisfied_by?.length ? true : false,
      })

      if (successCallback) {
        successCallback(fullRule)
      }

      return response
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to create rule'
      throw err
    }
    finally {
      loading.value = false
    }
  }

  /**
   * Delete a rule
   * Removes from slim list, full cache, and open rules
   */
  async function deleteRule(id: number, successCallback?: () => void) {
    loading.value = true
    error.value = null

    try {
      await rulesApi.deleteRule(id)

      // Remove from slim list
      const index = rules.value.findIndex(r => r.id === id)
      if (index !== -1) {
        rules.value.splice(index, 1)
      }

      // Remove from full cache
      fullRulesCache.value.delete(id)

      // Clear current rule if it was deleted
      if (currentRule.value?.id === id) {
        currentRule.value = null
      }

      // Remove from open rules
      const openIndex = openRuleIds.value.indexOf(id)
      if (openIndex !== -1) {
        openRuleIds.value.splice(openIndex, 1)
      }

      if (successCallback) {
        successCallback()
      }
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to delete rule'
      throw err
    }
    finally {
      loading.value = false
    }
  }

  // ============================================
  // Actions - Check/Description mutations (local)
  // These operate on full rule data in cache and currentRule
  // ============================================

  /**
   * Add an empty check to a rule (operates on full data)
   */
  function addCheck(ruleId: number) {
    const rule = fullRulesCache.value.get(ruleId)
    if (!rule) return

    if (!rule.checks) {
      rule.checks = []
    }

    rule.checks.push({
      id: 0, // Will be assigned by server
      rule_id: ruleId,
      system: '',
      content_ref_name: '',
      content_ref_href: '',
      content: '',
    } as ICheck)

    // Update currentRule if it's the same rule
    if (currentRule.value?.id === ruleId) {
      currentRule.value = { ...rule }
    }
  }

  /**
   * Update a check at a specific index (operates on full data)
   */
  function updateCheck(ruleId: number, check: Partial<ICheck>, index: number) {
    if (index === -1) return

    const rule = fullRulesCache.value.get(ruleId)
    if (!rule?.checks) return

    rule.checks.splice(index, 1, { ...rule.checks[index], ...check })

    if (currentRule.value?.id === ruleId) {
      currentRule.value = { ...rule }
    }
  }

  /**
   * Add an empty rule description (operates on full data)
   */
  function addRuleDescription(ruleId: number) {
    const rule = fullRulesCache.value.get(ruleId)
    if (!rule) return

    if (!rule.rule_descriptions) {
      rule.rule_descriptions = []
    }

    rule.rule_descriptions.push({
      id: 0,
      rule_id: ruleId,
      label: '',
      description: '',
    } as IRuleDescription)

    if (currentRule.value?.id === ruleId) {
      currentRule.value = { ...rule }
    }
  }

  /**
   * Update a rule description at a specific index (operates on full data)
   */
  function updateRuleDescription(
    ruleId: number,
    description: Partial<IRuleDescription>,
    index: number
  ) {
    if (index === -1) return

    const rule = fullRulesCache.value.get(ruleId)
    if (!rule?.rule_descriptions) return

    rule.rule_descriptions.splice(index, 1, {
      ...rule.rule_descriptions[index],
      ...description,
    })

    if (currentRule.value?.id === ruleId) {
      currentRule.value = { ...rule }
    }
  }

  /**
   * Add an empty DISA rule description (operates on full data)
   */
  function addDisaRuleDescription(ruleId: number) {
    const rule = fullRulesCache.value.get(ruleId)
    if (!rule) return

    if (!rule.disa_rule_descriptions) {
      rule.disa_rule_descriptions = []
    }

    rule.disa_rule_descriptions.push({
      id: 0,
      rule_id: ruleId,
      vuln_discussion: '',
    } as IDisaRuleDescription)

    if (currentRule.value?.id === ruleId) {
      currentRule.value = { ...rule }
    }
  }

  /**
   * Update a DISA rule description at a specific index (operates on full data)
   */
  function updateDisaRuleDescription(
    ruleId: number,
    description: Partial<IDisaRuleDescription>,
    index: number
  ) {
    if (index === -1) return

    const rule = fullRulesCache.value.get(ruleId)
    if (!rule?.disa_rule_descriptions) return

    rule.disa_rule_descriptions.splice(index, 1, {
      ...rule.disa_rule_descriptions[index],
      ...description,
    })

    if (currentRule.value?.id === ruleId) {
      currentRule.value = { ...rule }
    }
  }

  // ============================================
  // Actions - Satisfaction (merge) operations
  // ============================================

  /**
   * Add a satisfaction relationship (merge rules)
   */
  async function addSatisfaction(
    ruleId: number,
    satisfiedByRuleId: number,
    successCallback?: () => void
  ) {
    try {
      await rulesApi.createRuleSatisfaction(ruleId, satisfiedByRuleId)

      // Refresh both rules to get updated relationships
      await Promise.all([refreshRule(ruleId), refreshRule(satisfiedByRuleId)])

      if (successCallback) {
        successCallback()
      }
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to merge rules'
      throw err
    }
  }

  /**
   * Remove a satisfaction relationship (unmerge)
   */
  async function removeSatisfaction(
    ruleId: number,
    satisfiedByRuleId: number,
    successCallback?: () => void
  ) {
    try {
      await rulesApi.deleteRuleSatisfaction(ruleId, satisfiedByRuleId)

      // Refresh both rules
      await Promise.all([refreshRule(ruleId), refreshRule(satisfiedByRuleId)])

      if (successCallback) {
        successCallback()
      }
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to unmerge rules'
      throw err
    }
  }

  // ============================================
  // Actions - Review operations
  // ============================================

  /**
   * Create a review action
   */
  async function createReview(ruleId: number, data: IReviewCreate) {
    try {
      await rulesApi.createReview(ruleId, data)
      await refreshRule(ruleId)
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to submit review'
      throw err
    }
  }

  /**
   * Lock a rule (admin action, skips review process)
   * Uses review system with 'lock_control' action
   */
  async function lockRule(ruleId: number, comment: string) {
    try {
      await rulesApi.createReview(ruleId, { action: 'lock_control', comment })
      await refreshRule(ruleId)
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to lock rule'
      throw err
    }
  }

  /**
   * Unlock a rule (admin action)
   * Uses review system with 'unlock_control' action
   */
  async function unlockRule(ruleId: number, comment: string) {
    try {
      await rulesApi.createReview(ruleId, { action: 'unlock_control', comment })
      await refreshRule(ruleId)
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to unlock rule'
      throw err
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
  ) {
    try {
      await rulesApi.revertRule(ruleId, auditId, fields, auditComment)
      await refreshRule(ruleId)
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to revert rule'
      throw err
    }
  }

  // ============================================
  // Actions - Selection / UI state
  // ============================================

  /**
   * Select a rule - fetches full data if not cached
   * This is the main entry point when user clicks a rule in the table
   */
  async function selectRule(id: number) {
    // Add to open rules if not already
    if (!openRuleIds.value.includes(id)) {
      openRuleIds.value.push(id)
    }

    // Persist to localStorage
    if (componentId.value) {
      localStorage.setItem(`selectedRuleId-${componentId.value}`, id.toString())
    }

    // Fetch full data (uses cache if available)
    const fullRule = await fetchFullRule(id)
    currentRule.value = fullRule
  }

  /**
   * Close a rule tab
   */
  function closeRule(id: number) {
    const index = openRuleIds.value.indexOf(id)
    if (index !== -1) {
      openRuleIds.value.splice(index, 1)
    }

    // If closing the current rule, select another open one from cache
    if (currentRule.value?.id === id) {
      const nextId = openRuleIds.value[0]
      // Get from full cache (if available) or set null
      currentRule.value = nextId ? fullRulesCache.value.get(nextId) || null : null
    }
  }

  /**
   * Toggle nested rules visibility
   */
  function toggleNestedRules() {
    showNestedRules.value = !showNestedRules.value
  }

  /**
   * Initialize selection from localStorage
   * Fetches full data for the saved rule if it exists
   */
  async function initSelection(compId: number) {
    const saved = localStorage.getItem(`selectedRuleId-${compId}`)
    if (saved) {
      const id = parseInt(saved, 10)
      if (rules.value.some(r => r.id === id)) {
        await selectRule(id)
      }
    }
  }

  /**
   * Set current rule directly (for full data)
   */
  function setCurrentRule(rule: IRule | null) {
    currentRule.value = rule
    if (rule) {
      fullRulesCache.value.set(rule.id, rule)
    }
  }

  /**
   * Reset store state
   */
  function reset() {
    rules.value = []
    pagination.value = null
    fullRulesCache.value.clear()
    currentRule.value = null
    loading.value = false
    error.value = null
    componentId.value = null
    showNestedRules.value = true
    openRuleIds.value = []
  }

  // ============================================
  // Return public API
  // ============================================
  return {
    // State
    rules,                // ISlimRule[] - list view data
    pagination,           // IPagination | null - pagination state
    fullRulesCache,       // Map<id, IRule> - full data cache
    currentRule,          // IRule | null - currently selected (full data)
    loading,
    error,
    componentId,
    showNestedRules,
    openRuleIds,

    // Getters
    sortedRules,
    primaryRules,
    nestedRules,
    visibleRules,
    currentRuleId,
    getSlimRuleById,      // Get slim rule from list
    getFullRuleById,      // Get full rule from cache
    getChildRules,

    // Actions - Data fetching
    fetchRules,           // Fetch slim data for component (with optional pagination)
    goToPage,             // Navigate to specific page
    fetchFullRule,        // Fetch/cache full data for single rule
    refreshRule,          // Refresh both slim and full data

    // Actions - CRUD
    updateSlimRuleLocal,  // Optimistic update for list
    updateFullRuleLocal,  // Update full cache entry
    updateRule,           // Server update (updates both)
    createRule,
    deleteRule,

    // Actions - Check/Description mutations (operate on full data)
    addCheck,
    updateCheck,
    addRuleDescription,
    updateRuleDescription,
    addDisaRuleDescription,
    updateDisaRuleDescription,

    // Actions - Satisfaction
    addSatisfaction,
    removeSatisfaction,

    // Actions - Review & Lock
    createReview,
    lockRule,
    unlockRule,
    revertRule,

    // Actions - Selection/UI
    selectRule,           // Now async - fetches full data
    closeRule,
    toggleNestedRules,
    initSelection,        // Now async
    setCurrentRule,
    reset,
  }
})
