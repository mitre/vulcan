/**
 * Tests for satisfaction removal confirmation dialog in RequirementsTable
 *
 * The confirmation dialog ensures users must confirm before removing
 * satisfaction relationships (destructive action).
 */

import { describe, expect, it, vi } from 'vitest'

// Simulating the component logic for satisfaction removal confirmation
function createSatisfactionConfirmationState(mockRules: Array<{ id: number, rule_id: string }>) {
  const showRemoveSatisfactionModal = { value: false }
  const satisfactionToRemove = {
    value: null as null | {
      childId: number
      parentId: number
      childRuleId: string
    },
  }
  const removingSatisfaction = { value: false }

  // Mock remove function
  const mockRemoveSatisfaction = vi.fn().mockResolvedValue(true)

  function handleRemoveSatisfactionFromIndicator(childRuleId: number, parentRuleId: number) {
    // Find the child rule to get its display ID
    const childRule = mockRules.find(r => r.id === childRuleId)
    satisfactionToRemove.value = {
      childId: childRuleId,
      parentId: parentRuleId,
      childRuleId: childRule?.rule_id || String(childRuleId),
    }
    showRemoveSatisfactionModal.value = true
  }

  async function confirmRemoveSatisfaction() {
    if (!satisfactionToRemove.value) return

    removingSatisfaction.value = true
    try {
      const { childId, parentId } = satisfactionToRemove.value
      await mockRemoveSatisfaction(childId, parentId)
      showRemoveSatisfactionModal.value = false
      satisfactionToRemove.value = null
    }
    finally {
      removingSatisfaction.value = false
    }
  }

  function cancelRemoveSatisfaction() {
    showRemoveSatisfactionModal.value = false
    satisfactionToRemove.value = null
  }

  return {
    showRemoveSatisfactionModal,
    satisfactionToRemove,
    removingSatisfaction,
    handleRemoveSatisfactionFromIndicator,
    confirmRemoveSatisfaction,
    cancelRemoveSatisfaction,
    mockRemoveSatisfaction,
  }
}

describe('satisfaction Removal Confirmation', () => {
  const mockRules = [
    { id: 1, rule_id: '000001' },
    { id: 2, rule_id: '000002' },
    { id: 3, rule_id: '000003' },
  ]

  describe('initial state', () => {
    it('starts with modal hidden', () => {
      const state = createSatisfactionConfirmationState(mockRules)
      expect(state.showRemoveSatisfactionModal.value).toBe(false)
    })

    it('starts with no satisfaction to remove', () => {
      const state = createSatisfactionConfirmationState(mockRules)
      expect(state.satisfactionToRemove.value).toBeNull()
    })

    it('starts with removingSatisfaction false', () => {
      const state = createSatisfactionConfirmationState(mockRules)
      expect(state.removingSatisfaction.value).toBe(false)
    })
  })

  describe('handleRemoveSatisfactionFromIndicator', () => {
    it('opens the modal', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)

      expect(state.showRemoveSatisfactionModal.value).toBe(true)
    })

    it('stores the satisfaction to remove with correct IDs', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)

      expect(state.satisfactionToRemove.value).toEqual({
        childId: 2,
        parentId: 1,
        childRuleId: '000002',
      })
    })

    it('does NOT call removeSatisfaction directly', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)

      expect(state.mockRemoveSatisfaction).not.toHaveBeenCalled()
    })

    it('looks up rule_id from rules array', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(3, 1)

      expect(state.satisfactionToRemove.value?.childRuleId).toBe('000003')
    })

    it('falls back to string ID if rule not found', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      // Rule 999 doesn't exist
      state.handleRemoveSatisfactionFromIndicator(999, 1)

      expect(state.satisfactionToRemove.value?.childRuleId).toBe('999')
    })
  })

  describe('confirmRemoveSatisfaction', () => {
    it('calls removeSatisfaction with correct IDs', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      await state.confirmRemoveSatisfaction()

      expect(state.mockRemoveSatisfaction).toHaveBeenCalledWith(2, 1)
    })

    it('closes the modal after confirmation', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      await state.confirmRemoveSatisfaction()

      expect(state.showRemoveSatisfactionModal.value).toBe(false)
    })

    it('clears satisfactionToRemove after confirmation', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      await state.confirmRemoveSatisfaction()

      expect(state.satisfactionToRemove.value).toBeNull()
    })

    it('sets removingSatisfaction to true during removal', async () => {
      const state = createSatisfactionConfirmationState(mockRules)
      let wasLoadingDuringRemoval = false

      // Make the mock async and capture loading state
      state.mockRemoveSatisfaction.mockImplementation(async () => {
        wasLoadingDuringRemoval = state.removingSatisfaction.value
        return true
      })

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      await state.confirmRemoveSatisfaction()

      expect(wasLoadingDuringRemoval).toBe(true)
    })

    it('sets removingSatisfaction back to false after removal', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      await state.confirmRemoveSatisfaction()

      expect(state.removingSatisfaction.value).toBe(false)
    })

    it('does nothing if no satisfaction to remove', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      await state.confirmRemoveSatisfaction()

      expect(state.mockRemoveSatisfaction).not.toHaveBeenCalled()
    })
  })

  describe('cancelRemoveSatisfaction', () => {
    it('closes the modal', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      state.cancelRemoveSatisfaction()

      expect(state.showRemoveSatisfactionModal.value).toBe(false)
    })

    it('clears satisfactionToRemove', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      state.cancelRemoveSatisfaction()

      expect(state.satisfactionToRemove.value).toBeNull()
    })

    it('does NOT call removeSatisfaction', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.handleRemoveSatisfactionFromIndicator(2, 1)
      state.cancelRemoveSatisfaction()

      expect(state.mockRemoveSatisfaction).not.toHaveBeenCalled()
    })
  })

  describe('error handling', () => {
    it('resets removingSatisfaction on error', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      state.mockRemoveSatisfaction.mockRejectedValueOnce(new Error('API Error'))

      state.handleRemoveSatisfactionFromIndicator(2, 1)

      // Should throw but still reset loading state
      await expect(state.confirmRemoveSatisfaction()).rejects.toThrow()
      expect(state.removingSatisfaction.value).toBe(false)
    })
  })

  describe('full workflow', () => {
    it('prevents accidental removal with confirmation step', async () => {
      const state = createSatisfactionConfirmationState(mockRules)

      // User clicks remove button
      state.handleRemoveSatisfactionFromIndicator(2, 1)

      // API should NOT have been called yet
      expect(state.mockRemoveSatisfaction).not.toHaveBeenCalled()

      // Modal should be open
      expect(state.showRemoveSatisfactionModal.value).toBe(true)

      // User confirms
      await state.confirmRemoveSatisfaction()

      // NOW the API should have been called
      expect(state.mockRemoveSatisfaction).toHaveBeenCalledTimes(1)
      expect(state.mockRemoveSatisfaction).toHaveBeenCalledWith(2, 1)
    })

    it('allows user to cancel without removing', () => {
      const state = createSatisfactionConfirmationState(mockRules)

      // User clicks remove button
      state.handleRemoveSatisfactionFromIndicator(2, 1)

      // User cancels
      state.cancelRemoveSatisfaction()

      // API should NOT have been called
      expect(state.mockRemoveSatisfaction).not.toHaveBeenCalled()

      // Modal should be closed
      expect(state.showRemoveSatisfactionModal.value).toBe(false)
    })
  })
})
