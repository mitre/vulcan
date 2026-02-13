import { describe, it, expect } from 'vitest'
import { truncateSrgId } from '@/utils/srgIdFormatter'

/**
 * SRG ID Formatter Tests
 *
 * REQUIREMENTS:
 *
 * SRG IDs are very long (e.g., "SRG-OS-000480-GPOS-00227") and need to be
 * truncated for compact display while remaining recognizable.
 *
 * Pattern: Show significant part (e.g., "SRG-OS-000480"), hide GPOS suffix
 * Full ID should be available via tooltip.
 */
describe('truncateSrgId', () => {
  it('truncates standard SRG ID to significant part', () => {
    const result = truncateSrgId('SRG-OS-000480-GPOS-00227')
    expect(result).toBe('SRG-OS-000480')
  })

  it('truncates APP domain SRG ID', () => {
    const result = truncateSrgId('SRG-APP-000123-GPOS-00456')
    expect(result).toBe('SRG-APP-000123')
  })

  it('truncates NET domain SRG ID', () => {
    const result = truncateSrgId('SRG-NET-000789-GPOS-00111')
    expect(result).toBe('SRG-NET-000789')
  })

  it('handles SRG ID without GPOS suffix', () => {
    const result = truncateSrgId('SRG-OS-000480')
    expect(result).toBe('SRG-OS-000480')
  })

  it('handles already short SRG ID', () => {
    const result = truncateSrgId('SRG-123')
    expect(result).toBe('SRG-123')
  })

  it('handles null gracefully', () => {
    const result = truncateSrgId(null)
    expect(result).toBe('')
  })

  it('handles undefined gracefully', () => {
    const result = truncateSrgId(undefined)
    expect(result).toBe('')
  })

  it('handles empty string', () => {
    const result = truncateSrgId('')
    expect(result).toBe('')
  })

  it('preserves non-standard format', () => {
    const result = truncateSrgId('CUSTOM-SRG-FORMAT')
    expect(result).toBe('CUSTOM-SRG-FORMAT')
  })
})
