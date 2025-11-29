/**
 * Projects Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useProjectsStore } from '../projects.store'

// Mock the API module
vi.mock('@/apis/projects.api', () => ({
  getProjects: vi.fn(),
  getProject: vi.fn(),
  createProject: vi.fn(),
  updateProject: vi.fn(),
  deleteProject: vi.fn(),
}))

describe('projects Store', () => {
  let store: ReturnType<typeof useProjectsStore>

  beforeEach(() => {
    store = useProjectsStore()
  })

  describe('initial state', () => {
    it('has empty projects array', () => {
      expect(store.projects).toEqual([])
    })

    it('has null currentProject', () => {
      expect(store.currentProject).toBeNull()
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })

    it('has error null', () => {
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    it('projectCount returns projects length', () => {
      expect(store.projectCount).toBe(0)
      store.$patch({ projects: [{ id: 1 }, { id: 2 }] as any })
      expect(store.projectCount).toBe(2)
    })

    it('getProjectById finds project by id', () => {
      const mockProject = { id: 42, name: 'Test Project' }
      store.$patch({ projects: [mockProject] as any })
      expect(store.getProjectById(42)).toEqual(mockProject)
      expect(store.getProjectById(999)).toBeUndefined()
    })

    it('memberProjects filters by is_member', () => {
      store.$patch({
        projects: [
          { id: 1, is_member: true },
          { id: 2, is_member: false },
          { id: 3, is_member: true },
        ] as any,
      })
      expect(store.memberProjects).toHaveLength(2)
      expect(store.memberProjects.map(p => p.id)).toEqual([1, 3])
    })

    it('adminProjects filters by admin', () => {
      store.$patch({
        projects: [
          { id: 1, admin: true },
          { id: 2, admin: false },
          { id: 3, admin: true },
        ] as any,
      })
      expect(store.adminProjects).toHaveLength(2)
    })
  })

  describe('actions', () => {
    it('setCurrentProject updates currentProject', () => {
      const mockProject = { id: 1, name: 'Test' } as any
      store.setCurrentProject(mockProject)
      expect(store.currentProject).toEqual(mockProject)

      store.setCurrentProject(null)
      expect(store.currentProject).toBeNull()
    })

    it('reset clears all state', () => {
      store.$patch({
        projects: [{ id: 1 }] as any,
        currentProject: { id: 1 } as any,
        loading: true,
        error: 'some error',
      })

      store.reset()

      expect(store.projects).toEqual([])
      expect(store.currentProject).toBeNull()
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })
})
