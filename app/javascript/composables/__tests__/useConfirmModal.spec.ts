/**
 * useConfirmModal Composable Tests
 *
 * Tests for the programmatic confirmation dialog composable.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useConfirmModal } from '../useConfirmModal'

// Mock Bootstrap-Vue-Next useModal
const mockShow = vi.fn()
const mockCreate = vi.fn(() => ({
  show: mockShow,
}))

vi.mock('bootstrap-vue-next', () => ({
  useModal: () => ({
    create: mockCreate,
  }),
}))

describe('useConfirmModal', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('confirm', () => {
    it('creates a modal with correct default options', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirm } = useConfirmModal()
      await confirm('Are you sure?')

      expect(mockCreate).toHaveBeenCalledWith({
        title: 'Confirm',
        body: 'Are you sure?',
        okTitle: 'OK',
        cancelTitle: 'Cancel',
        centered: true,
      })
    })

    it('uses custom title when provided', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirm } = useConfirmModal()
      await confirm('Message', 'Custom Title')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Custom Title',
          body: 'Message',
        }),
      )
    })

    it('returns true when user clicks OK', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirm } = useConfirmModal()
      const result = await confirm('Test')

      expect(result).toBe(true)
    })

    it('returns false when user clicks Cancel', async () => {
      mockShow.mockResolvedValue({ ok: false })

      const { confirm } = useConfirmModal()
      const result = await confirm('Test')

      expect(result).toBe(false)
    })

    it('returns false when result is null', async () => {
      mockShow.mockResolvedValue(null)

      const { confirm } = useConfirmModal()
      const result = await confirm('Test')

      expect(result).toBe(false)
    })

    it('returns true when result is boolean true', async () => {
      mockShow.mockResolvedValue(true)

      const { confirm } = useConfirmModal()
      const result = await confirm('Test')

      expect(result).toBe(true)
    })

    it('returns false when result is boolean false', async () => {
      mockShow.mockResolvedValue(false)

      const { confirm } = useConfirmModal()
      const result = await confirm('Test')

      expect(result).toBe(false)
    })
  })

  describe('confirmDelete', () => {
    it('creates a modal with danger styling', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmDelete } = useConfirmModal()
      await confirmDelete('Delete this item?')

      expect(mockCreate).toHaveBeenCalledWith({
        title: 'Confirm Delete',
        body: 'Delete this item?',
        okTitle: 'Delete',
        okVariant: 'danger',
        cancelTitle: 'Cancel',
        centered: true,
        headerVariant: 'danger',
      })
    })

    it('includes item name in title when provided', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmDelete } = useConfirmModal()
      await confirmDelete('This will permanently delete the user.', 'User')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Delete User?',
        }),
      )
    })

    it('returns true on confirmation', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmDelete } = useConfirmModal()
      const result = await confirmDelete('Test')

      expect(result).toBe(true)
    })

    it('returns false on cancellation', async () => {
      mockShow.mockResolvedValue({ ok: false })

      const { confirmDelete } = useConfirmModal()
      const result = await confirmDelete('Test')

      expect(result).toBe(false)
    })
  })

  describe('confirmAction', () => {
    it('creates a modal with custom options', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmAction } = useConfirmModal()
      await confirmAction({
        title: 'Custom Title',
        body: 'Custom body text',
        okTitle: 'Proceed',
        cancelTitle: 'Go Back',
        okVariant: 'warning',
        size: 'lg',
      })

      expect(mockCreate).toHaveBeenCalledWith({
        title: 'Custom Title',
        body: 'Custom body text',
        okTitle: 'Proceed',
        cancelTitle: 'Go Back',
        okVariant: 'warning',
        cancelVariant: 'secondary',
        size: 'lg',
        centered: true,
        headerVariant: null,
      })
    })

    it('uses defaults for unspecified options', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmAction } = useConfirmModal()
      await confirmAction({})

      expect(mockCreate).toHaveBeenCalledWith({
        title: 'Confirm',
        body: 'Are you sure?',
        okTitle: 'OK',
        cancelTitle: 'Cancel',
        okVariant: 'primary',
        cancelVariant: 'secondary',
        size: 'md',
        centered: true,
        headerVariant: null,
      })
    })
  })

  describe('confirmWarning', () => {
    it('creates a modal with warning styling', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmWarning } = useConfirmModal()
      await confirmWarning('This action may have consequences.')

      expect(mockCreate).toHaveBeenCalledWith({
        title: 'Warning',
        body: 'This action may have consequences.',
        okTitle: 'Proceed',
        okVariant: 'warning',
        cancelTitle: 'Cancel',
        centered: true,
        headerVariant: 'warning',
      })
    })

    it('uses custom title when provided', async () => {
      mockShow.mockResolvedValue({ ok: true })

      const { confirmWarning } = useConfirmModal()
      await confirmWarning('Message', 'Caution')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Caution',
        }),
      )
    })
  })
})
