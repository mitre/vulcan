import { describe, it, expect } from 'vitest'
import { truncateId } from '@/utils/idFormatter'

/**
 * Generic ID Formatter Tests
 *
 * REQUIREMENTS:
 *
 * One DRY function to truncate ALL ID types (SRG, STIG, Rule, Component).
 * Pattern: Remove non-meaningful suffixes while keeping unique identifier.
 *
 * Patterns to truncate:
 * - SRG: "SRG-OS-000480-GPOS-00227" → "SRG-OS-000480" (remove -GPOS-####)
 * - STIG Rule: "SV-257777r925318_rule" → "SV-257777" (remove r####_rule)
 * - Component/Rule: "CNTR-00-000020" → "CNTR-00-000020" (already short)
 */
describe('truncateId - generic ID truncation', () => {
  // ==========================================
  // SRG IDs
  // ==========================================
  describe('SRG IDs', () => {
    it('truncates SRG-OS format', () => {
      expect(truncateId('SRG-OS-000480-GPOS-00227')).toBe('SRG-OS-000480')
    })

    it('truncates SRG-APP format', () => {
      expect(truncateId('SRG-APP-000123-GPOS-00456')).toBe('SRG-APP-000123')
    })

    it('truncates SRG-NET format', () => {
      expect(truncateId('SRG-NET-000789-GPOS-00111')).toBe('SRG-NET-000789')
    })

    it('handles SRG without GPOS suffix', () => {
      expect(truncateId('SRG-OS-000480')).toBe('SRG-OS-000480')
    })
  })

  // ==========================================
  // STIG Rule IDs
  // ==========================================
  describe('STIG Rule IDs', () => {
    it('truncates SV format with revision', () => {
      expect(truncateId('SV-257777r925318_rule')).toBe('SV-257777')
    })

    it('truncates V format with revision', () => {
      expect(truncateId('V-203591r557031_rule')).toBe('V-203591')
    })

    it('handles rule ID without revision', () => {
      expect(truncateId('SV-257777_rule')).toBe('SV-257777')
    })

    it('handles rule ID without _rule suffix', () => {
      expect(truncateId('SV-257777r925318')).toBe('SV-257777')
    })
  })

  // ==========================================
  // Component/Custom Rule IDs
  // ==========================================
  describe('Component and custom rule IDs', () => {
    it('keeps component rule IDs unchanged', () => {
      expect(truncateId('CNTR-00-000020')).toBe('CNTR-00-000020')
    })

    it('keeps RHEL format unchanged', () => {
      expect(truncateId('RHEL-09-211010')).toBe('RHEL-09-211010')
    })

    it('keeps PHOS format unchanged', () => {
      expect(truncateId('PHOS-03-000001')).toBe('PHOS-03-000001')
    })
  })

  // ==========================================
  // Edge Cases
  // ==========================================
  describe('edge cases', () => {
    it('handles null gracefully', () => {
      expect(truncateId(null)).toBe('')
    })

    it('handles undefined gracefully', () => {
      expect(truncateId(undefined)).toBe('')
    })

    it('handles empty string', () => {
      expect(truncateId('')).toBe('')
    })

    it('handles short arbitrary ID', () => {
      expect(truncateId('ABC-123')).toBe('ABC-123')
    })

    it('handles custom format unchanged', () => {
      expect(truncateId('CUSTOM-FORMAT-12345')).toBe('CUSTOM-FORMAT-12345')
    })
  })
})
