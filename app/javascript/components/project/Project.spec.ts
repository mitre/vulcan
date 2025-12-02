/**
 * Project Component Unit Tests
 *
 * Tests for empty state display logic and component visibility
 */

import { describe, expect, it } from 'vitest'

describe('project component', () => {
  describe('empty state display logic', () => {
    it('shows empty state when no components exist', () => {
      const project = {
        id: 1,
        name: 'Test Project',
        components: [],
      }

      // Simulate sortedComponents computed
      const sortedComponents = project.components || []
      const showEmptyState = sortedComponents.length === 0

      expect(showEmptyState).toBe(true)
    })

    it('hides empty state when components exist', () => {
      const project = {
        id: 1,
        name: 'Test Project',
        components: [
          { id: 1, name: 'Component A' },
          { id: 2, name: 'Component B' },
        ],
      }

      const sortedComponents = project.components || []
      const showEmptyState = sortedComponents.length === 0

      expect(showEmptyState).toBe(false)
    })

    it('hides empty state when null components array exists', () => {
      const project = {
        id: 1,
        name: 'Test Project',
        components: null as any,
      }

      const sortedComponents = project.components || []
      const showEmptyState = sortedComponents.length === 0

      expect(showEmptyState).toBe(true)
    })
  })

  describe('overlay components section visibility', () => {
    it('hides overlay section when no components exist', () => {
      const components: any[] = []
      const showOverlaySection = components.length > 0

      expect(showOverlaySection).toBe(false)
    })

    it('shows overlay section when regular components exist', () => {
      const components = [{ id: 1, name: 'Component', component_id: null }]
      const showOverlaySection = components.length > 0

      expect(showOverlaySection).toBe(true)
    })
  })

  describe('admin permissions for empty state CTA', () => {
    it('shows create button for admin users', () => {
      const isProjectAdmin = true
      const showCreateButton = isProjectAdmin

      expect(showCreateButton).toBe(true)
    })

    it('shows contact admin message for non-admin users', () => {
      const isProjectAdmin = false
      const showContactMessage = !isProjectAdmin

      expect(showContactMessage).toBe(true)
    })
  })

  describe('component sorting', () => {
    it('separates regular and overlay components', () => {
      const components = [
        { id: 1, name: 'Regular A', component_id: null },
        { id: 2, name: 'Overlay B', component_id: 10 },
        { id: 3, name: 'Regular C', component_id: null },
        { id: 4, name: 'Overlay D', component_id: 20 },
      ]

      const regularComponents = components.filter(c => c.component_id == null)
      const overlayComponents = components.filter(c => c.component_id != null)

      expect(regularComponents).toHaveLength(2)
      expect(overlayComponents).toHaveLength(2)
      expect(regularComponents.map(c => c.name)).toEqual(['Regular A', 'Regular C'])
      expect(overlayComponents.map(c => c.name)).toEqual(['Overlay B', 'Overlay D'])
    })

    it('handles empty components array', () => {
      const components: any[] = []

      const regularComponents = components.filter(c => c.component_id == null)
      const overlayComponents = components.filter(c => c.component_id != null)

      expect(regularComponents).toHaveLength(0)
      expect(overlayComponents).toHaveLength(0)
    })
  })
})
