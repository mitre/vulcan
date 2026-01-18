/**
 * Tests for useRailsForm composable
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useRailsForm } from '@/composables/useRailsForm'

describe('useRailsForm', () => {
  let metaTag: HTMLMetaElement | null = null
  let submittedForm: HTMLFormElement | null = null

  beforeEach(() => {
    // Set up CSRF meta tag
    metaTag = document.createElement('meta')
    metaTag.name = 'csrf-token'
    metaTag.content = 'test-csrf-token'
    document.head.appendChild(metaTag)

    // Mock form.submit() to capture the form instead of actually submitting
    submittedForm = null
    vi.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation(function () {
      submittedForm = this as HTMLFormElement
    })
  })

  afterEach(() => {
    if (metaTag) {
      metaTag.remove()
      metaTag = null
    }
    // Clean up any forms added to body
    document.querySelectorAll('form').forEach(form => form.remove())
    vi.restoreAllMocks()
  })

  describe('csrfToken', () => {
    it('provides CSRF token from meta tag', () => {
      const { csrfToken } = useRailsForm()
      expect(csrfToken.value).toBe('test-csrf-token')
    })
  })

  describe('submitForm', () => {
    it('creates a form with POST method for post requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/test/path', 'post')

      expect(submittedForm).toBeTruthy()
      expect(submittedForm!.method.toLowerCase()).toBe('post')
      expect(submittedForm!.action).toContain('/test/path')
    })

    it('creates a form with GET method for get requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/test/path', 'get')

      expect(submittedForm).toBeTruthy()
      expect(submittedForm!.method.toLowerCase()).toBe('get')
    })

    it('adds _method hidden field for DELETE requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users/123', 'delete')

      expect(submittedForm).toBeTruthy()
      const methodInput = submittedForm!.querySelector('input[name="_method"]') as HTMLInputElement
      expect(methodInput).toBeTruthy()
      expect(methodInput.value).toBe('delete')
    })

    it('adds _method hidden field for PUT requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users/123', 'put')

      const methodInput = submittedForm!.querySelector('input[name="_method"]') as HTMLInputElement
      expect(methodInput).toBeTruthy()
      expect(methodInput.value).toBe('put')
    })

    it('adds _method hidden field for PATCH requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users/123', 'patch')

      const methodInput = submittedForm!.querySelector('input[name="_method"]') as HTMLInputElement
      expect(methodInput).toBeTruthy()
      expect(methodInput.value).toBe('patch')
    })

    it('does not add _method field for POST requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users', 'post')

      const methodInput = submittedForm!.querySelector('input[name="_method"]')
      expect(methodInput).toBeNull()
    })

    it('adds CSRF token for non-GET requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users/123', 'delete')

      const tokenInput = submittedForm!.querySelector('input[name="authenticity_token"]') as HTMLInputElement
      expect(tokenInput).toBeTruthy()
      expect(tokenInput.value).toBe('test-csrf-token')
    })

    it('does not add CSRF token for GET requests', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users', 'get')

      const tokenInput = submittedForm!.querySelector('input[name="authenticity_token"]')
      expect(tokenInput).toBeNull()
    })

    it('adds additional data as hidden inputs', () => {
      const { submitForm } = useRailsForm()
      submitForm('/users/123', 'put', {
        data: {
          'user[name]': 'John Doe',
          'user[email]': 'john@example.com',
        },
      })

      const nameInput = submittedForm!.querySelector('input[name="user[name]"]') as HTMLInputElement
      const emailInput = submittedForm!.querySelector('input[name="user[email]"]') as HTMLInputElement

      expect(nameInput).toBeTruthy()
      expect(nameInput.value).toBe('John Doe')
      expect(emailInput).toBeTruthy()
      expect(emailInput.value).toBe('john@example.com')
    })

    it('appends form to document body', () => {
      const { submitForm } = useRailsForm()
      submitForm('/test', 'post')

      expect(document.body.contains(submittedForm)).toBe(true)
    })
  })

  describe('submitDelete', () => {
    it('is a shorthand for DELETE requests', () => {
      const { submitDelete } = useRailsForm()
      submitDelete('/users/123')

      expect(submittedForm).toBeTruthy()
      expect(submittedForm!.action).toContain('/users/123')

      const methodInput = submittedForm!.querySelector('input[name="_method"]') as HTMLInputElement
      expect(methodInput.value).toBe('delete')
    })
  })

  describe('submitPut', () => {
    it('is a shorthand for PUT requests', () => {
      const { submitPut } = useRailsForm()
      submitPut('/users/123')

      expect(submittedForm).toBeTruthy()

      const methodInput = submittedForm!.querySelector('input[name="_method"]') as HTMLInputElement
      expect(methodInput.value).toBe('put')
    })

    it('accepts optional data parameter', () => {
      const { submitPut } = useRailsForm()
      submitPut('/users/123', { 'user[admin]': 'true' })

      const adminInput = submittedForm!.querySelector('input[name="user[admin]"]') as HTMLInputElement
      expect(adminInput).toBeTruthy()
      expect(adminInput.value).toBe('true')
    })
  })
})
