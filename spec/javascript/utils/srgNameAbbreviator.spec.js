import { describe, it, expect } from 'vitest'
import { abbreviateSrgName } from '@/utils/srgNameAbbreviator'

/**
 * SRG Name Abbreviator Tests
 *
 * REQUIREMENTS:
 *
 * Abbreviate common SRG names for compact table display while keeping them recognizable.
 *
 * Pattern:
 * - Known SRGs: Use standard abbreviations (GPOS, DB, etc.)
 * - Unknown SRGs: Keep first 3-4 meaningful words
 * - Always append " SRG" suffix for clarity
 *
 * Examples:
 * - "General Purpose Operating System Security Requirements Guide" → "GPOS SRG"
 * - "Database Security Requirements Guide" → "Database SRG"
 * - "Web Server Security Requirements Guide" → "Web Server SRG"
 */
describe('abbreviateSrgName', () => {
  it('abbreviates General Purpose Operating System SRG', () => {
    const result = abbreviateSrgName('General Purpose Operating System Security Requirements Guide')
    expect(result).toBe('GPOS SRG')
  })

  it('abbreviates Database SRG', () => {
    const result = abbreviateSrgName('Database Security Requirements Guide')
    expect(result).toBe('Database SRG')
  })

  it('abbreviates Web Server SRG', () => {
    const result = abbreviateSrgName('Web Server Security Requirements Guide')
    expect(result).toBe('Web Server SRG')
  })

  it('abbreviates Windows Server SRG', () => {
    const result = abbreviateSrgName('Windows Server Security Requirements Guide')
    expect(result).toBe('Windows Server SRG')
  })

  it('abbreviates Application Security and Development SRG', () => {
    const result = abbreviateSrgName('Application Security and Development Security Requirements Guide')
    expect(result).toBe('App Sec & Dev SRG')
  })

  it('abbreviates Container Platform SRG', () => {
    const result = abbreviateSrgName('Container Platform Security Requirements Guide')
    expect(result).toBe('Container Platform SRG')
  })

  it('keeps unknown SRG names with first few words', () => {
    const result = abbreviateSrgName('Custom Security Thing Security Requirements Guide')
    expect(result).toBe('Custom Security Thing SRG')
  })

  it('handles already short names', () => {
    const result = abbreviateSrgName('Test SRG')
    expect(result).toBe('Test SRG')
  })

  it('handles names without "Security Requirements Guide"', () => {
    const result = abbreviateSrgName('Some Other Document')
    expect(result).toBe('Some Other Document')
  })

  it('handles null gracefully', () => {
    const result = abbreviateSrgName(null)
    expect(result).toBe('')
  })

  it('handles undefined gracefully', () => {
    const result = abbreviateSrgName(undefined)
    expect(result).toBe('')
  })

  it('handles empty string', () => {
    const result = abbreviateSrgName('')
    expect(result).toBe('')
  })
})
