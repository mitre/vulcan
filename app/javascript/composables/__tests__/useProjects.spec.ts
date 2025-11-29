/**
 * useProjects Composable Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useProjectsStore } from '@/stores'
import { useProjects } from '../useProjects'

// Mock the toast composable
vi.mock('../useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

// Mock the API module
vi.mock('@/apis/projects.api', () => ({
  getProjects: vi.fn(),
  getProject: vi.fn(),
  createProject: vi.fn(),
  updateProject: vi.fn(),
  deleteProject: vi.fn(),
}))

describe('useProjects', () => {
  let composable: ReturnType<typeof useProjects>
  let store: ReturnType<typeof useProjectsStore>

  beforeEach(() => {
    store = useProjectsStore()
    composable = useProjects()
  })

  describe('reactive state', () => {
    it('exposes projects as reactive ref', () => {
      expect(composable.projects.value).toEqual([])

      store.$patch({ projects: [{ id: 1, name: 'Test' }] as any })
      expect(composable.projects.value).toHaveLength(1)
    })

    it('exposes currentProject as reactive ref', () => {
      expect(composable.currentProject.value).toBeNull()

      store.$patch({ currentProject: { id: 1, name: 'Test' } as any })
      expect(composable.currentProject.value).toEqual({ id: 1, name: 'Test' })
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })

    it('exposes error as reactive ref', () => {
      expect(composable.error.value).toBeNull()

      store.$patch({ error: 'Test error' })
      expect(composable.error.value).toBe('Test error')
    })
  })

  describe('computed properties', () => {
    it('count returns projects length', () => {
      expect(composable.count.value).toBe(0)

      store.$patch({ projects: [{ id: 1 }, { id: 2 }, { id: 3 }] as any })
      expect(composable.count.value).toBe(3)
    })

    it('isEmpty returns true when no projects', () => {
      expect(composable.isEmpty.value).toBe(true)

      store.$patch({ projects: [{ id: 1 }] as any })
      expect(composable.isEmpty.value).toBe(false)
    })

    it('memberProjects filters correctly', () => {
      store.$patch({
        projects: [
          { id: 1, is_member: true },
          { id: 2, is_member: false },
        ] as any,
      })
      expect(composable.memberProjects.value).toHaveLength(1)
    })

    it('adminProjects filters correctly', () => {
      store.$patch({
        projects: [
          { id: 1, admin: true },
          { id: 2, admin: false },
        ] as any,
      })
      expect(composable.adminProjects.value).toHaveLength(1)
    })
  })

  describe('actions', () => {
    it('findById delegates to store getter', () => {
      const mockProject = { id: 42, name: 'Test Project' }
      store.$patch({ projects: [mockProject] as any })

      expect(composable.findById(42)).toEqual(mockProject)
      expect(composable.findById(999)).toBeUndefined()
    })

    it('reset clears store state', () => {
      store.$patch({
        projects: [{ id: 1 }] as any,
        loading: true,
        error: 'error',
      })

      composable.reset()

      expect(composable.projects.value).toEqual([])
      expect(composable.loading.value).toBe(false)
      expect(composable.error.value).toBeNull()
    })
  })
})
