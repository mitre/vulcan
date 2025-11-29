/**
 * useRequirementEditor Composable
 *
 * Orchestrates editor state, validation, and save operations.
 * Composes from smaller composables for a clean component interface.
 *
 * Usage:
 *   const {
 *     // From useRequirementFields
 *     showField, isDisabled, getTooltip, riskLevel,
 *     // Editor state
 *     editedRule, isDirty, isValid, validationErrors,
 *     // Actions
 *     save, reset, markDirty
 *   } = useRequirementEditor(ruleRef, permissionsRef)
 */

import { computed, ref, watch, type Ref, type ComputedRef } from 'vue'
import type { IRule, IRuleUpdate } from '@/types'
import { useRules } from '@/composables/useRules'
import { useRequirementFields, type UseRequirementFieldsReturn } from './useRequirementFields'

export interface ValidationError {
  field: string
  message: string
}

export interface UseRequirementEditorReturn extends UseRequirementFieldsReturn {
  // Editor state
  editedRule: Ref<Partial<IRuleUpdate>>
  isDirty: Ref<boolean>
  isValid: ComputedRef<boolean>
  validationErrors: ComputedRef<ValidationError[]>

  // Permissions
  canEdit: ComputedRef<boolean>
  isMerged: ComputedRef<boolean>
  isLocked: ComputedRef<boolean>
  isUnderReview: ComputedRef<boolean>

  // DISA description helpers
  disaDescription: ComputedRef<any | null>
  editedDisaDescription: Ref<{
    id?: number
    vuln_discussion?: string
    mitigations?: string
    poam?: string
  }>
  mitigationsAvailable: Ref<boolean>
  poamAvailable: Ref<boolean>
  toggleMitigations: (value: boolean) => void
  togglePoam: (value: boolean) => void

  // Actions
  save: () => Promise<boolean>
  reset: () => void
  markDirty: () => void

  // Loading state from store
  loading: ComputedRef<boolean>
}

/**
 * Composable for requirement editor functionality
 *
 * @param ruleRef - Reactive reference to the rule being edited
 * @param effectivePermissions - User's permission level ('admin', 'author', 'reviewer', 'viewer')
 */
export function useRequirementEditor(
  ruleRef: Ref<IRule | null>,
  effectivePermissions: Ref<string> | ComputedRef<string>,
): UseRequirementEditorReturn {
  // Store for CRUD operations
  const { updateRule, loading } = useRules()

  // === Permissions ===
  const canEdit = computed(() => {
    if (!ruleRef.value) return false
    if (ruleRef.value.locked) return false
    if (ruleRef.value.review_requestor_id) return false
    if (ruleRef.value.satisfied_by && ruleRef.value.satisfied_by.length > 0) return false
    return ['admin', 'author', 'reviewer'].includes(effectivePermissions.value)
  })

  const isMerged = computed(() => {
    return !!(ruleRef.value?.satisfied_by && ruleRef.value.satisfied_by.length > 0)
  })

  const isLocked = computed(() => !!ruleRef.value?.locked)

  const isUnderReview = computed(() => !!ruleRef.value?.review_requestor_id)

  // === Field configuration (from useRequirementFields) ===
  const editedRule = ref<Partial<IRuleUpdate>>({})
  const currentStatus = computed(() => editedRule.value.status)

  const fieldHelpers = useRequirementFields(currentStatus, canEdit)

  // === Editor state ===
  const isDirty = ref(false)

  // === DISA description helpers (must be declared before watch) ===
  const disaDescription = computed(() => {
    return ruleRef.value?.disa_rule_descriptions?.[0] || null
  })

  const mitigationsAvailable = ref(false)
  const poamAvailable = ref(false)

  // Editable DISA description fields
  const editedDisaDescription = ref<{
    id?: number
    vuln_discussion?: string
    mitigations?: string
    poam?: string
  }>({})

  // Reset editor when rule changes
  watch(
    () => ruleRef.value,
    (newRule) => {
      if (newRule) {
        editedRule.value = {
          status: newRule.status,
          rule_severity: newRule.rule_severity,
          title: newRule.title || '',
          status_justification: newRule.status_justification || '',
          artifact_description: newRule.artifact_description || '',
          fixtext: newRule.fixtext || '',
          vendor_comments: newRule.vendor_comments || '',
        }
        isDirty.value = false

        // Reset DISA toggles and editable fields
        const disa = newRule.disa_rule_descriptions?.[0]
        mitigationsAvailable.value = disa?.mitigations_available || false
        poamAvailable.value = disa?.poam_available || false
        editedDisaDescription.value = {
          id: disa?.id,
          vuln_discussion: disa?.vuln_discussion || '',
          mitigations: disa?.mitigations || '',
          poam: disa?.poam || '',
        }
      }
    },
    { immediate: true },
  )

  // XOR logic for mitigations vs POA&M
  function toggleMitigations(value: boolean) {
    mitigationsAvailable.value = value
    if (value) {
      poamAvailable.value = false
    }
    markDirty()
  }

  function togglePoam(value: boolean) {
    poamAvailable.value = value
    if (value) {
      mitigationsAvailable.value = false
    }
    markDirty()
  }

  // === Validation ===
  const validationErrors = computed<ValidationError[]>(() => {
    const errors: ValidationError[] = []

    // Status justification required for certain statuses
    if (fieldHelpers.requiresJustification.value) {
      if (!editedRule.value.status_justification?.trim()) {
        errors.push({
          field: 'status_justification',
          message: 'Status justification is required',
        })
      }
    }

    // Artifact description required for certain statuses
    if (fieldHelpers.requiresArtifact.value) {
      if (!editedRule.value.artifact_description?.trim()) {
        errors.push({
          field: 'artifact_description',
          message: 'Artifact description is required',
        })
      }
    }

    // For "Does Not Meet", need either mitigations or POA&M
    if (currentStatus.value === 'Applicable - Does Not Meet') {
      if (!mitigationsAvailable.value && !poamAvailable.value) {
        errors.push({
          field: 'mitigations',
          message: 'Either Mitigations or POA&M must be specified',
        })
      }
    }

    return errors
  })

  const isValid = computed(() => validationErrors.value.length === 0)

  // === Actions ===
  function markDirty() {
    isDirty.value = true
  }

  function reset() {
    const rule = ruleRef.value
    if (rule) {
      editedRule.value = {
        status: rule.status,
        rule_severity: rule.rule_severity,
        title: rule.title || '',
        status_justification: rule.status_justification || '',
        artifact_description: rule.artifact_description || '',
        fixtext: rule.fixtext || '',
        vendor_comments: rule.vendor_comments || '',
      }
      isDirty.value = false
    }
  }

  async function save(): Promise<boolean> {
    if (!ruleRef.value || !isDirty.value) return false
    if (!isValid.value) return false

    // Build payload with DISA attributes if they have an id
    const payload = { ...editedRule.value }
    if (editedDisaDescription.value.id) {
      payload.disa_rule_descriptions_attributes = [{
        id: editedDisaDescription.value.id,
        vuln_discussion: editedDisaDescription.value.vuln_discussion,
        mitigations: mitigationsAvailable.value ? editedDisaDescription.value.mitigations : null,
        mitigations_available: mitigationsAvailable.value,
        poam: poamAvailable.value ? editedDisaDescription.value.poam : null,
        poam_available: poamAvailable.value,
      }]
    }

    const success = await updateRule(ruleRef.value.id, payload)
    if (success) {
      isDirty.value = false
    }
    return success
  }

  // === Return combined interface ===
  return {
    // Spread all field helpers
    ...fieldHelpers,

    // Editor state
    editedRule,
    isDirty,
    isValid,
    validationErrors,

    // Permissions
    canEdit,
    isMerged,
    isLocked,
    isUnderReview,

    // DISA helpers
    disaDescription,
    editedDisaDescription,
    mitigationsAvailable,
    poamAvailable,
    toggleMitigations,
    togglePoam,

    // Actions
    save,
    reset,
    markDirty,

    // Loading
    loading: computed(() => loading.value),
  }
}
