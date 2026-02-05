import { describe, it, expect, vi, beforeEach } from 'vitest'
import { useDeleteConfirmation } from '@/composables/useDeleteConfirmation'

/**
 * useDeleteConfirmation Composable Tests
 *
 * REQUIREMENTS:
 *
 * 1. STATE MANAGEMENT:
 *    - showModal: Boolean - controls modal visibility
 *    - itemToDelete: Object|null - the item being deleted
 *    - isDeleting: Boolean - loading state during delete
 *
 * 2. METHODS:
 *    - openModal(item): Sets itemToDelete and shows modal
 *    - cancel(): Resets state and closes modal
 *    - confirm(deleteFn): Executes delete function with loading state
 *
 * 3. CONFIRM BEHAVIOR:
 *    - Sets isDeleting to true before calling deleteFn
 *    - Calls deleteFn with itemToDelete
 *    - On success: resets state, closes modal
 *    - On error: sets isDeleting to false, keeps modal open
 *    - Returns { success, error } result
 *
 * 4. REUSABLE:
 *    - Works for any item type (projects, components, users, STIGs, SRGs)
 *    - No assumptions about item structure
 */
describe('useDeleteConfirmation', () => {
  let composable

  beforeEach(() => {
    composable = useDeleteConfirmation()
  })

  // ==========================================
  // INITIAL STATE
  // ==========================================
  describe('initial state', () => {
    it('showModal starts as false', () => {
      expect(composable.showModal.value).toBe(false)
    })

    it('itemToDelete starts as null', () => {
      expect(composable.itemToDelete.value).toBe(null)
    })

    it('isDeleting starts as false', () => {
      expect(composable.isDeleting.value).toBe(false)
    })
  })

  // ==========================================
  // OPEN MODAL
  // ==========================================
  describe('openModal', () => {
    it('sets itemToDelete to the provided item', () => {
      const item = { id: 1, name: 'Test Project' }
      composable.openModal(item)
      expect(composable.itemToDelete.value).toEqual(item)
    })

    it('sets showModal to true', () => {
      composable.openModal({ id: 1 })
      expect(composable.showModal.value).toBe(true)
    })

    it('works with any item type', () => {
      const project = { id: 1, name: 'Project', type: 'project' }
      const user = { id: 2, email: 'test@test.com', type: 'user' }
      const stig = { id: 3, title: 'STIG Title', type: 'stig' }

      composable.openModal(project)
      expect(composable.itemToDelete.value).toEqual(project)

      composable.openModal(user)
      expect(composable.itemToDelete.value).toEqual(user)

      composable.openModal(stig)
      expect(composable.itemToDelete.value).toEqual(stig)
    })
  })

  // ==========================================
  // CANCEL
  // ==========================================
  describe('cancel', () => {
    it('sets showModal to false', () => {
      composable.openModal({ id: 1 })
      composable.cancel()
      expect(composable.showModal.value).toBe(false)
    })

    it('sets itemToDelete to null', () => {
      composable.openModal({ id: 1 })
      composable.cancel()
      expect(composable.itemToDelete.value).toBe(null)
    })

    it('sets isDeleting to false', () => {
      composable.isDeleting.value = true
      composable.cancel()
      expect(composable.isDeleting.value).toBe(false)
    })
  })

  // ==========================================
  // CONFIRM - SUCCESS
  // ==========================================
  describe('confirm - success', () => {
    it('sets isDeleting to true before calling deleteFn', async () => {
      const item = { id: 1 }
      let deletingDuringCall = false
      const deleteFn = vi.fn(async () => {
        deletingDuringCall = composable.isDeleting.value
      })

      composable.openModal(item)
      await composable.confirm(deleteFn)

      expect(deletingDuringCall).toBe(true)
    })

    it('calls deleteFn with itemToDelete', async () => {
      const item = { id: 1, name: 'Test' }
      const deleteFn = vi.fn(async () => {})

      composable.openModal(item)
      await composable.confirm(deleteFn)

      expect(deleteFn).toHaveBeenCalledWith(item)
    })

    it('sets showModal to false on success', async () => {
      const deleteFn = vi.fn(async () => {})

      composable.openModal({ id: 1 })
      await composable.confirm(deleteFn)

      expect(composable.showModal.value).toBe(false)
    })

    it('sets itemToDelete to null on success', async () => {
      const deleteFn = vi.fn(async () => {})

      composable.openModal({ id: 1 })
      await composable.confirm(deleteFn)

      expect(composable.itemToDelete.value).toBe(null)
    })

    it('sets isDeleting to false on success', async () => {
      const deleteFn = vi.fn(async () => {})

      composable.openModal({ id: 1 })
      await composable.confirm(deleteFn)

      expect(composable.isDeleting.value).toBe(false)
    })

    it('returns success: true on success', async () => {
      const deleteFn = vi.fn(async () => {})

      composable.openModal({ id: 1 })
      const result = await composable.confirm(deleteFn)

      expect(result.success).toBe(true)
      expect(result.error).toBe(null)
    })
  })

  // ==========================================
  // CONFIRM - ERROR
  // ==========================================
  describe('confirm - error', () => {
    it('sets isDeleting to false on error', async () => {
      const error = new Error('Delete failed')
      const deleteFn = vi.fn(async () => { throw error })

      composable.openModal({ id: 1 })
      await composable.confirm(deleteFn)

      expect(composable.isDeleting.value).toBe(false)
    })

    it('keeps showModal open on error', async () => {
      const deleteFn = vi.fn(async () => { throw new Error('Failed') })

      composable.openModal({ id: 1 })
      await composable.confirm(deleteFn)

      expect(composable.showModal.value).toBe(true)
    })

    it('keeps itemToDelete on error (for retry)', async () => {
      const item = { id: 1, name: 'Test' }
      const deleteFn = vi.fn(async () => { throw new Error('Failed') })

      composable.openModal(item)
      await composable.confirm(deleteFn)

      expect(composable.itemToDelete.value).toEqual(item)
    })

    it('returns success: false and error on failure', async () => {
      const error = new Error('Delete failed')
      const deleteFn = vi.fn(async () => { throw error })

      composable.openModal({ id: 1 })
      const result = await composable.confirm(deleteFn)

      expect(result.success).toBe(false)
      expect(result.error).toBe(error)
    })
  })

  // ==========================================
  // EDGE CASES
  // ==========================================
  describe('edge cases', () => {
    it('confirm does nothing if itemToDelete is null', async () => {
      const deleteFn = vi.fn(async () => {})

      const result = await composable.confirm(deleteFn)

      expect(deleteFn).not.toHaveBeenCalled()
      expect(result.success).toBe(false)
    })

    it('confirm does nothing if already deleting', async () => {
      const deleteFn = vi.fn(async () => {})

      composable.openModal({ id: 1 })
      composable.isDeleting.value = true

      const result = await composable.confirm(deleteFn)

      expect(deleteFn).not.toHaveBeenCalled()
      expect(result.success).toBe(false)
    })
  })
})
