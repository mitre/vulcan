import { describe, it, expect, beforeEach, vi } from 'vitest'
import { ref } from 'vue'
import { useRuleActions } from '@/composables/useRuleActions'

// Mock axios
vi.mock('axios', () => ({
  default: {
    post: vi.fn(() => Promise.resolve({ data: { success: true } })),
    put: vi.fn(() => Promise.resolve({ data: { success: true } })),
    delete: vi.fn(() => Promise.resolve({ data: { success: true } })),
    defaults: { headers: { common: {} } }
  }
}))

import axios from 'axios'

describe('useRuleActions', () => {
  const mockRule = ref({
    id: 1,
    rule_id: 'CNTR-00-000010',
    component_id: 41,
    locked: false,
    review_requestor_id: null
  })

  const componentId = 41

  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('lockRule', () => {
    it('posts to the reviews endpoint with lock_control action', async () => {
      const { lockRule } = useRuleActions(componentId)
      await lockRule(mockRule.value, 'Locking for review')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'lock_control',
            comment: 'Locking for review'
          }
        }
      )
    })

    it('returns the response data on success', async () => {
      const { lockRule } = useRuleActions(componentId)
      const result = await lockRule(mockRule.value, 'Test comment')
      expect(result.success).toBe(true)
    })

    it('throws error when comment is empty', async () => {
      const { lockRule } = useRuleActions(componentId)
      await expect(lockRule(mockRule.value, '')).rejects.toThrow('Comment is required')
    })

    it('throws error when rule is null', async () => {
      const { lockRule } = useRuleActions(componentId)
      await expect(lockRule(null, 'comment')).rejects.toThrow('Rule is required')
    })
  })

  describe('unlockRule', () => {
    it('posts to the reviews endpoint with unlock_control action', async () => {
      const { unlockRule } = useRuleActions(componentId)
      await unlockRule(mockRule.value, 'Unlocking after review')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'unlock_control',
            comment: 'Unlocking after review'
          }
        }
      )
    })
  })

  describe('requestReview', () => {
    it('posts to the reviews endpoint with request_review action', async () => {
      const { requestReview } = useRuleActions(componentId)
      await requestReview(mockRule.value, 'Please review this control')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'request_review',
            comment: 'Please review this control'
          }
        }
      )
    })
  })

  describe('approveReview', () => {
    it('posts to the reviews endpoint with approve action', async () => {
      const { approveReview } = useRuleActions(componentId)
      await approveReview(mockRule.value, 'Looks good')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'approve',
            comment: 'Looks good'
          }
        }
      )
    })
  })

  describe('requestChanges', () => {
    it('posts to the reviews endpoint with request_changes action', async () => {
      const { requestChanges } = useRuleActions(componentId)
      await requestChanges(mockRule.value, 'Needs more detail')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'request_changes',
            comment: 'Needs more detail'
          }
        }
      )
    })
  })

  describe('revokeReview', () => {
    it('posts to the reviews endpoint with revoke_review action', async () => {
      const { revokeReview } = useRuleActions(componentId)
      await revokeReview(mockRule.value, 'Withdrawing review request')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'revoke_review',
            comment: 'Withdrawing review request'
          }
        }
      )
    })
  })

  describe('addComment', () => {
    it('posts to the reviews endpoint with comment action', async () => {
      const { addComment } = useRuleActions(componentId)
      await addComment(mockRule.value, 'This is a comment')

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/reviews',
        {
          review: {
            component_id: 41,
            action: 'comment',
            comment: 'This is a comment'
          }
        }
      )
    })
  })

  describe('saveRule', () => {
    it('puts to the rules endpoint', async () => {
      const { saveRule } = useRuleActions(componentId)
      const ruleData = { title: 'Updated title' }
      await saveRule(mockRule.value, ruleData)

      expect(axios.put).toHaveBeenCalledWith(
        '/rules/1',
        { rule: ruleData }
      )
    })
  })

  describe('deleteRule', () => {
    it('deletes the rule endpoint', async () => {
      const { deleteRule } = useRuleActions(componentId)
      await deleteRule(mockRule.value)

      expect(axios.delete).toHaveBeenCalledWith('/rules/1')
    })
  })

  describe('cloneRule', () => {
    it('posts to the clone endpoint', async () => {
      const { cloneRule } = useRuleActions(componentId)
      const cloneData = { rule_id: 'CNTR-00-000011' }
      await cloneRule(mockRule.value, cloneData)

      expect(axios.post).toHaveBeenCalledWith(
        '/rules/1/duplicate',
        { rule: cloneData }
      )
    })
  })

  describe('loading state', () => {
    it('starts with isLoading false', () => {
      const { isLoading } = useRuleActions(componentId)
      expect(isLoading.value).toBe(false)
    })

    it('sets isLoading to true during API call', async () => {
      // Use a delayed promise to verify loading state
      let resolvePromise
      axios.post.mockImplementationOnce(() => new Promise(resolve => {
        resolvePromise = () => resolve({ data: { success: true } })
      }))

      const { isLoading, lockRule } = useRuleActions(componentId)

      // Start the call but don't await it
      const promise = lockRule(mockRule.value, 'Test')

      // Loading should be true while waiting
      expect(isLoading.value).toBe(true)

      // Now resolve and await
      resolvePromise()
      await promise

      // Loading should be false after completion
      expect(isLoading.value).toBe(false)
    })

    it('sets isLoading to false after API error', async () => {
      axios.post.mockRejectedValueOnce(new Error('Network error'))
      const { isLoading, lockRule } = useRuleActions(componentId)

      try {
        await lockRule(mockRule.value, 'Test')
      } catch {}

      expect(isLoading.value).toBe(false)
    })
  })

  describe('error handling', () => {
    it('captures errors from API calls', async () => {
      axios.post.mockRejectedValueOnce(new Error('Network error'))
      const { lockRule, lastError } = useRuleActions(componentId)

      await expect(lockRule(mockRule.value, 'Test')).rejects.toThrow('Network error')
      expect(lastError.value).toBe('Network error')
    })

    it('clears error on successful call', async () => {
      const { lockRule, lastError } = useRuleActions(componentId)

      // First call fails
      axios.post.mockRejectedValueOnce(new Error('Network error'))
      try { await lockRule(mockRule.value, 'Test') } catch {}
      expect(lastError.value).toBe('Network error')

      // Second call succeeds
      axios.post.mockResolvedValueOnce({ data: { success: true } })
      await lockRule(mockRule.value, 'Test')
      expect(lastError.value).toBeNull()
    })
  })
})
