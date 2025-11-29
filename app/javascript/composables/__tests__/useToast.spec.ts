/**
 * useToast Composable Unit Tests
 *
 * Note: This tests the wrapper functionality, not the underlying
 * Bootstrap-Vue-Next toast which requires a Vue app context.
 */

import { describe, expect, it, vi } from 'vitest'

// Import after mocking
import { useAppToast } from '../useToast'

// Mock bootstrap-vue-next's useToast
const mockShow = vi.fn()
vi.mock('bootstrap-vue-next', () => ({
  useToast: () => ({
    show: mockShow,
  }),
}))

describe('useAppToast', () => {
  beforeEach(() => {
    mockShow.mockClear()
  })

  describe('convenience methods', () => {
    it('success calls show with success variant', () => {
      const toast = useAppToast()
      toast.success('Test message')

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Success',
          variant: 'success',
          body: 'Test message',
        }),
      })
    })

    it('success accepts custom title', () => {
      const toast = useAppToast()
      toast.success('Test message', 'Custom Title')

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Custom Title',
          variant: 'success',
        }),
      })
    })

    it('error calls show with danger variant', () => {
      const toast = useAppToast()
      toast.error('Error message')

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Error',
          variant: 'danger',
          body: 'Error message',
        }),
      })
    })

    it('warning calls show with warning variant', () => {
      const toast = useAppToast()
      toast.warning('Warning message')

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Warning',
          variant: 'warning',
        }),
      })
    })

    it('info calls show with info variant', () => {
      const toast = useAppToast()
      toast.info('Info message')

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Info',
          variant: 'info',
        }),
      })
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
      expect(mockShow).toHaveBeenCalled()
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
      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Custom',
          variant: 'warning',
        }),
      })
    })
  })

  describe('fromError', () => {
    it('extracts error message from response', () => {
      const toast = useAppToast()
      toast.fromError({
        response: { data: { error: 'API Error' } },
      })

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          title: 'Error',
          variant: 'danger',
          body: 'API Error',
        }),
      })
    })

    it('joins array of errors', () => {
      const toast = useAppToast()
      toast.fromError({
        response: { data: { errors: ['Error 1', 'Error 2'] } },
      })

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          body: 'Error 1, Error 2',
        }),
      })
    })

    it('falls back to error message', () => {
      const toast = useAppToast()
      toast.fromError(new Error('Native error'))

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          body: 'Native error',
        }),
      })
    })

    it('uses default message when nothing available', () => {
      const toast = useAppToast()
      toast.fromError({})

      expect(mockShow).toHaveBeenCalledWith({
        props: expect.objectContaining({
          body: 'An unexpected error occurred',
        }),
      })
    })
  })

  describe('exposes raw toast', () => {
    it('provides access to BVN toast', () => {
      const toast = useAppToast()
      expect(toast.raw).toBeDefined()
      expect(toast.raw.show).toBe(mockShow)
    })
  })
})
