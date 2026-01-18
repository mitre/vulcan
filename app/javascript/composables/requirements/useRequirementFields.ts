/**
 * useRequirementFields Composable
 *
 * Provides reactive field configuration based on rule status.
 * This is the stable interface between UI components and field logic.
 *
 * Usage:
 *   const { showField, isDisabled, getTooltip, riskLevel } = useRequirementFields(statusRef)
 *
 * Or with a rule ref:
 *   const { showField, isDisabled, ... } = useRequirementFields(computed(() => rule.value?.status))
 */

import type { ComputedRef, Ref } from 'vue'
import type { RuleStatusType, StatusFieldConfig } from '@/config'
import { computed } from 'vue'
import {
  getFieldConfig,
  getFieldTooltip,
  getStatusRiskLevel,
  RISK_LEVEL_DESCRIPTIONS,
  RULE_STATUSES,

} from '@/config'

export interface UseRequirementFieldsReturn {
  // The current status
  status: ComputedRef<RuleStatusType>

  // Full field configuration for current status
  fieldConfig: ComputedRef<StatusFieldConfig>

  // Check if a field should be displayed
  showField: (fieldName: string, category?: 'rule' | 'disa' | 'check') => boolean

  // Check if a field should be disabled (readonly)
  isDisabled: (fieldName: string, category?: 'rule' | 'disa' | 'check') => boolean

  // Get tooltip text for a field
  getTooltip: (fieldName: string) => string | null

  // Risk level for current status
  riskLevel: ComputedRef<'none' | 'low' | 'medium' | 'high'>

  // Human-readable risk description
  riskDescription: ComputedRef<string>

  // All available statuses (for dropdowns)
  statuses: typeof RULE_STATUSES

  // Is this a "completed" status (not "Not Yet Determined")
  isStatusDetermined: ComputedRef<boolean>

  // Does this status require justification?
  requiresJustification: ComputedRef<boolean>

  // Does this status require artifact/evidence?
  requiresArtifact: ComputedRef<boolean>

  // Is this the main authoring status?
  isConfigurable: ComputedRef<boolean>
}

/**
 * Composable for requirement field configuration
 *
 * @param statusRef - Reactive reference to the current status string
 * @param canEditRef - Optional reactive reference to edit permission (defaults to true)
 */
export function useRequirementFields(
  statusRef: Ref<string | undefined> | ComputedRef<string | undefined>,
  canEditRef?: Ref<boolean> | ComputedRef<boolean>,
): UseRequirementFieldsReturn {
  // Normalize status to valid type
  const status = computed<RuleStatusType>(() => {
    const s = statusRef.value
    if (s && RULE_STATUSES.includes(s as RuleStatusType)) {
      return s as RuleStatusType
    }
    return 'Not Yet Determined'
  })

  // Get field configuration for current status
  const fieldConfig = computed(() => getFieldConfig(status.value))

  // Check if a field should be displayed
  function showField(fieldName: string, category: 'rule' | 'disa' | 'check' = 'rule'): boolean {
    return fieldConfig.value[category].displayed.includes(fieldName)
  }

  // Check if a field should be disabled
  function isDisabled(fieldName: string, category: 'rule' | 'disa' | 'check' = 'rule'): boolean {
    // If canEditRef is provided and false, everything is disabled
    if (canEditRef && !canEditRef.value) return true
    return fieldConfig.value[category].disabled.includes(fieldName)
  }

  // Get tooltip for a field
  function getTooltip(fieldName: string): string | null {
    return getFieldTooltip(status.value, fieldName)
  }

  // Risk level
  const riskLevel = computed(() => getStatusRiskLevel(status.value))

  // Risk description
  const riskDescription = computed(() => RISK_LEVEL_DESCRIPTIONS[riskLevel.value] || '')

  // Is status determined (not "Not Yet Determined")
  const isStatusDetermined = computed(() => status.value !== 'Not Yet Determined')

  // Does this status require justification?
  const requiresJustification = computed(() => {
    return [
      'Applicable - Inherently Meets',
      'Applicable - Does Not Meet',
      'Not Applicable',
    ].includes(status.value)
  })

  // Does this status require artifact/evidence?
  const requiresArtifact = computed(() => {
    return ['Applicable - Inherently Meets', 'Not Applicable'].includes(status.value)
  })

  // Is this the main authoring status?
  const isConfigurable = computed(() => status.value === 'Applicable - Configurable')

  return {
    status,
    fieldConfig,
    showField,
    isDisabled,
    getTooltip,
    riskLevel,
    riskDescription,
    statuses: RULE_STATUSES,
    isStatusDetermined,
    requiresJustification,
    requiresArtifact,
    isConfigurable,
  }
}

/**
 * Convenience composable that takes a rule object directly
 */
export function useRequirementFieldsFromRule(
  ruleRef: Ref<{ status?: string } | null | undefined>,
  canEditRef?: Ref<boolean> | ComputedRef<boolean>,
): UseRequirementFieldsReturn {
  const statusRef = computed(() => ruleRef.value?.status)
  return useRequirementFields(statusRef, canEditRef)
}
