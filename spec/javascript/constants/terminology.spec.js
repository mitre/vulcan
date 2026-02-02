import { describe, it, expect } from 'vitest'
import {
  RULE_TERM,
  COMPONENT_TERM,
  PANEL_LABELS,
  SIDEBAR_TITLES,
  ACTION_LABELS,
  NAVIGATOR_LABELS,
  MESSAGE_LABELS,
  REVIEW_ACTION_LABELS,
  ROLE_DESCRIPTIONS,
  ruleCountLabel,
  selectedCountLabel
} from '@/constants/terminology'

/**
 * Terminology Constants Tests
 *
 * These tests ensure the terminology configuration is properly structured
 * and that all labels are derived from the base terms (DRY principle).
 *
 * If terminology changes (e.g., "Rule" → "Requirement"), these tests
 * verify the change propagates correctly throughout the app.
 */
describe('terminology constants', () => {
  describe('RULE_TERM', () => {
    it('has required properties', () => {
      expect(RULE_TERM).toHaveProperty('singular')
      expect(RULE_TERM).toHaveProperty('plural')
      expect(RULE_TERM).toHaveProperty('label')
    })

    it('singular and plural are consistent', () => {
      // If singular is "Rule", plural should be "Rules"
      // If singular is "Requirement", plural should be "Requirements"
      expect(RULE_TERM.plural).toBe(`${RULE_TERM.singular}s`)
    })
  })

  describe('COMPONENT_TERM', () => {
    it('has required properties', () => {
      expect(COMPONENT_TERM).toHaveProperty('singular')
      expect(COMPONENT_TERM).toHaveProperty('plural')
      expect(COMPONENT_TERM).toHaveProperty('label')
      expect(COMPONENT_TERM).toHaveProperty('labelFull')
    })

    it('labelFull matches singular', () => {
      expect(COMPONENT_TERM.labelFull).toBe(COMPONENT_TERM.singular)
    })
  })

  describe('PANEL_LABELS', () => {
    it('has all required panel labels', () => {
      expect(PANEL_LABELS).toHaveProperty('details')
      expect(PANEL_LABELS).toHaveProperty('metadata')
      expect(PANEL_LABELS).toHaveProperty('questions')
      expect(PANEL_LABELS).toHaveProperty('compHistory')
      expect(PANEL_LABELS).toHaveProperty('compReviews')
      expect(PANEL_LABELS).toHaveProperty('satisfies')
      expect(PANEL_LABELS).toHaveProperty('ruleHistory')
      expect(PANEL_LABELS).toHaveProperty('ruleReviews')
    })

    it('component labels use COMPONENT_TERM.label', () => {
      expect(PANEL_LABELS.compHistory).toContain(COMPONENT_TERM.label)
      expect(PANEL_LABELS.compReviews).toContain(COMPONENT_TERM.label)
    })

    it('rule labels use RULE_TERM.label', () => {
      expect(PANEL_LABELS.ruleHistory).toContain(RULE_TERM.label)
      expect(PANEL_LABELS.ruleReviews).toContain(RULE_TERM.label)
    })
  })

  describe('SIDEBAR_TITLES', () => {
    it('has all required sidebar titles', () => {
      expect(SIDEBAR_TITLES).toHaveProperty('details')
      expect(SIDEBAR_TITLES).toHaveProperty('metadata')
      expect(SIDEBAR_TITLES).toHaveProperty('questions')
      expect(SIDEBAR_TITLES).toHaveProperty('compHistory')
      expect(SIDEBAR_TITLES).toHaveProperty('compReviews')
      expect(SIDEBAR_TITLES).toHaveProperty('satisfies')
      expect(SIDEBAR_TITLES).toHaveProperty('ruleHistory')
      expect(SIDEBAR_TITLES).toHaveProperty('ruleReviews')
    })

    it('component sidebar titles use COMPONENT_TERM.labelFull', () => {
      expect(SIDEBAR_TITLES.details).toContain(COMPONENT_TERM.labelFull)
      expect(SIDEBAR_TITLES.metadata).toContain(COMPONENT_TERM.labelFull)
      expect(SIDEBAR_TITLES.compHistory).toContain(COMPONENT_TERM.labelFull)
      expect(SIDEBAR_TITLES.compReviews).toContain(COMPONENT_TERM.labelFull)
    })

    it('rule sidebar titles use RULE_TERM.singular', () => {
      expect(SIDEBAR_TITLES.ruleHistory).toContain(RULE_TERM.singular)
      expect(SIDEBAR_TITLES.ruleReviews).toContain(RULE_TERM.singular)
    })
  })

  describe('ACTION_LABELS', () => {
    it('has all required action labels', () => {
      expect(ACTION_LABELS).toHaveProperty('save')
      expect(ACTION_LABELS).toHaveProperty('clone')
      expect(ACTION_LABELS).toHaveProperty('delete')
      expect(ACTION_LABELS).toHaveProperty('lock')
      expect(ACTION_LABELS).toHaveProperty('unlock')
      expect(ACTION_LABELS).toHaveProperty('comment')
      expect(ACTION_LABELS).toHaveProperty('review')
      expect(ACTION_LABELS).toHaveProperty('related')
    })

    it('action labels for rule operations use RULE_TERM.singular', () => {
      expect(ACTION_LABELS.save).toContain(RULE_TERM.singular)
      expect(ACTION_LABELS.clone).toContain(RULE_TERM.singular)
      expect(ACTION_LABELS.delete).toContain(RULE_TERM.singular)
      expect(ACTION_LABELS.lock).toContain(RULE_TERM.singular)
      expect(ACTION_LABELS.unlock).toContain(RULE_TERM.singular)
    })
  })

  describe('NAVIGATOR_LABELS', () => {
    it('has all required navigator labels', () => {
      expect(NAVIGATOR_LABELS).toHaveProperty('openRules')
      expect(NAVIGATOR_LABELS).toHaveProperty('allRules')
      expect(NAVIGATOR_LABELS).toHaveProperty('noRulesSelected')
      expect(NAVIGATOR_LABELS).toHaveProperty('searchPlaceholder')
      expect(NAVIGATOR_LABELS).toHaveProperty('createNew')
    })

    it('navigator labels use RULE_TERM', () => {
      expect(NAVIGATOR_LABELS.openRules).toContain(RULE_TERM.plural)
      expect(NAVIGATOR_LABELS.allRules).toContain(RULE_TERM.plural)
      expect(NAVIGATOR_LABELS.createNew).toContain(RULE_TERM.singular)
    })

    it('search placeholder uses lowercase plural', () => {
      expect(NAVIGATOR_LABELS.searchPlaceholder.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase())
    })
  })

  describe('MESSAGE_LABELS', () => {
    it('has all required message labels', () => {
      expect(MESSAGE_LABELS).toHaveProperty('saveTitle')
      expect(MESSAGE_LABELS).toHaveProperty('saveMessage')
      expect(MESSAGE_LABELS).toHaveProperty('lockTitle')
      expect(MESSAGE_LABELS).toHaveProperty('lockMessage')
      expect(MESSAGE_LABELS).toHaveProperty('unlockTitle')
      expect(MESSAGE_LABELS).toHaveProperty('unlockMessage')
      expect(MESSAGE_LABELS).toHaveProperty('cloneTitle')
      expect(MESSAGE_LABELS).toHaveProperty('deleteTitle')
      expect(MESSAGE_LABELS).toHaveProperty('commentMessage')
      expect(MESSAGE_LABELS).toHaveProperty('selectRule')
      // Delete confirmation
      expect(MESSAGE_LABELS).toHaveProperty('deleteConfirmMessage')
      expect(MESSAGE_LABELS).toHaveProperty('deleteConfirmButton')
      // Also Satisfies modal
      expect(MESSAGE_LABELS).toHaveProperty('satisfiesPrompt')
      expect(MESSAGE_LABELS).toHaveProperty('satisfiesPlaceholder')
      // Revert history
      expect(MESSAGE_LABELS).toHaveProperty('revertHistoryTitle')
    })

    it('revert history title uses RULE_TERM', () => {
      expect(MESSAGE_LABELS.revertHistoryTitle).toContain(RULE_TERM.singular)
    })

    it('delete confirmation uses RULE_TERM', () => {
      expect(MESSAGE_LABELS.deleteConfirmMessage.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(MESSAGE_LABELS.deleteConfirmButton).toContain(RULE_TERM.singular)
    })

    it('satisfies labels use RULE_TERM', () => {
      expect(MESSAGE_LABELS.satisfiesPrompt.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase())
      expect(MESSAGE_LABELS.satisfiesPlaceholder.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase())
    })

    it('message labels use RULE_TERM', () => {
      expect(MESSAGE_LABELS.saveTitle).toContain(RULE_TERM.singular)
      expect(MESSAGE_LABELS.lockTitle).toContain(RULE_TERM.singular)
      expect(MESSAGE_LABELS.unlockTitle).toContain(RULE_TERM.singular)
      expect(MESSAGE_LABELS.cloneTitle).toContain(RULE_TERM.singular)
      expect(MESSAGE_LABELS.deleteTitle).toContain(RULE_TERM.singular)
    })

    it('message bodies use lowercase rule term', () => {
      expect(MESSAGE_LABELS.saveMessage.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(MESSAGE_LABELS.lockMessage.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(MESSAGE_LABELS.commentMessage.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
    })
  })

  describe('ROLE_DESCRIPTIONS', () => {
    it('has all four role descriptions', () => {
      expect(ROLE_DESCRIPTIONS).toHaveLength(4)
    })

    it('role descriptions that mention rules use RULE_TERM', () => {
      // Author and reviewer roles mention rules
      const authorDesc = ROLE_DESCRIPTIONS[1] // author role
      const reviewerDesc = ROLE_DESCRIPTIONS[2] // reviewer role
      const adminDesc = ROLE_DESCRIPTIONS[3] // admin role

      // These descriptions should use RULE_TERM, not "Control"
      expect(authorDesc.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase())
      expect(reviewerDesc.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(adminDesc.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase())
    })

    it('does not contain hardcoded "Control" or "Controls" as entity name', () => {
      // Check for "Control" or "Controls" when used as the entity name (not the verb "control")
      // The pattern matches: "a Control", "the Control", "Controls" at word boundary
      // but NOT "Full control" (lowercase verb usage)
      ROLE_DESCRIPTIONS.forEach((desc) => {
        expect(desc).not.toMatch(/\bControls\b/) // Plural always refers to entity
        expect(desc).not.toMatch(/\ba Control\b/i) // "a Control" is entity reference
        expect(desc).not.toMatch(/\bthe Control\b/i) // "the Control" is entity reference
      })
    })
  })

  describe('REVIEW_ACTION_LABELS', () => {
    it('has all required review action labels', () => {
      expect(REVIEW_ACTION_LABELS).toHaveProperty('requestReview')
      expect(REVIEW_ACTION_LABELS).toHaveProperty('revokeReview')
      expect(REVIEW_ACTION_LABELS).toHaveProperty('requestChanges')
      expect(REVIEW_ACTION_LABELS).toHaveProperty('approve')
      expect(REVIEW_ACTION_LABELS).toHaveProperty('lock')
      expect(REVIEW_ACTION_LABELS).toHaveProperty('unlock')
    })

    it('review action descriptions use RULE_TERM', () => {
      // All action descriptions should reference the rule term, not "control"
      expect(REVIEW_ACTION_LABELS.requestReview.description.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(REVIEW_ACTION_LABELS.approve.description.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(REVIEW_ACTION_LABELS.lock.description.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(REVIEW_ACTION_LABELS.unlock.description.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
    })

    it('disabled tooltips use RULE_TERM', () => {
      // All tooltips mentioning the entity should use the correct term
      expect(REVIEW_ACTION_LABELS.requestReview.alreadyUnderReview.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(REVIEW_ACTION_LABELS.lock.alreadyLocked.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
      expect(REVIEW_ACTION_LABELS.unlock.notLocked.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase())
    })
  })

  describe('ruleCountLabel helper', () => {
    it('returns singular for count of 1', () => {
      expect(ruleCountLabel(1)).toBe(`1 ${RULE_TERM.singular}`)
    })

    it('returns plural for count of 0', () => {
      expect(ruleCountLabel(0)).toBe(`0 ${RULE_TERM.plural}`)
    })

    it('returns plural for count greater than 1', () => {
      expect(ruleCountLabel(5)).toBe(`5 ${RULE_TERM.plural}`)
      expect(ruleCountLabel(100)).toBe(`100 ${RULE_TERM.plural}`)
    })
  })

  describe('selectedCountLabel helper', () => {
    it('returns singular for count of 1', () => {
      expect(selectedCountLabel(1)).toBe(`1 ${RULE_TERM.singular.toLowerCase()} selected`)
    })

    it('returns plural for count of 0', () => {
      expect(selectedCountLabel(0)).toBe(`0 ${RULE_TERM.plural.toLowerCase()} selected`)
    })

    it('returns plural for count greater than 1', () => {
      expect(selectedCountLabel(5)).toBe(`5 ${RULE_TERM.plural.toLowerCase()} selected`)
    })
  })

  describe('DRY principle verification', () => {
    it('changing RULE_TERM would update all derived labels', () => {
      // This test documents the expected behavior:
      // If RULE_TERM.label = 'Rule', then ruleHistory = 'Rule History'
      // If RULE_TERM.label = 'Req', then ruleHistory = 'Req History'
      const expectedRuleHistoryPattern = new RegExp(`${RULE_TERM.label}.*History`)
      const expectedRuleReviewsPattern = new RegExp(`${RULE_TERM.label}.*Reviews`)

      expect(PANEL_LABELS.ruleHistory).toMatch(expectedRuleHistoryPattern)
      expect(PANEL_LABELS.ruleReviews).toMatch(expectedRuleReviewsPattern)
    })

    it('changing COMPONENT_TERM would update all derived labels', () => {
      const expectedCompHistoryPattern = new RegExp(`${COMPONENT_TERM.label}.*History`)
      const expectedCompReviewsPattern = new RegExp(`${COMPONENT_TERM.label}.*Reviews`)

      expect(PANEL_LABELS.compHistory).toMatch(expectedCompHistoryPattern)
      expect(PANEL_LABELS.compReviews).toMatch(expectedCompReviewsPattern)
    })
  })
})
