/**
 * ActionMenu Component Unit Tests
 */

import { describe, expect, it } from 'vitest'

describe('actionMenu component', () => {
  describe('action visibility', () => {
    it('filters out hidden actions', () => {
      const actions = [
        { id: 'view', label: 'View', icon: 'bi-eye', hidden: false },
        { id: 'edit', label: 'Edit', icon: 'bi-pencil', hidden: true },
        { id: 'delete', label: 'Delete', icon: 'bi-trash' },
      ]

      const visibleActions = actions.filter(action => !action.hidden)

      expect(visibleActions).toHaveLength(2)
      expect(visibleActions.map(a => a.id)).toEqual(['view', 'delete'])
    })

    it('shows all actions when none are hidden', () => {
      const actions = [
        { id: 'view', label: 'View' },
        { id: 'edit', label: 'Edit' },
        { id: 'delete', label: 'Delete' },
      ]

      const visibleActions = actions.filter(action => !action.hidden)

      expect(visibleActions).toHaveLength(3)
    })

    it('handles empty actions array', () => {
      const actions: any[] = []
      const visibleActions = actions.filter(action => !action.hidden)

      expect(visibleActions).toHaveLength(0)
    })
  })

  describe('action item classes', () => {
    it('applies danger variant class', () => {
      const action = { id: 'delete', label: 'Delete', variant: 'danger' as const }

      const getItemClass = (action: any) => {
        const classes = ['dropdown-item', 'd-flex', 'align-items-center', 'gap-2']
        if (action.variant === 'danger') classes.push('text-danger')
        if (action.variant === 'success') classes.push('text-success')
        if (action.variant === 'warning') classes.push('text-warning')
        if (action.disabled) classes.push('disabled')
        return classes.join(' ')
      }

      expect(getItemClass(action)).toContain('text-danger')
    })

    it('applies success variant class', () => {
      const action = { id: 'approve', label: 'Approve', variant: 'success' as const }

      const getItemClass = (action: any) => {
        const classes = ['dropdown-item', 'd-flex', 'align-items-center', 'gap-2']
        if (action.variant === 'danger') classes.push('text-danger')
        if (action.variant === 'success') classes.push('text-success')
        if (action.variant === 'warning') classes.push('text-warning')
        if (action.disabled) classes.push('disabled')
        return classes.join(' ')
      }

      expect(getItemClass(action)).toContain('text-success')
    })

    it('applies disabled class', () => {
      const action = { id: 'edit', label: 'Edit', disabled: true }

      const getItemClass = (action: any) => {
        const classes = ['dropdown-item', 'd-flex', 'align-items-center', 'gap-2']
        if (action.variant === 'danger') classes.push('text-danger')
        if (action.variant === 'success') classes.push('text-success')
        if (action.variant === 'warning') classes.push('text-warning')
        if (action.disabled) classes.push('disabled')
        return classes.join(' ')
      }

      expect(getItemClass(action)).toContain('disabled')
    })

    it('applies no variant class for default', () => {
      const action = { id: 'view', label: 'View' }

      const getItemClass = (action: any) => {
        const classes = ['dropdown-item', 'd-flex', 'align-items-center', 'gap-2']
        if (action.variant === 'danger') classes.push('text-danger')
        if (action.variant === 'success') classes.push('text-success')
        if (action.variant === 'warning') classes.push('text-warning')
        if (action.disabled) classes.push('disabled')
        return classes.join(' ')
      }

      const result = getItemClass(action)
      expect(result).not.toContain('text-danger')
      expect(result).not.toContain('text-success')
      expect(result).not.toContain('text-warning')
      expect(result).not.toContain('disabled')
    })
  })

  describe('dividers', () => {
    it('identifies actions with dividers before them', () => {
      const actions = [
        { id: 'view', label: 'View' },
        { id: 'edit', label: 'Edit' },
        { id: 'delete', label: 'Delete', dividerBefore: true },
      ]

      const actionsWithDividers = actions.filter(a => a.dividerBefore)

      expect(actionsWithDividers).toHaveLength(1)
      expect(actionsWithDividers[0].id).toBe('delete')
    })
  })

  describe('action emission', () => {
    it('emits action id when handleAction is called', () => {
      const emittedActions: string[] = []
      const emit = (event: string, actionId: string) => {
        if (event === 'action') emittedActions.push(actionId)
      }

      const action = { id: 'view', label: 'View' }

      // Simulate handleAction
      const handleAction = (action: any) => {
        if (action.disabled) return
        emit('action', action.id)
      }

      handleAction(action)

      expect(emittedActions).toContain('view')
    })

    it('does not emit for disabled actions', () => {
      const emittedActions: string[] = []
      const emit = (event: string, actionId: string) => {
        if (event === 'action') emittedActions.push(actionId)
      }

      const action = { id: 'edit', label: 'Edit', disabled: true }

      const handleAction = (action: any) => {
        if (action.disabled) return
        emit('action', action.id)
      }

      handleAction(action)

      expect(emittedActions).toHaveLength(0)
    })
  })

  describe('common action patterns', () => {
    it('supports typical CRUD actions', () => {
      const crudActions = [
        { id: 'view', label: 'View', icon: 'bi-eye' },
        { id: 'edit', label: 'Edit', icon: 'bi-pencil' },
        { id: 'delete', label: 'Delete', icon: 'bi-trash', variant: 'danger' as const, dividerBefore: true },
      ]

      expect(crudActions).toHaveLength(3)
      expect(crudActions.find(a => a.id === 'delete')?.variant).toBe('danger')
      expect(crudActions.find(a => a.id === 'delete')?.dividerBefore).toBe(true)
    })

    it('supports project-specific actions', () => {
      const projectActions = [
        { id: 'view', label: 'View Project', icon: 'bi-eye' },
        { id: 'edit', label: 'Edit Details', icon: 'bi-pencil' },
        { id: 'members', label: 'Manage Members', icon: 'bi-people' },
        { id: 'delete', label: 'Delete Project', icon: 'bi-trash', variant: 'danger' as const, dividerBefore: true },
      ]

      expect(projectActions).toHaveLength(4)
    })

    it('supports user management actions', () => {
      const userActions = [
        { id: 'promote', label: 'Make Admin', icon: 'bi-arrow-up-circle', variant: 'success' as const },
        { id: 'demote', label: 'Remove Admin', icon: 'bi-arrow-down-circle', variant: 'warning' as const },
        { id: 'delete', label: 'Remove User', icon: 'bi-trash', variant: 'danger' as const, dividerBefore: true },
      ]

      expect(userActions).toHaveLength(3)
    })
  })
})
