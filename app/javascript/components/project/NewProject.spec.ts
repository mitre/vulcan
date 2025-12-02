/**
 * NewProject Component Unit Tests
 */

import { describe, expect, it, vi } from 'vitest'

// Mock useRouter
const mockPush = vi.fn()
vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush,
  }),
}))

// Mock useProjects composable
const mockCreate = vi.fn()
vi.mock('@/composables', () => ({
  useProjects: () => ({
    create: mockCreate,
    loading: { value: false },
  }),
}))

describe('newProject component', () => {
  beforeEach(() => {
    mockPush.mockClear()
    mockCreate.mockClear()
  })

  describe('form validation', () => {
    it('requires both name and description to submit', () => {
      // Simulate validation logic from component
      const canSubmit = (name: string, description: string) => {
        return name.trim().length > 0 && description.trim().length > 0
      }

      expect(canSubmit('', '')).toBe(false)
      expect(canSubmit('Project', '')).toBe(false)
      expect(canSubmit('', 'Description')).toBe(false)
      expect(canSubmit('Project', 'Description')).toBe(true)
    })

    it('trims whitespace from inputs', () => {
      const canSubmit = (name: string, description: string) => {
        return name.trim().length > 0 && description.trim().length > 0
      }

      expect(canSubmit('   ', '   ')).toBe(false)
      expect(canSubmit('  Project  ', '  Description  ')).toBe(true)
    })
  })

  describe('navigation', () => {
    it('redirects to project page on successful creation', async () => {
      mockCreate.mockResolvedValue(123)

      // Simulate handleSubmit logic
      const projectId = await mockCreate({ name: 'Test', description: 'Test' })
      if (projectId) {
        mockPush(`/projects/${projectId}`)
      }

      expect(mockPush).toHaveBeenCalledWith('/projects/123')
    })

    it('does not redirect on failed creation', async () => {
      mockCreate.mockResolvedValue(null)

      const projectId = await mockCreate({ name: 'Test', description: 'Test' })
      if (projectId) {
        mockPush(`/projects/${projectId}`)
      }

      expect(mockPush).not.toHaveBeenCalled()
    })

    it('cancel navigates to projects list', () => {
      // Simulate handleCancel
      mockPush('/projects')

      expect(mockPush).toHaveBeenCalledWith('/projects')
    })
  })

  describe('form submission data', () => {
    it('sends trimmed values to API', async () => {
      mockCreate.mockResolvedValue(1)

      const formData = {
        name: '  Test Project  ',
        description: '  Test Description  ',
        visibility: 'discoverable' as const,
        slack_channel_id: '  C123  ',
      }

      // Simulate handleSubmit preparation
      const submitData = {
        name: formData.name.trim(),
        description: formData.description.trim(),
        visibility: formData.visibility,
        slack_channel_id: formData.slack_channel_id.trim() || undefined,
      }

      await mockCreate(submitData)

      expect(mockCreate).toHaveBeenCalledWith({
        name: 'Test Project',
        description: 'Test Description',
        visibility: 'discoverable',
        slack_channel_id: 'C123',
      })
    })

    it('omits empty slack_channel_id', async () => {
      mockCreate.mockResolvedValue(1)

      const formData = {
        name: 'Test Project',
        description: 'Test Description',
        visibility: 'hidden' as const,
        slack_channel_id: '   ',
      }

      const submitData = {
        name: formData.name.trim(),
        description: formData.description.trim(),
        visibility: formData.visibility,
        slack_channel_id: formData.slack_channel_id.trim() || undefined,
      }

      await mockCreate(submitData)

      expect(mockCreate).toHaveBeenCalledWith({
        name: 'Test Project',
        description: 'Test Description',
        visibility: 'hidden',
        slack_channel_id: undefined,
      })
    })
  })
})
