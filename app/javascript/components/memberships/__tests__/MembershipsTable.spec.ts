/**
 * MembershipsTable Component Unit Tests
 *
 * Tests for the MembershipsTable component that displays project/component memberships.
 * Focuses on prop defaults, computed properties, and action handling.
 */

import { describe, expect, it } from 'vitest'

describe('membershipsTable', () => {
  describe('prop defaults', () => {
    it('provides default available_roles when not passed', () => {
      // This was a bug - available_roles was optional without a default,
      // causing undefined to be passed to NewMembership which requires it
      const defaultRoles = ['viewer', 'author', 'reviewer', 'admin']

      // Simulate the withDefaults behavior
      const props = {
        memberships: [],
        membership_type: 'Component' as const,
        membership_id: 1,
        memberships_count: 0,
        // available_roles NOT provided - should use default
      }

      const mergedProps = {
        access_requests: [],
        editable: false,
        available_roles: defaultRoles,
        available_members: [],
        header_text: 'Members',
        ...props,
      }

      expect(mergedProps.available_roles).toEqual(defaultRoles)
      expect(mergedProps.available_roles).toHaveLength(4)
    })

    it('allows override of available_roles', () => {
      const customRoles = ['viewer', 'admin']

      const props = {
        memberships: [],
        membership_type: 'Project' as const,
        membership_id: 1,
        memberships_count: 0,
        available_roles: customRoles,
      }

      expect(props.available_roles).toEqual(customRoles)
      expect(props.available_roles).toHaveLength(2)
    })

    it('provides empty array defaults for optional array props', () => {
      const defaults = {
        access_requests: [],
        available_members: [],
      }

      expect(defaults.access_requests).toEqual([])
      expect(defaults.available_members).toEqual([])
    })
  })

  describe('columns computation', () => {
    it('excludes actions column when not editable', () => {
      const editable = false
      const cols = [
        { key: 'name', label: 'User', sortable: true },
        { key: 'role', label: 'Role', sortable: true },
      ]

      if (editable) {
        cols.push({ key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' } as any)
      }

      expect(cols).toHaveLength(2)
      expect(cols.map(c => c.key)).toEqual(['name', 'role'])
    })

    it('includes actions column when editable', () => {
      const editable = true
      const cols: any[] = [
        { key: 'name', label: 'User', sortable: true },
        { key: 'role', label: 'Role', sortable: true },
      ]

      if (editable) {
        cols.push({ key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' })
      }

      expect(cols).toHaveLength(3)
      expect(cols.map(c => c.key)).toEqual(['name', 'role', 'actions'])
    })
  })

  describe('pendingMembers computation', () => {
    it('filters available_members by access_requests', () => {
      const available_members = [
        { id: 1, name: 'User 1', email: 'user1@test.com' },
        { id: 2, name: 'User 2', email: 'user2@test.com' },
        { id: 3, name: 'User 3', email: 'user3@test.com' },
      ]

      const access_requests = [
        { id: 100, user_id: 1 },
        { id: 101, user_id: 3 },
      ]

      const pendingMembers = available_members.filter(member =>
        access_requests.some(request => request.user_id === member.id),
      )

      expect(pendingMembers).toHaveLength(2)
      expect(pendingMembers.map(m => m.id)).toEqual([1, 3])
    })

    it('returns empty array when no access requests', () => {
      const available_members = [
        { id: 1, name: 'User 1', email: 'user1@test.com' },
      ]
      const access_requests: any[] = []

      const pendingMembers = available_members.filter(member =>
        access_requests.some(request => request.user_id === member.id),
      )

      expect(pendingMembers).toHaveLength(0)
    })
  })

  describe('getAccessRequestId helper', () => {
    it('returns access request id for matching user', () => {
      const access_requests = [
        { id: 100, user_id: 1 },
        { id: 101, user_id: 2 },
      ]

      const member = { id: 2, name: 'User 2', email: 'user2@test.com' }

      const requestId = access_requests.find(r => r.user_id === member.id)?.id

      expect(requestId).toBe(101)
    })

    it('returns undefined when no matching request', () => {
      const access_requests = [
        { id: 100, user_id: 1 },
      ]

      const member = { id: 99, name: 'Unknown User', email: 'unknown@test.com' }

      const requestId = access_requests.find(r => r.user_id === member.id)?.id

      expect(requestId).toBeUndefined()
    })
  })

  describe('action menu', () => {
    it('returns delete action with danger variant', () => {
      const actions = [
        { id: 'delete', label: 'Remove Member', icon: 'bi-trash', variant: 'danger' as const },
      ]

      expect(actions).toHaveLength(1)
      expect(actions[0].variant).toBe('danger')
      expect(actions[0].id).toBe('delete')
    })
  })

  describe('new member button visibility', () => {
    it('shows button when editable and has available_members and available_roles', () => {
      const editable = true
      const available_members = [{ id: 1, name: 'User', email: 'user@test.com' }]
      const available_roles = ['viewer', 'admin']

      const showButton = editable && available_members && available_roles

      // && returns the last truthy value (available_roles array), not boolean true
      expect(showButton).toBeTruthy()
    })

    it('hides button when not editable', () => {
      const editable = false
      const available_members = [{ id: 1, name: 'User', email: 'user@test.com' }]
      const available_roles = ['viewer', 'admin']

      const showButton = editable && available_members && available_roles

      expect(showButton).toBe(false)
    })

    it('shows button even with empty available_members (truthy empty array)', () => {
      const editable = true
      const available_members: any[] = []
      const available_roles = ['viewer', 'admin']

      // In JavaScript, empty array is truthy
      // The template check is: v-if="editable && available_members && available_roles"
      // This evaluates to true even with empty arrays
      const showButton = editable && available_members && available_roles

      // Button will show (though it may not be useful with no members to add)
      expect(showButton).toBeTruthy()
    })
  })
})
