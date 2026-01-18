/**
 * Ident Parser Utility Tests
 */

import { describe, expect, it } from 'vitest'
import {
  formatCisControl,
  hasCisControls,
  hasMitreData,
  parseIdents,
} from '../ident-parser'

describe('ident Parser', () => {
  describe('parseIdents', () => {
    it('returns empty arrays for null input', () => {
      const result = parseIdents(null)

      expect(result.ccis).toEqual([])
      expect(result.cisV7).toEqual([])
      expect(result.cisV8).toEqual([])
      expect(result.mitreTechniques).toEqual([])
      expect(result.mitreTactics).toEqual([])
      expect(result.mitreMitigations).toEqual([])
      expect(result.other).toEqual([])
    })

    it('returns empty arrays for undefined input', () => {
      const result = parseIdents(undefined)

      expect(result.ccis).toEqual([])
    })

    it('returns empty arrays for empty string', () => {
      const result = parseIdents('')

      expect(result.ccis).toEqual([])
    })

    it('parses CCI identifiers', () => {
      const result = parseIdents('CCI-000366, CCI-002447, CCI-000123')

      expect(result.ccis).toEqual(['CCI-000366', 'CCI-002447', 'CCI-000123'])
    })

    it('parses CIS Controls v7 identifiers', () => {
      const result = parseIdents('7:14.9, 7:5.1, 7:0.0')

      expect(result.cisV7).toEqual(['7:14.9', '7:5.1', '7:0.0'])
    })

    it('parses CIS Controls v8 identifiers', () => {
      const result = parseIdents('8:3.14, 8:5.1, 8:0.0')

      expect(result.cisV8).toEqual(['8:3.14', '8:5.1', '8:0.0'])
    })

    it('parses MITRE ATT&CK techniques', () => {
      const result = parseIdents('T1565, T1565.001, T1036, T1036.005')

      expect(result.mitreTechniques).toEqual(['T1565', 'T1565.001', 'T1036', 'T1036.005'])
    })

    it('parses MITRE ATT&CK tactics', () => {
      const result = parseIdents('TA0001, TA0040, TA0005')

      expect(result.mitreTactics).toEqual(['TA0001', 'TA0040', 'TA0005'])
    })

    it('parses MITRE ATT&CK mitigations', () => {
      const result = parseIdents('M1022, M1030, M1040')

      expect(result.mitreMitigations).toEqual(['M1022', 'M1030', 'M1040'])
    })

    it('categorizes mixed ident string correctly', () => {
      const ident = 'CCI-000366, 8:3.14, 7:14.9, T1565, TA0001, M1022'
      const result = parseIdents(ident)

      expect(result.ccis).toEqual(['CCI-000366'])
      expect(result.cisV7).toEqual(['7:14.9'])
      expect(result.cisV8).toEqual(['8:3.14'])
      expect(result.mitreTechniques).toEqual(['T1565'])
      expect(result.mitreTactics).toEqual(['TA0001'])
      expect(result.mitreMitigations).toEqual(['M1022'])
      expect(result.other).toEqual([])
    })

    it('puts unrecognized identifiers in other array', () => {
      const result = parseIdents('CCI-000366, UNKNOWN-123, CUSTOM_ID')

      expect(result.ccis).toEqual(['CCI-000366'])
      expect(result.other).toEqual(['UNKNOWN-123', 'CUSTOM_ID'])
    })

    it('handles extra whitespace correctly', () => {
      const result = parseIdents('  CCI-000366  ,   8:3.14   ,  T1565  ')

      expect(result.ccis).toEqual(['CCI-000366'])
      expect(result.cisV8).toEqual(['8:3.14'])
      expect(result.mitreTechniques).toEqual(['T1565'])
    })

    it('handles real-world cis-bench export data', () => {
      // Actual data from cis-bench DISA export
      const ident = 'CCI-000123, CCI-002447, 8:3.14, 7:14.9, T1565, T1565.001, TA0001, M1022'
      const result = parseIdents(ident)

      expect(result.ccis).toHaveLength(2)
      expect(result.cisV7).toHaveLength(1)
      expect(result.cisV8).toHaveLength(1)
      expect(result.mitreTechniques).toHaveLength(2)
      expect(result.mitreTactics).toHaveLength(1)
      expect(result.mitreMitigations).toHaveLength(1)
    })
  })

  describe('hasCisControls', () => {
    it('returns false when no CIS controls present', () => {
      const parsed = parseIdents('CCI-000366, T1565')

      expect(hasCisControls(parsed)).toBe(false)
    })

    it('returns true when CIS v7 controls present', () => {
      const parsed = parseIdents('CCI-000366, 7:14.9')

      expect(hasCisControls(parsed)).toBe(true)
    })

    it('returns true when CIS v8 controls present', () => {
      const parsed = parseIdents('CCI-000366, 8:3.14')

      expect(hasCisControls(parsed)).toBe(true)
    })

    it('returns true when both v7 and v8 present', () => {
      const parsed = parseIdents('7:14.9, 8:3.14')

      expect(hasCisControls(parsed)).toBe(true)
    })
  })

  describe('hasMitreData', () => {
    it('returns false when no MITRE data present', () => {
      const parsed = parseIdents('CCI-000366, 8:3.14')

      expect(hasMitreData(parsed)).toBe(false)
    })

    it('returns true when techniques present', () => {
      const parsed = parseIdents('T1565')

      expect(hasMitreData(parsed)).toBe(true)
    })

    it('returns true when tactics present', () => {
      const parsed = parseIdents('TA0001')

      expect(hasMitreData(parsed)).toBe(true)
    })

    it('returns true when mitigations present', () => {
      const parsed = parseIdents('M1022')

      expect(hasMitreData(parsed)).toBe(true)
    })

    it('returns true when all MITRE types present', () => {
      const parsed = parseIdents('T1565, TA0001, M1022')

      expect(hasMitreData(parsed)).toBe(true)
    })
  })

  describe('formatCisControl', () => {
    it('strips v7 prefix', () => {
      expect(formatCisControl('7:14.9')).toBe('14.9')
    })

    it('strips v8 prefix', () => {
      expect(formatCisControl('8:3.14')).toBe('3.14')
    })

    it('handles control with 0.0 (unmapped)', () => {
      expect(formatCisControl('7:0.0')).toBe('0.0')
      expect(formatCisControl('8:0.0')).toBe('0.0')
    })

    it('returns unchanged string if no prefix', () => {
      expect(formatCisControl('14.9')).toBe('14.9')
    })
  })
})
