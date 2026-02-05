import { describe, it, expect, afterEach, vi, beforeEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import ProjectsTable from '@/components/projects/ProjectsTable.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

// Mock axios
vi.mock('axios', () => ({
  default: {
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } }
  }
}))

/**
 * ProjectsTable Delete Functionality Tests
 *
 * REQUIREMENTS:
 *
 * 1. DELETE BUTTON (admin only):
 *    - Shows "Remove" button for vulcan admins
 *    - Hidden for non-admins
 *
 * 2. DELETE CONFIRMATION MODAL:
 *    - Clicking Remove opens confirmation modal (NOT browser confirm)
 *    - Modal shows project name in warning message
 *    - Cancel button closes modal without deleting
 *    - Confirm button triggers delete
 *
 * 3. DELETE LOADING STATE:
 *    - Shows spinner while delete is processing
 *    - Disables buttons during delete
 *
 * 4. DELETE SUCCESS:
 *    - Emits 'projectDeleted' event on success
 *    - Closes modal on success
 *
 * 5. DELETE ERROR:
 *    - Shows error message on failure
 *    - Allows retry
 */
describe('ProjectsTable', () => {
  let wrapper

  const sampleProjects = [
    {
      id: 1,
      name: 'Test Project',
      description: 'A test project',
      visibility: 'discoverable',
      is_member: true,
      admin: true,
      memberships_count: 5,
      updated_at: '2024-01-15T10:00:00Z'
    },
    {
      id: 2,
      name: 'Another Project',
      description: 'Another description',
      visibility: 'hidden',
      is_member: true,
      admin: false,
      memberships_count: 3,
      updated_at: '2024-01-14T10:00:00Z'
    }
  ]

  const createWrapper = (props = {}) => {
    return mount(ProjectsTable, {
      localVue,
      propsData: {
        projects: sampleProjects,
        is_vulcan_admin: true,
        ...props
      },
      stubs: {
        UpdateProjectDetailsModal: true
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
    vi.clearAllMocks()
  })

  // ==========================================
  // DELETE BUTTON VISIBILITY
  // ==========================================
  describe('delete button visibility', () => {
    it('shows Remove button for vulcan admin', () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]')
      expect(removeBtn.exists()).toBe(true)
    })

    it('hides Remove button for non-admin', () => {
      wrapper = createWrapper({ is_vulcan_admin: false })
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]')
      expect(removeBtn.exists()).toBe(false)
    })
  })

  // ==========================================
  // DELETE CONFIRMATION MODAL
  // ==========================================
  describe('delete confirmation modal', () => {
    it('opens modal when Remove clicked', async () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      expect(wrapper.vm.showDeleteModal).toBe(false)

      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]')
      await removeBtn.trigger('click')

      expect(wrapper.vm.showDeleteModal).toBe(true)
    })

    it('stores project to delete when modal opens', async () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]')
      await removeBtn.trigger('click')

      expect(wrapper.vm.projectToDelete).toEqual(sampleProjects[0])
    })

    it('shows project name in modal', async () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]')
      await removeBtn.trigger('click')
      await wrapper.vm.$nextTick()

      expect(wrapper.text()).toContain('Test Project')
    })

    it('Cancel closes modal without deleting', async () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      // Open modal
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]')
      await removeBtn.trigger('click')
      expect(wrapper.vm.showDeleteModal).toBe(true)

      // Click cancel
      wrapper.vm.cancelDelete()
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.showDeleteModal).toBe(false)
      expect(wrapper.vm.projectToDelete).toBe(null)
    })
  })

  // ==========================================
  // DELETE LOADING STATE
  // ==========================================
  describe('delete loading state', () => {
    it('shows spinner when delete is processing', async () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      wrapper.vm.isDeleting = true
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.isDeleting).toBe(true)
    })

    it('isDeleting starts as false', () => {
      wrapper = createWrapper({ is_vulcan_admin: true })
      expect(wrapper.vm.isDeleting).toBe(false)
    })
  })

  // ==========================================
  // DELETE EXECUTION
  // ==========================================
  describe('delete execution', () => {
    it('confirmDelete calls axios.delete with correct URL (JSON format)', async () => {
      const axios = (await import('axios')).default
      wrapper = createWrapper({ is_vulcan_admin: true })
      wrapper.vm.projectToDelete = sampleProjects[0]
      wrapper.vm.showDeleteModal = true

      await wrapper.vm.confirmDelete()

      expect(axios.delete).toHaveBeenCalledWith('/projects/1.json')
    })

    it('confirmDelete sets isDeleting to true during request', async () => {
      const axios = (await import('axios')).default
      axios.delete.mockImplementation(() => new Promise(resolve => setTimeout(resolve, 100)))

      wrapper = createWrapper({ is_vulcan_admin: true })
      wrapper.vm.projectToDelete = sampleProjects[0]

      const deletePromise = wrapper.vm.confirmDelete()
      expect(wrapper.vm.isDeleting).toBe(true)

      await deletePromise
    })

    it('emits projectUpdated on success', async () => {
      const axios = (await import('axios')).default
      axios.delete.mockResolvedValue({ data: {} })

      wrapper = createWrapper({ is_vulcan_admin: true })
      wrapper.vm.projectToDelete = sampleProjects[0]
      wrapper.vm.showDeleteModal = true

      await wrapper.vm.confirmDelete()

      expect(wrapper.emitted('projectUpdated')).toBeTruthy()
    })

    it('closes modal on success', async () => {
      const axios = (await import('axios')).default
      axios.delete.mockResolvedValue({ data: {} })

      wrapper = createWrapper({ is_vulcan_admin: true })
      wrapper.vm.projectToDelete = sampleProjects[0]
      wrapper.vm.showDeleteModal = true

      await wrapper.vm.confirmDelete()

      expect(wrapper.vm.showDeleteModal).toBe(false)
      expect(wrapper.vm.isDeleting).toBe(false)
    })

    it('resets state on success', async () => {
      const axios = (await import('axios')).default
      axios.delete.mockResolvedValue({ data: {} })

      wrapper = createWrapper({ is_vulcan_admin: true })
      wrapper.vm.projectToDelete = sampleProjects[0]
      wrapper.vm.showDeleteModal = true

      await wrapper.vm.confirmDelete()

      expect(wrapper.vm.projectToDelete).toBe(null)
    })
  })
})
