import { ref, computed } from 'vue'
import { findRules } from '@/apis/components.api'
import { updateRule } from '@/apis/rules.api'
import { useAppToast } from '@/composables/useToast'
import type { IRule, IRuleUpdate } from '@/types'

/**
 * Field name to object path mapping for find/replace operations
 */
const FIND_REPLACE_FIELD_PATHS: Record<string, (string | number)[]> = {
  'Status Justification': ['status_justification'],
  'Title': ['title'],
  'Artifact Description': ['artifact_description'],
  'Vulnerability Discussion': ['disa_rule_descriptions_attributes', 0, 'vuln_discussion'],
  'Mitigations': ['disa_rule_descriptions_attributes', 0, 'mitigations'],
  'Check': ['checks_attributes', 0, 'content'],
  'Fix': ['fixtext'],
  'Vendor Comments': ['vendor_comments'],
}

/**
 * All available field names for find/replace
 */
export const FIND_REPLACE_FIELDS = Object.keys(FIND_REPLACE_FIELD_PATHS)

/**
 * Text segment with highlighting info
 */
export interface ITextSegment {
  text: string
  highlighted: boolean
}

/**
 * Single field match within a rule
 */
export interface IFieldMatch {
  field: string
  value: string
  segments: ITextSegment[]
}

/**
 * All matches for a single rule
 */
export interface IRuleMatches {
  ruleId: number
  rule_id: string
  results: IFieldMatch[]
}

/**
 * Composable for find/replace operations across rule fields
 */
export function useFindReplace() {
  const toast = useAppToast()

  const loading = ref(false)
  const findText = ref('')
  const replaceText = ref('')
  const matchCase = ref(false)
  const selectedFields = ref<string[]>([...FIND_REPLACE_FIELDS])
  const searchResults = ref<Record<number, IRuleMatches>>({})
  const searchVersion = ref(0)
  const fullRulesCache = ref<Map<number, IRule>>(new Map())  // Cache full rules from search

  /**
   * Get value from rule using lodash-style path
   */
  function getValueAtPath(obj: any, path: (string | number)[]): string | undefined {
    let current = obj
    for (const key of path) {
      if (current == null) return undefined
      current = current[key]
    }
    return typeof current === 'string' ? current : undefined
  }

  /**
   * Set value in rule using lodash-style path
   */
  function setValueAtPath(obj: any, path: (string | number)[], value: string): void {
    let current = obj
    for (let i = 0; i < path.length - 1; i++) {
      const key = path[i]
      if (current[key] == null) {
        current[key] = typeof path[i + 1] === 'number' ? [] : {}
      }
      current = current[key]
    }
    current[path[path.length - 1]] = value
  }

  /**
   * Split text into segments, highlighting matches
   */
  function getSegments(value: string, searchText: string, caseSensitive: boolean): ITextSegment[] {
    const segments: ITextSegment[] = []
    const normalizedValue = caseSensitive ? value : value.toLowerCase()
    const normalizedSearch = caseSensitive ? searchText : searchText.toLowerCase()

    // Find all match indices
    const matchIndices: number[] = []
    let previousIndex = 0
    while (true) {
      const currentIndex = normalizedValue.indexOf(normalizedSearch, previousIndex)
      if (currentIndex < 0) break
      matchIndices.push(currentIndex)
      previousIndex = currentIndex + 1
    }

    // Build segments
    let currentIndex = 0
    matchIndices.forEach((matchIndex) => {
      // Non-highlighted text before match
      if (currentIndex < matchIndex) {
        segments.push({ text: value.substring(currentIndex, matchIndex), highlighted: false })
      }
      // Highlighted match
      currentIndex = matchIndex + searchText.length
      segments.push({ text: value.substring(matchIndex, currentIndex), highlighted: true })
    })

    // Remaining non-highlighted text
    if (currentIndex < value.length) {
      segments.push({ text: value.substring(currentIndex), highlighted: false })
    }

    return segments
  }

  /**
   * Group find results by rule
   */
  function groupFindResults(rules: IRule[], searchText: string, caseSensitive: boolean, fields: string[]): Record<number, IRuleMatches> {
    const normalizedSearch = caseSensitive ? searchText : searchText.toLowerCase()
    const results: Record<number, IRuleMatches> = {}

    rules.forEach((rule) => {
      fields.forEach((fieldName) => {
        const path = FIND_REPLACE_FIELD_PATHS[fieldName]
        if (!path) return

        const value = getValueAtPath(rule, path)
        if (!value) return

        const normalizedValue = caseSensitive ? value : value.toLowerCase()
        if (!normalizedValue.includes(normalizedSearch)) return

        const fieldMatch: IFieldMatch = {
          field: fieldName,
          value,
          segments: getSegments(value, searchText, caseSensitive),
        }

        if (rule.id in results) {
          results[rule.id].results.push(fieldMatch)
        } else {
          results[rule.id] = {
            ruleId: rule.id,
            rule_id: rule.rule_id,
            results: [fieldMatch],
          }
        }
      })
    })

    return results
  }

  /**
   * Replace text in rule field
   */
  function replaceTextInRule(rule: IRule, fieldName: string, segments: ITextSegment[], replacement: string): void {
    const path = FIND_REPLACE_FIELD_PATHS[fieldName]
    if (!path) return

    const modifiedText = segments
      .map((segment) => (segment.highlighted ? replacement : segment.text))
      .join('')

    setValueAtPath(rule, path, modifiedText)
  }

  /**
   * Total match count across all results
   */
  const totalMatches = computed(() => {
    return Object.values(searchResults.value).reduce((total, ruleMatches) => {
      return (
        total +
        ruleMatches.results.reduce((count, fieldMatch) => {
          return count + fieldMatch.segments.filter((s) => s.highlighted && s.text.length > 0).length
        }, 0)
      )
    }, 0)
  })

  /**
   * Total control count with matches
   */
  const totalControls = computed(() => {
    return Object.keys(searchResults.value).length
  })

  /**
   * Sorted results by rule_id
   */
  const sortedResults = computed(() => {
    return Object.entries(searchResults.value).sort(([, a], [, b]) => {
      return a.rule_id.localeCompare(b.rule_id)
    })
  })

  /**
   * Execute find operation
   */
  async function executeFind(componentId: number, rules: IRule[]): Promise<void> {
    if (!findText.value.trim()) {
      toast.warning('Please enter search text')
      return
    }

    loading.value = true
    try {
      // Backend search returns all rules with any text match (full rule data)
      const response = await findRules(componentId, findText.value)
      const fullRules = response.data as IRule[]

      // Cache full rules for replacement operations
      fullRulesCache.value.clear()
      fullRules.forEach((rule) => {
        fullRulesCache.value.set(rule.id, rule)
      })

      console.log('Cached full rules:', fullRulesCache.value.size, 'rules')

      // Client-side filtering by fields and case sensitivity
      searchResults.value = groupFindResults(fullRules, findText.value, matchCase.value, selectedFields.value)
      searchVersion.value += 1
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Find operation failed')
    } finally {
      loading.value = false
    }
  }

  /**
   * Replace single field in a rule
   */
  async function replaceOne(
    ruleId: number,
    rule: IRule,
    fieldMatch: IFieldMatch,
    comment: string,
    customReplacement?: string,
    onSuccess?: () => void
  ): Promise<void> {
    loading.value = true
    try {
      // Clone rule with JSON (simpler, works with API data)
      const updatedRule = JSON.parse(JSON.stringify(rule))

      const replacementText = customReplacement ?? replaceText.value
      replaceTextInRule(updatedRule, fieldMatch.field, fieldMatch.segments, replacementText)

      // Prepare update data with audit comment
      const updateData: IRuleUpdate = {
        ...updatedRule,
        audit_comment: comment || 'Find & Replace',
      }

      await updateRule(ruleId, updateData)

      toast.success('Replacement successful')
      if (onSuccess) onSuccess()
    } catch (error: any) {
      console.error('Replace failed with error:', error)
      toast.error(error.response?.data?.error || error.message || 'Replace failed')
    } finally {
      loading.value = false
    }
  }

  /**
   * Replace all matches across all rules
   */
  async function replaceAll(rules: IRule[], comment: string, onSuccess?: () => void): Promise<void> {
    loading.value = true
    try {
      const promises = Object.entries(searchResults.value).map(async ([ruleIdStr, ruleMatches]) => {
        const ruleId = Number(ruleIdStr)
        const originalRule = rules.find((r) => r.id === ruleId)
        if (!originalRule) return

        // Clone rule with JSON (avoids structuredClone issues)
        const updatedRule = JSON.parse(JSON.stringify(originalRule))
        ruleMatches.results.forEach((fieldMatch) => {
          replaceTextInRule(updatedRule, fieldMatch.field, fieldMatch.segments, replaceText.value)
        })

        const updateData: IRuleUpdate = {
          ...updatedRule,
          audit_comment: comment || 'Find & Replace (all)',
        }

        await updateRule(ruleId, updateData)
      })

      await Promise.all(promises)
      toast.success(`Replaced ${totalMatches.value} matches in ${totalControls.value} controls`)
      if (onSuccess) onSuccess()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Replace all failed')
    } finally {
      loading.value = false
    }
  }

  /**
   * Reset all state
   */
  function reset(): void {
    loading.value = false
    findText.value = ''
    replaceText.value = ''
    matchCase.value = false
    selectedFields.value = [...FIND_REPLACE_FIELDS]
    searchResults.value = {}
    searchVersion.value = 0
  }

  return {
    // State
    loading,
    findText,
    replaceText,
    matchCase,
    selectedFields,
    searchResults,
    searchVersion,
    fullRulesCache,

    // Computed
    totalMatches,
    totalControls,
    sortedResults,

    // Methods
    executeFind,
    replaceOne,
    replaceAll,
    reset,
  }
}
