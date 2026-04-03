import { describe, it, expect } from 'vitest'
import { parseMitreAttack, parseCisControls } from '@/utils/identParser'

/**
 * Ident Parser Tests
 *
 * REQUIREMENTS:
 *
 * Rules have ident and ident_system fields that contain references to:
 * - MITRE ATT&CK techniques (e.g., "T1078", "T1078.004")
 * - CIS Controls (e.g., "5.2", "6.1", "18")
 *
 * Parsers extract and structure this data for display in RuleOverview.
 */
describe('Ident Parser', () => {
  // ==========================================
  // MITRE ATT&CK PARSER
  // ==========================================
  describe('parseMitreAttack', () => {
    it('parses single MITRE technique', () => {
      const ident = 'T1078'
      const result = parseMitreAttack(ident)
      expect(result).toEqual(['T1078'])
    })

    it('parses MITRE technique with subtechnique', () => {
      const ident = 'T1078.004'
      const result = parseMitreAttack(ident)
      expect(result).toEqual(['T1078.004'])
    })

    it('parses comma-separated techniques', () => {
      const ident = 'T1078, T1548, T1068'
      const result = parseMitreAttack(ident)
      expect(result).toEqual(['T1078', 'T1548', 'T1068'])
    })

    it('handles techniques with whitespace', () => {
      const ident = 'T1078 ,  T1548  , T1068'
      const result = parseMitreAttack(ident)
      expect(result).toEqual(['T1078', 'T1548', 'T1068'])
    })

    it('filters out non-MITRE content', () => {
      const ident = 'T1078, CCI-000123, T1548'
      const result = parseMitreAttack(ident)
      expect(result).toEqual(['T1078', 'T1548'])
    })

    it('returns empty array for null ident', () => {
      const result = parseMitreAttack(null)
      expect(result).toEqual([])
    })

    it('returns empty array for undefined ident', () => {
      const result = parseMitreAttack(undefined)
      expect(result).toEqual([])
    })

    it('returns empty array for empty string', () => {
      const result = parseMitreAttack('')
      expect(result).toEqual([])
    })

    it('returns empty array when no MITRE techniques found', () => {
      const ident = 'CCI-000123, CCI-000456'
      const result = parseMitreAttack(ident)
      expect(result).toEqual([])
    })
  })

  // ==========================================
  // CIS CONTROLS PARSER
  // ==========================================
  describe('parseCisControls', () => {
    it('parses single CIS control', () => {
      const ident = '5.2'
      const result = parseCisControls(ident)
      expect(result).toEqual(['5.2'])
    })

    it('parses single-digit CIS control', () => {
      const ident = '18'
      const result = parseCisControls(ident)
      expect(result).toEqual(['18'])
    })

    it('parses comma-separated CIS controls', () => {
      const ident = '5.2, 6.1, 18'
      const result = parseCisControls(ident)
      expect(result).toEqual(['5.2', '6.1', '18'])
    })

    it('handles controls with whitespace', () => {
      const ident = '5.2 ,  6.1  , 18'
      const result = parseCisControls(ident)
      expect(result).toEqual(['5.2', '6.1', '18'])
    })

    it('parses controls with three-digit decimals', () => {
      const ident = '5.2.1, 6.1.2'
      const result = parseCisControls(ident)
      expect(result).toEqual(['5.2.1', '6.1.2'])
    })

    it('filters out non-CIS content', () => {
      const ident = '5.2, T1078, 6.1'
      const result = parseCisControls(ident)
      expect(result).toEqual(['5.2', '6.1'])
    })

    it('returns empty array for null ident', () => {
      const result = parseCisControls(null)
      expect(result).toEqual([])
    })

    it('returns empty array for undefined ident', () => {
      const result = parseCisControls(undefined)
      expect(result).toEqual([])
    })

    it('returns empty array for empty string', () => {
      const result = parseCisControls('')
      expect(result).toEqual([])
    })

    it('returns empty array when no CIS controls found', () => {
      const ident = 'T1078, CCI-000123'
      const result = parseCisControls(ident)
      expect(result).toEqual([])
    })
  })
})
