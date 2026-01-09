/**
 * NewMembership Component Unit Tests
 *
 * Tests the async user search, keyboard navigation, role selection,
 * and form submission for the invite member modal.
 */

import { flushPromises, mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import NewMembership from '../NewMembership.vue'
import * as membersApi from '@/apis/members.api'

// Mock the members API
vi.mock('@/apis/members.api')

describe('newMembership', () => {
  const mockProjectId = 123
  const mockUsers = [
    { id: 1, name: 'John Doe', email: 'john@example.com' },
    { id: 2, name: 'Jane Smith', email: 'jane@example.com' },
    { id: 3, name: 'Bob Wilson', email: 'bob@example.com' },
  ]

  beforeEach(() => {
    vi.useFakeTimers()
    vi.mocked(membersApi.searchUsers).mockResolvedValue({ users: mockUsers })

    // Mock HTMLFormElement.submit() for jsdom
    HTMLFormElement.prototype.submit = vi.fn()
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.clearAllMocks()
  })

  describe('rendering', () => {
    it('renders search input when no user selected', () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      expect(wrapper.find('input[type="text"]').exists()).toBe(true)
      expect(wrapper.find('.bi-search').exists()).toBe(true)
    })

    it('shows placeholder text', () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      expect(input.attributes('placeholder')).toContain('Search for a user')
    })

    it('shows selected user in alert when user selected', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      expect(wrapper.text()).toContain('John Doe')
      expect(wrapper.text()).toContain('john@example.com')
      expect(wrapper.find('input[type="text"]').exists()).toBe(false)
    })

    it('does not show role selection until user selected', () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      expect(wrapper.findAll('input[type="radio"]')).toHaveLength(0)
    })

    it('shows role selection after user selected', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'author', 'reviewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      expect(wrapper.findAll('input[type="radio"]')).toHaveLength(4)
    })
  })

  describe('debounced search', () => {
    it('does not search with less than 2 characters', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('a')
      vi.advanceTimersByTime(300)
      await flushPromises()

      expect(membersApi.searchUsers).not.toHaveBeenCalled()
    })

    it('searches after 300ms debounce with 2+ characters', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')

      // Should not call immediately
      expect(membersApi.searchUsers).not.toHaveBeenCalled()

      // Advance timers by debounce amount
      vi.advanceTimersByTime(300)
      await flushPromises()

      expect(membersApi.searchUsers).toHaveBeenCalledWith({
        projectId: mockProjectId,
        query: 'jo',
      })
    })

    it('cancels previous search on rapid typing', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')

      // Type first query
      await input.setValue('jo')
      vi.advanceTimersByTime(150)

      // Type second query before first completes
      await input.setValue('john')
      vi.advanceTimersByTime(300)
      await flushPromises()

      // Should only call once with final query
      expect(membersApi.searchUsers).toHaveBeenCalledTimes(1)
      expect(membersApi.searchUsers).toHaveBeenCalledWith({
        projectId: mockProjectId,
        query: 'john',
      })
    })

    it('shows loading spinner while searching', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)

      // Should show spinner before promise resolves
      await nextTick()
      expect(wrapper.find('.spinner-border').exists()).toBe(true)

      // Wait for promise to resolve
      await flushPromises()
      await nextTick()

      // Spinner should be gone
      expect(wrapper.find('.spinner-border').exists()).toBe(false)
    })
  })

  describe('search results', () => {
    it('displays search results dropdown', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      expect(wrapper.find('.search-dropdown').exists()).toBe(true)
      expect(wrapper.findAll('.search-result-item')).toHaveLength(3)
    })

    it('shows user names and emails in results', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      const dropdown = wrapper.find('.search-dropdown')
      expect(dropdown.text()).toContain('John Doe')
      expect(dropdown.text()).toContain('john@example.com')
      expect(dropdown.text()).toContain('Jane Smith')
    })

    it('shows "no results" message when search returns empty', async () => {
      vi.mocked(membersApi.searchUsers).mockResolvedValue({ users: [] })

      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('xyz')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      expect(wrapper.text()).toContain('No users found')
    })

    it('selects user when clicking result', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      const firstResult = wrapper.find('.search-result-item')
      await firstResult.trigger('mousedown')
      await nextTick()

      // Should show selected user alert
      expect(wrapper.text()).toContain('John Doe')
      expect(wrapper.text()).toContain('john@example.com')
      // Should hide search input
      expect(wrapper.find('input[type="text"]').exists()).toBe(false)
    })

    it('hides search results after selecting user', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      const firstResult = wrapper.find('.search-result-item')
      await firstResult.trigger('mousedown')
      await nextTick()

      // Search dropdown should be hidden after selection
      expect(wrapper.find('.search-dropdown').exists()).toBe(false)
    })
  })

  describe('keyboard navigation', () => {
    it('highlights next result on arrow down', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      // Press arrow down
      await input.trigger('keydown', { key: 'ArrowDown' })
      await nextTick()

      const items = wrapper.findAll('.search-result-item')
      expect(items[0].classes()).toContain('highlighted')
    })

    it('highlights previous result on arrow up', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      // Press arrow down twice, then up once
      await input.trigger('keydown', { key: 'ArrowDown' })
      await input.trigger('keydown', { key: 'ArrowDown' })
      await input.trigger('keydown', { key: 'ArrowUp' })
      await nextTick()

      const items = wrapper.findAll('.search-result-item')
      expect(items[0].classes()).toContain('highlighted')
    })

    it('selects highlighted result on enter', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      // Highlight second item
      await input.trigger('keydown', { key: 'ArrowDown' })
      await input.trigger('keydown', { key: 'ArrowDown' })
      await nextTick()

      // Press enter
      await input.trigger('keydown', { key: 'Enter' })
      await nextTick()

      // Should select Jane Smith (second result)
      expect(wrapper.text()).toContain('Jane Smith')
    })

    it('closes dropdown on escape', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      expect(wrapper.find('.search-dropdown').exists()).toBe(true)

      // Press escape
      await input.trigger('keydown', { key: 'Escape' })
      await nextTick()

      expect(wrapper.find('.search-dropdown').exists()).toBe(false)
    })

    it('does not navigate when dropdown closed', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')

      // Try arrow down with no results
      await input.trigger('keydown', { key: 'ArrowDown' })
      await nextTick()

      // Should not error, just do nothing
      expect(wrapper.find('.search-dropdown').exists()).toBe(false)
    })
  })

  describe('role selection', () => {
    it('enables radio button selection', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      const radios = wrapper.findAll('input[type="radio"]')
      const viewerRadio = radios[0]

      await viewerRadio.trigger('click')
      await nextTick()

      expect(viewerRadio.element.checked).toBe(true)
    })

    it('shows role labels and descriptions', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'author', 'reviewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      expect(wrapper.text()).toContain('Viewer')
      expect(wrapper.text()).toContain('Author')
      expect(wrapper.text()).toContain('Reviewer')
      expect(wrapper.text()).toContain('Admin')
      expect(wrapper.text()).toContain('Read only access')
    })
  })

  describe('form submission', () => {
    it('exposes isSubmitDisabled as true when no user selected', () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      expect(wrapper.vm.isSubmitDisabled).toBe(true)
    })

    it('exposes isSubmitDisabled as true when user selected but no role', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      expect(wrapper.vm.isSubmitDisabled).toBe(true)
    })

    it('exposes isSubmitDisabled as false when user and role selected', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      const viewerRadio = wrapper.find('input[type="radio"]')
      await viewerRadio.trigger('click')
      await nextTick()

      expect(wrapper.vm.isSubmitDisabled).toBe(false)
    })

    it('exposes submitForm method', () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      expect(wrapper.vm.submitForm).toBeDefined()
      expect(typeof wrapper.vm.submitForm).toBe('function')
    })

    it('submits hidden form when submitForm called', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      const viewerRadio = wrapper.find('input[type="radio"]')
      await viewerRadio.trigger('click')
      await nextTick()

      const form = wrapper.find('form')
      const submitSpy = vi.spyOn(form.element, 'submit')

      wrapper.vm.submitForm()

      expect(submitSpy).toHaveBeenCalled()
    })

    it('includes hidden form fields with correct values', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
          access_request_id: 999,
        },
      })

      await nextTick()

      const viewerRadio = wrapper.find('input[type="radio"]')
      await viewerRadio.trigger('click')
      await nextTick()

      const form = wrapper.find('form')

      const membershipTypeInput = form.find('input[name="membership[membership_type]"]')
      expect(membershipTypeInput.element.value).toBe('Project')

      const membershipIdInput = form.find('input[name="membership[membership_id]"]')
      expect(membershipIdInput.element.value).toBe(mockProjectId.toString())

      const userIdInput = form.find('input[name="membership[user_id]"]')
      expect(userIdInput.element.value).toBe('1')

      const accessRequestIdInput = form.find('input[name="membership[access_request_id]"]')
      expect(accessRequestIdInput.element.value).toBe('999')

      const roleInput = form.find('input[name="membership[role]"]')
      expect(roleInput.element.value).toBe('viewer')
    })
  })

  describe('selected_member prop watcher', () => {
    it('updates selectedUser when selected_member prop changes', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      expect(wrapper.find('input[type="text"]').exists()).toBe(true)

      // Update prop
      await wrapper.setProps({ selected_member: mockUsers[0] })
      await nextTick()

      // Should show selected user
      expect(wrapper.text()).toContain('John Doe')
      expect(wrapper.find('input[type="text"]').exists()).toBe(false)
    })
  })

  describe('user selection state', () => {
    it('shows search when no user selected', () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      // Should show search input, not alert
      expect(wrapper.find('input[type="text"]').exists()).toBe(true)
      expect(wrapper.find('.alert').exists()).toBe(false)
    })

    it('shows alert when user selected', async () => {
      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
          selected_member: mockUsers[0],
        },
      })

      await nextTick()

      // Should show alert with user info, not search input
      expect(wrapper.find('input[type="text"]').exists()).toBe(false)
      expect(wrapper.find('.alert').exists()).toBe(true)
      expect(wrapper.text()).toContain('John Doe')
    })
  })

  describe('error handling', () => {
    it('handles API error gracefully', async () => {
      const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
      vi.mocked(membersApi.searchUsers).mockRejectedValue(new Error('API Error'))

      const wrapper = mount(NewMembership, {
        props: {
          membership_type: 'Project',
          membership_id: mockProjectId,
          available_roles: ['viewer', 'admin'],
        },
      })

      const input = wrapper.find('input[type="text"]')
      await input.setValue('jo')
      vi.advanceTimersByTime(300)
      await flushPromises()
      await nextTick()

      // Should not show dropdown
      expect(wrapper.find('.search-dropdown').exists()).toBe(false)

      // Should log error
      expect(consoleErrorSpy).toHaveBeenCalled()

      consoleErrorSpy.mockRestore()
    })
  })
})
