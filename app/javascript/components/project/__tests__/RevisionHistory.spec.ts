/**
 * RevisionHistory Component Tests
 *
 * Tests for component revision history display
 */

import type { VueWrapper } from '@vue/test-utils'
import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import * as componentsApi from '@/apis/components.api'
import RevisionHistory from '../RevisionHistory.vue'

// Mock the API instead of the composable
vi.mock('@/apis/components.api', () => ({
  getRevisionHistory: vi.fn(),
}))

describe('revisionHistory', () => {
  let wrapper: VueWrapper

  const mockProject = {
    id: 123,
    name: 'Test Project',
  }

  const mockComponentNames = ['Component A', 'Component B', 'Component C']

  const mockHistory = [
    {
      component: {
        id: 1,
        name: 'Component A',
        version: '1.0',
        release: 'R1',
      },
      baseComponent: { prefix: 'COMP' },
      diffComponent: { prefix: 'COMP' },
      changes: {
        '001': { change: 'added' as const },
        '002': { change: 'updated' as const },
        '003': { change: 'removed' as const },
      },
    },
  ]

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue([])
  })

  it('renders component name dropdown', () => {
    wrapper = mount(RevisionHistory, {
      props: {
        project: mockProject,
        uniqueComponentNames: mockComponentNames,
      },
    })

    const select = wrapper.find('select')
    expect(select.exists()).toBe(true)

    const options = wrapper.findAll('option')
    expect(options).toHaveLength(mockComponentNames.length + 1) // +1 for empty option
  })

  it('fetches revision history when component is selected', async () => {
    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue(mockHistory)

    wrapper = mount(RevisionHistory, {
      props: {
        project: mockProject,
        uniqueComponentNames: mockComponentNames,
      },
    })

    const select = wrapper.find('select')
    await select.setValue('Component A')
    await nextTick()

    // Wait for watch to trigger fetchRevisionHistory
    await new Promise(resolve => setTimeout(resolve, 10))
    await nextTick()

    expect(componentsApi.getRevisionHistory).toHaveBeenCalledWith(123, 'Component A')
  })

  it('displays revision history entries after selection', async () => {
    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue(mockHistory)

    wrapper = mount(RevisionHistory, {
      props: {
        project: mockProject,
        uniqueComponentNames: mockComponentNames,
      },
    })

    // Select component
    const select = wrapper.find('select')
    await select.setValue('Component A')
    await nextTick()

    // Wait for API call
    await new Promise(resolve => setTimeout(resolve, 10))
    await nextTick()

    // Should display component name with version
    expect(wrapper.text()).toContain('Component A')
    expect(wrapper.text()).toContain('Version 1.0')
    expect(wrapper.text()).toContain('Release R1')

    // Should display changes
    expect(wrapper.text()).toContain('COMP-001 was added')
    expect(wrapper.text()).toContain('COMP-002 was updated')
    expect(wrapper.text()).toContain('COMP-003 was removed')
  })

  it('displays component name without version/release if not present', async () => {
    const historyWithoutVersion = [{
      ...mockHistory[0],
      component: {
        id: 1,
        name: 'Component B',
      },
    }]

    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue(historyWithoutVersion as any)

    wrapper = mount(RevisionHistory, {
      props: {
        project: mockProject,
        uniqueComponentNames: mockComponentNames,
      },
    })

    const select = wrapper.find('select')
    await select.setValue('Component B')
    await nextTick()
    await new Promise(resolve => setTimeout(resolve, 10))
    await nextTick()

    expect(wrapper.text()).toContain('Component B')
    // Should NOT contain version/release text
    expect(wrapper.text()).not.toContain('Version')
    expect(wrapper.text()).not.toContain('Release')
  })

  it('handles empty component names list', () => {
    wrapper = mount(RevisionHistory, {
      props: {
        project: mockProject,
        uniqueComponentNames: [],
      },
    })

    const options = wrapper.findAll('option')
    expect(options).toHaveLength(1) // Just the empty option
  })

  it('displays empty state message when no history found', async () => {
    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue([])

    wrapper = mount(RevisionHistory, {
      props: {
        project: mockProject,
        uniqueComponentNames: mockComponentNames,
      },
    })

    // Select component
    const select = wrapper.find('select')
    await select.setValue('Component A')
    await nextTick()
    await new Promise(resolve => setTimeout(resolve, 10))
    await nextTick()

    // Should show empty state message
    expect(wrapper.text()).toContain('No revision history found')
  })
})
