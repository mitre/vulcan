/**
 * Requirements Composables
 *
 * Hierarchical composables for the requirements/controls interface.
 *
 * Architecture:
 *   useRequirementFields   - Status → fields configuration (base layer)
 *   useRequirementEditor   - Editor state, validation, save (orchestrator)
 *   useRequirementProgress - Bucketing progress tracking
 *
 * Usage in components:
 *   // For editors - use the orchestrator
 *   const { showField, editedRule, save } = useRequirementEditor(ruleRef, permissionsRef)
 *
 *   // For read-only display - use fields directly
 *   const { showField, riskLevel } = useRequirementFields(statusRef)
 *
 *   // For progress bars - use progress
 *   const { percentComplete, progressSummary } = useRequirementProgress()
 */

// Orchestrator - editor state and actions
export {
  useRequirementEditor,
  type UseRequirementEditorReturn,
  type ValidationError,
} from './useRequirementEditor'

// Base layer - status to fields mapping
export {
  useRequirementFields,
  useRequirementFieldsFromRule,
  type UseRequirementFieldsReturn,
} from './useRequirementFields'

// Progress tracking
export {
  type StatusCount,
  useRequirementProgress,
  type UseRequirementProgressReturn,
} from './useRequirementProgress'
