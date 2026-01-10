/**
 * useRevisionHistory Composable Tests
 *
 * Tests for component revision history management
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import * as componentsApi from '@/apis/components.api'
import { useRevisionHistory } from '../useRevisionHistory'

vi.mock('@/apis/components.api', () => ({
  getRevisionHistory: vi.fn(),
}))

describe('useRevisionHistory', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('initializes with empty state', () => {
    const { selectedComponentName, revisionHistory, isLoading } = useRevisionHistory()

    expect(selectedComponentName.value).toBe('')
    expect(revisionHistory.value).toEqual([])
    expect(isLoading.value).toBe(false)
  })

  it('fetches revision history when component name is selected', async () => {
    const mockHistory = [
      {
        component: { id: 1, name: 'Test Component', version: '1.0' },
        baseComponent: { prefix: 'TEST' },
        diffComponent: { prefix: 'TEST' },
        changes: {
          '001': { change: 'added' },
          '002': { change: 'updated' },
        },
      },
    ]

    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue(mockHistory)

    const { selectedComponentName, revisionHistory, isLoading, fetchRevisionHistory } = useRevisionHistory()

    // Set project ID
    const projectId = 123
    selectedComponentName.value = 'Test Component'

    // Fetch history
    await fetchRevisionHistory(projectId)
    await nextTick()

    expect(componentsApi.getRevisionHistory).toHaveBeenCalledWith(123, 'Test Component')
    expect(revisionHistory.value).toEqual(mockHistory)
    expect(isLoading.value).toBe(false)
  })

  it('sets loading state during fetch', async () => {
    let resolvePromise: (value: any) => void
    const promise = new Promise((resolve) => {
      resolvePromise = resolve
    })

    vi.mocked(componentsApi.getRevisionHistory).mockReturnValue(promise as any)

    const { selectedComponentName, isLoading, fetchRevisionHistory } = useRevisionHistory()

    selectedComponentName.value = 'Test Component'
    const fetchPromise = fetchRevisionHistory(123)

    // Should be loading immediately after call
    expect(isLoading.value).toBe(true)

    // Resolve the promise
    resolvePromise!([])
    await fetchPromise
    await nextTick()

    // Should no longer be loading
    expect(isLoading.value).toBe(false)
  })

  it('does not fetch if component name is empty', async () => {
    const { selectedComponentName, fetchRevisionHistory } = useRevisionHistory()

    selectedComponentName.value = ''
    await fetchRevisionHistory(123)

    expect(componentsApi.getRevisionHistory).not.toHaveBeenCalled()
  })

  it('handles API errors gracefully', async () => {
    const error = new Error('API Error')
    vi.mocked(componentsApi.getRevisionHistory).mockRejectedValue(error)

    const { selectedComponentName, revisionHistory, isLoading, fetchRevisionHistory } = useRevisionHistory()

    selectedComponentName.value = 'Test Component'

    await expect(fetchRevisionHistory(123)).rejects.toThrow('API Error')

    // Loading should be false after error
    expect(isLoading.value).toBe(false)
    // History should remain empty
    expect(revisionHistory.value).toEqual([])
  })

  it('clears revision history when component name changes', async () => {
    const mockHistory = [
      {
        component: { id: 1, name: 'Test Component', version: '1.0' },
        baseComponent: { prefix: 'TEST' },
        diffComponent: { prefix: 'TEST' },
        changes: {},
      },
    ]

    vi.mocked(componentsApi.getRevisionHistory).mockResolvedValue(mockHistory)

    const { selectedComponentName, revisionHistory, fetchRevisionHistory } = useRevisionHistory()

    // Load first component
    selectedComponentName.value = 'Component A'
    await fetchRevisionHistory(123)
    expect(revisionHistory.value).toEqual(mockHistory)

    // Change to empty - should clear history
    selectedComponentName.value = ''
    await nextTick()
    expect(revisionHistory.value).toEqual([])
  })

  it('returns reactive refs', () => {
    const { selectedComponentName, revisionHistory, isLoading } = useRevisionHistory()

    // Should be Vue refs
    expect(selectedComponentName).toHaveProperty('value')
    expect(revisionHistory).toHaveProperty('value')
    expect(isLoading).toHaveProperty('value')
  })
})
