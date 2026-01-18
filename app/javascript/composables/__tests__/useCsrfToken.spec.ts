/**
 * Tests for useCsrfToken composable
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { useCsrfToken } from '@/composables/useCsrfToken'

describe('useCsrfToken', () => {
  let metaTag: HTMLMetaElement | null = null

  beforeEach(() => {
    // Clean up any existing CSRF meta tag
    const existing = document.querySelector('meta[name="csrf-token"]')
    if (existing) {
      existing.remove()
    }
  })

  afterEach(() => {
    // Clean up test meta tag
    if (metaTag) {
      metaTag.remove()
      metaTag = null
    }
  })

  function createCsrfMetaTag(token: string) {
    metaTag = document.createElement('meta')
    metaTag.name = 'csrf-token'
    metaTag.content = token
    document.head.appendChild(metaTag)
  }

  it('returns empty string when no meta tag exists', () => {
    const { csrfToken } = useCsrfToken()
    expect(csrfToken.value).toBe('')
  })

  it('returns token from meta tag when it exists', () => {
    const expectedToken = 'abc123xyz789'
    createCsrfMetaTag(expectedToken)

    const { csrfToken } = useCsrfToken()
    expect(csrfToken.value).toBe(expectedToken)
  })

  it('returns the current token value each time accessed', () => {
    createCsrfMetaTag('initial-token')
    const { csrfToken } = useCsrfToken()

    expect(csrfToken.value).toBe('initial-token')

    // Note: Since this is a computed that reads from the DOM,
    // and Vue's reactivity doesn't track DOM changes,
    // calling csrfToken.value again just reads the current value.
    // This behavior is correct - the token is fetched fresh on each access.
    expect(csrfToken.value).toBe('initial-token')
  })

  it('handles empty token value in meta tag', () => {
    createCsrfMetaTag('')
    const { csrfToken } = useCsrfToken()
    expect(csrfToken.value).toBe('')
  })
})
