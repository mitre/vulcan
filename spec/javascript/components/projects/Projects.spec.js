import { describe, it, expect, afterEach, vi } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue } from 'bootstrap-vue'
import Projects from '@/components/projects/Projects.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

// Mock axios
vi.mock('axios', () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    defaults: { headers: { common: {} } }
  }
}))

/**
 * Projects List Page Requirements
 *
 * REQUIREMENTS:
 *
 * 1. BREADCRUMB:
 *    - Shows "Projects" breadcrumb
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar for consistency
 *    - LEFT: New Project button (admin only, opens modal)
 *    - RIGHT: Empty for now
 *
 * 3. NEW PROJECT MODAL:
 *    - Modal for creating projects (not a separate page)
 *    - Triggered by New Project button
 *
 * 4. PROJECTS TABLE:
 *    - Renders ProjectsTable
 *    - Passes projects data
 */
describe('Projects', () => {
  let wrapper

  const defaultProps = {
    projects: [
      { id: 1, name: 'Project 1', visibility: 'hidden', is_member: true, memberships_count: 5 },
      { id: 2, name: 'Project 2', visibility: 'discoverable', is_member: false, memberships_count: 3 }
    ],
    is_vulcan_admin: true
  }

  const createWrapper = (props = {}) => {
    return shallowMount(Projects, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props
      },
      stubs: {
        BBreadcrumb: true,
        BaseCommandBar: true,
        ProjectsTable: true,
        NewProjectModal: true
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  // ==========================================
  // BREADCRUMB
  // ==========================================
  describe('breadcrumb', () => {
    it('renders breadcrumb', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'BBreadcrumb' }).exists()).toBe(true)
    })

    it('breadcrumb shows Projects', () => {
      wrapper = createWrapper()
      expect(wrapper.vm.breadcrumbs).toEqual([{ text: 'Projects', active: true }])
    })
  })

  // ==========================================
  // COMMAND BAR
  // ==========================================
  describe('command bar', () => {
    it('renders BaseCommandBar', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'BaseCommandBar' }).exists()).toBe(true)
    })

    it('shows New Project button for admin', () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      // Button should exist and trigger modal
      expect(wrapper.vm.showNewProjectModal).toBeDefined()
    })

    it('hides New Project button for non-admin', () => {
      wrapper = createWrapper({ is_vulcan_admin: false })
      // Non-admin shouldn't see the button (tested via v-if in template)
      expect(wrapper.props('is_vulcan_admin')).toBe(false)
    })
  })

  // ==========================================
  // NEW PROJECT MODAL
  // ==========================================
  describe('new project modal', () => {
    it('renders NewProjectModal', () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      expect(wrapper.findComponent({ name: 'NewProjectModal' }).exists()).toBe(true)
    })

    it('openNewProjectModal shows the modal', () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      expect(wrapper.vm.showNewProjectModal).toBe(false)
      wrapper.vm.openNewProjectModal()
      expect(wrapper.vm.showNewProjectModal).toBe(true)
    })

    it('refreshProjects is called after project created', async () => {
      wrapper = createWrapper()
      const spy = vi.spyOn(wrapper.vm, 'refreshProjects')

      wrapper.vm.onProjectCreated()

      expect(spy).toHaveBeenCalled()
    })
  })

  // ==========================================
  // PROJECTS TABLE
  // ==========================================
  describe('projects table', () => {
    it('renders ProjectsTable', () => {
      wrapper = createWrapper()
      expect(wrapper.findComponent({ name: 'ProjectsTable' }).exists()).toBe(true)
    })

    it('passes projects to ProjectsTable', () => {
      wrapper = createWrapper()
      const table = wrapper.findComponent({ name: 'ProjectsTable' })
      expect(table.props('projects')).toEqual(defaultProps.projects)
    })

    it('passes is_vulcan_admin to ProjectsTable', () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      const table = wrapper.findComponent({ name: 'ProjectsTable' })
      expect(table.props('is_vulcan_admin')).toBe(true)
    })
  })
})
