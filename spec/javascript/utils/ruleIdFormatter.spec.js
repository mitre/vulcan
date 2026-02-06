import { describe, it, expect } from 'vitest'
import { truncateRuleId } from '@/utils/ruleIdFormatter'

/**
 * truncateRuleId Requirements
 *
 * Rule IDs come in the format "SV-203591r557031_rule" where:
 * - "SV-203591" is the meaningful identifier practitioners use
 * - "r557031_rule" is the release/revision suffix
 *
 * truncateRuleId strips the release suffix, returning just "SV-203591".
 * Pattern: everything before the first 'r' followed by digits.
 */
describe('truncateRuleId', () => {
  it('truncates standard rule ID format', () => {
    expect(truncateRuleId('SV-203591r557031_rule')).toBe('SV-203591')
  })

  it('truncates short revision numbers', () => {
    expect(truncateRuleId('SV-53018r3_rule')).toBe('SV-53018')
  })

  it('returns empty string for null input', () => {
    expect(truncateRuleId(null)).toBe('')
  })

  it('returns empty string for undefined input', () => {
    expect(truncateRuleId(undefined)).toBe('')
  })

  it('returns empty string for empty string input', () => {
    expect(truncateRuleId('')).toBe('')
  })

  it('passes through IDs without r-digit pattern', () => {
    expect(truncateRuleId('SRG-OS-000001-GPOS-00001')).toBe('SRG-OS-000001-GPOS-00001')
  })

  it('passes through IDs with r not followed by digits', () => {
    expect(truncateRuleId('some-rule-name')).toBe('some-rule-name')
  })
})
