/**
 * useToast Composable Unit Tests
 *
 * Note: This tests the wrapper functionality, not the underlying
 * Bootstrap-Vue-Next toast which requires a Vue app context.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'

// Import after mocking
import { useAppToast } from '../useToast'

// Mock bootstrap-vue-next's useToast with the create method
const mockCreate = vi.fn()
vi.mock('bootstrap-vue-next', () => ({
  useToast: () => ({
    create: mockCreate,
  }),
  BButton: 'BButton', // Mock BButton component
}))

describe('useAppToast', () => {
  beforeEach(() => {
    mockCreate.mockClear()
    // Default mock returns undefined (toast dismissed normally)
    mockCreate.mockResolvedValue({ ok: undefined })
  })

  describe('convenience methods', () => {
    it('success calls create with success variant', () => {
      const toast = useAppToast()
      toast.success('Test message')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Success',
          variant: 'success',
          body: 'Test message',
        }),
      )
    })

    it('success accepts custom title', () => {
      const toast = useAppToast()
      toast.success('Test message', 'Custom Title')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Custom Title',
          variant: 'success',
        }),
      )
    })

    it('error calls create with danger variant', () => {
      const toast = useAppToast()
      toast.error('Error message')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Error',
          variant: 'danger',
          body: 'Error message',
        }),
      )
    })

    it('warning calls create with warning variant', () => {
      const toast = useAppToast()
      toast.warning('Warning message')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Warning',
          variant: 'warning',
        }),
      )
    })

    it('info calls create with info variant', () => {
      const toast = useAppToast()
      toast.info('Info message')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Info',
          variant: 'info',
        }),
      )
    })
  })

  describe('fromResponse', () => {
    it('returns false when no toast data', () => {
      const toast = useAppToast()
      expect(toast.fromResponse({})).toBe(false)
      expect(toast.fromResponse({ data: {} })).toBe(false)
    })

    it('handles string toast data', () => {
      const toast = useAppToast()
      const result = toast.fromResponse({ data: { toast: 'Success!' } })

      expect(result).toBe(true)
      expect(mockCreate).toHaveBeenCalled()
    })

    it('handles object toast data', () => {
      const toast = useAppToast()
      const result = toast.fromResponse({
        data: {
          toast: {
            title: 'Custom',
            variant: 'warning',
            message: 'Test',
          },
        },
      })

      expect(result).toBe(true)
      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Custom',
          variant: 'warning',
        }),
      )
    })
  })

  describe('fromError', () => {
    it('extracts error message from response', () => {
      const toast = useAppToast()
      toast.fromError({
        response: { data: { error: 'API Error' } },
      })

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Error',
          variant: 'danger',
          body: 'API Error',
        }),
      )
    })

    it('joins array of errors', () => {
      const toast = useAppToast()
      toast.fromError({
        response: { data: { errors: ['Error 1', 'Error 2'] } },
      })

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'Error 1, Error 2',
        }),
      )
    })

    it('falls back to error message', () => {
      const toast = useAppToast()
      toast.fromError(new Error('Native error'))

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'Native error',
        }),
      )
    })

    it('uses default message when nothing available', () => {
      const toast = useAppToast()
      toast.fromError({})

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'An unexpected error occurred',
        }),
      )
    })
  })

  describe('exposes raw toast', () => {
    it('provides access to BVN toast', () => {
      const toast = useAppToast()
      expect(toast.raw).toBeDefined()
      expect(toast.raw.create).toBe(mockCreate)
    })
  })

  describe('successWithUndo', () => {
    it('calls create with slots pattern for interactive toast', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn()

      await toast.successWithUndo('Item deleted', onUndo)

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Success',
          variant: 'success',
          // Uses slots pattern, not body
          slots: expect.objectContaining({
            default: expect.any(Function),
          }),
        }),
        { resolveOnHide: true },
      )
    })

    it('accepts custom title', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn()

      await toast.successWithUndo('Item deleted', onUndo, 'Deleted')

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          title: 'Deleted',
        }),
        expect.anything(),
      )
    })

    it('has longer delay (8 seconds) for undo toasts', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn()

      await toast.successWithUndo('Item deleted', onUndo)

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          modelValue: 8000, // Longer delay for undo opportunity
        }),
        expect.anything(),
      )
    })

    it('does NOT call onUndo when toast times out normally', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn()

      // Mock: toast dismissed normally (no undo clicked)
      // BvTriggerableEvent has trigger property, ok is derived from trigger
      mockCreate.mockResolvedValueOnce({ trigger: undefined, ok: undefined })

      await toast.successWithUndo('Item deleted', onUndo)

      expect(onUndo).not.toHaveBeenCalled()
    })

    it('calls onUndo when user clicks Undo button', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn().mockResolvedValue(undefined)

      // Mock: user clicked undo - BvTriggerableEvent with trigger: 'undo'
      // ok is null for custom triggers (not 'ok' or 'cancel')
      mockCreate.mockResolvedValueOnce({ trigger: 'undo', ok: null })

      await toast.successWithUndo('Item deleted', onUndo)

      expect(onUndo).toHaveBeenCalledTimes(1)
    })

    it('shows error toast when onUndo callback fails', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn().mockRejectedValue(new Error('Undo failed'))

      // Mock: user clicked undo - BvTriggerableEvent with trigger: 'undo'
      mockCreate.mockResolvedValueOnce({ trigger: 'undo', ok: null })

      await toast.successWithUndo('Item deleted', onUndo)

      // onUndo was called
      expect(onUndo).toHaveBeenCalled()

      // Error toast was shown (second call to mockCreate)
      expect(mockCreate).toHaveBeenCalledTimes(2)
      expect(mockCreate).toHaveBeenLastCalledWith(
        expect.objectContaining({
          title: 'Error',
          variant: 'danger',
          body: 'Undo failed',
        }),
      )
    })

    it('slot function renders message and Undo button', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn()

      await toast.successWithUndo('Item deleted', onUndo)

      // Get the slots from the create call
      const createCall = mockCreate.mock.calls[0][0]
      const slotFn = createCall.slots.default

      // Call the slot function with a mock hide function
      const mockHide = vi.fn()
      const vnodes = slotFn({ hide: mockHide })

      // Verify VNode structure - returns array with wrapper div
      expect(vnodes).toBeDefined()
      expect(Array.isArray(vnodes)).toBe(true)
      expect(vnodes).toHaveLength(1)

      // The wrapper div contains message span and button
      const wrapperDiv = vnodes[0]
      expect(wrapperDiv.type).toBe('div')
      expect(wrapperDiv.children).toHaveLength(2)

      // First child is the message span
      expect(wrapperDiv.children[0].type).toBe('span')
      expect(wrapperDiv.children[0].children).toBe('Item deleted')

      // Second child is the Undo button
      expect(wrapperDiv.children[1].type).toBe('button')
      expect(wrapperDiv.children[1].children).toBe('Undo')
    })

    it('clicking Undo button calls hide with "undo" trigger', async () => {
      const toast = useAppToast()
      const onUndo = vi.fn()

      await toast.successWithUndo('Item deleted', onUndo)

      // Get the slots from the create call
      const createCall = mockCreate.mock.calls[0][0]
      const slotFn = createCall.slots.default

      // Call the slot function with a mock hide function
      const mockHide = vi.fn()
      const vnodes = slotFn({ hide: mockHide })

      // Get the button and simulate click
      const undoButton = vnodes[0].children[1]
      undoButton.props.onClick()

      expect(mockHide).toHaveBeenCalledWith('undo')
    })
  })
})
