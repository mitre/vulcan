import { describe, it, expect } from 'vitest'
import { stigToBenchmark, srgToBenchmark } from '@/adapters/benchmark'

/**
 * Benchmark Adapter Tests
 *
 * REQUIREMENTS:
 *
 * Adapters normalize STIG and SRG data into a unified structure so
 * BenchmarkViewer can work with both without knowing the differences.
 *
 * UNIFIED STRUCTURE:
 * {
 *   id: number,
 *   benchmark_id: string,    // stig_id or srg_id
 *   title: string,
 *   version: string,
 *   date: string,            // benchmark_date or release_date
 *   rules: array             // stig_rules or srg_rules
 * }
 */
describe('Benchmark Adapters', () => {
  // ==========================================
  // STIG TO BENCHMARK
  // ==========================================
  describe('stigToBenchmark', () => {
    const sampleStig = {
      id: 1,
      stig_id: 'TEST_STIG',
      title: 'Test STIG',
      version: 'V1R1',
      benchmark_date: '2024-01-15',
      stig_rules: [
        { id: 1, rule_id: 'SV-001', title: 'Rule One' },
        { id: 2, rule_id: 'SV-002', title: 'Rule Two' }
      ]
    }

    it('preserves id', () => {
      const result = stigToBenchmark(sampleStig)
      expect(result.id).toBe(1)
    })

    it('normalizes stig_id to benchmark_id', () => {
      const result = stigToBenchmark(sampleStig)
      expect(result.benchmark_id).toBe('TEST_STIG')
    })

    it('preserves title', () => {
      const result = stigToBenchmark(sampleStig)
      expect(result.title).toBe('Test STIG')
    })

    it('preserves version', () => {
      const result = stigToBenchmark(sampleStig)
      expect(result.version).toBe('V1R1')
    })

    it('normalizes benchmark_date to date', () => {
      const result = stigToBenchmark(sampleStig)
      expect(result.date).toBe('2024-01-15')
    })

    it('normalizes stig_rules to rules', () => {
      const result = stigToBenchmark(sampleStig)
      expect(result.rules).toHaveLength(2)
      expect(result.rules[0].rule_id).toBe('SV-001')
      expect(result.rules[1].rule_id).toBe('SV-002')
    })

    it('handles missing stig_rules gracefully', () => {
      const stigWithoutRules = { ...sampleStig, stig_rules: undefined }
      const result = stigToBenchmark(stigWithoutRules)
      expect(result.rules).toEqual([])
    })

    it('handles null stig_rules gracefully', () => {
      const stigWithNull = { ...sampleStig, stig_rules: null }
      const result = stigToBenchmark(stigWithNull)
      expect(result.rules).toEqual([])
    })

    it('handles empty stig_rules array', () => {
      const stigEmpty = { ...sampleStig, stig_rules: [] }
      const result = stigToBenchmark(stigEmpty)
      expect(result.rules).toEqual([])
    })
  })

  // ==========================================
  // SRG TO BENCHMARK
  // ==========================================
  describe('srgToBenchmark', () => {
    const sampleSrg = {
      id: 2,
      srg_id: 'TEST_SRG',
      title: 'Test SRG',
      version: 'V2R1',
      release_date: '2024-02-20',
      srg_rules: [
        { id: 10, rule_id: 'SRG-001', title: 'Requirement One' },
        { id: 11, rule_id: 'SRG-002', title: 'Requirement Two' }
      ]
    }

    it('preserves id', () => {
      const result = srgToBenchmark(sampleSrg)
      expect(result.id).toBe(2)
    })

    it('normalizes srg_id to benchmark_id', () => {
      const result = srgToBenchmark(sampleSrg)
      expect(result.benchmark_id).toBe('TEST_SRG')
    })

    it('preserves title', () => {
      const result = srgToBenchmark(sampleSrg)
      expect(result.title).toBe('Test SRG')
    })

    it('preserves version', () => {
      const result = srgToBenchmark(sampleSrg)
      expect(result.version).toBe('V2R1')
    })

    it('normalizes release_date to date', () => {
      const result = srgToBenchmark(sampleSrg)
      expect(result.date).toBe('2024-02-20')
    })

    it('normalizes srg_rules to rules', () => {
      const result = srgToBenchmark(sampleSrg)
      expect(result.rules).toHaveLength(2)
      expect(result.rules[0].rule_id).toBe('SRG-001')
      expect(result.rules[1].rule_id).toBe('SRG-002')
    })

    it('handles missing srg_rules gracefully', () => {
      const srgWithoutRules = { ...sampleSrg, srg_rules: undefined }
      const result = srgToBenchmark(srgWithoutRules)
      expect(result.rules).toEqual([])
    })

    it('handles null srg_rules gracefully', () => {
      const srgWithNull = { ...sampleSrg, srg_rules: null }
      const result = srgToBenchmark(srgWithNull)
      expect(result.rules).toEqual([])
    })

    it('handles empty srg_rules array', () => {
      const srgEmpty = { ...sampleSrg, srg_rules: [] }
      const result = srgToBenchmark(srgEmpty)
      expect(result.rules).toEqual([])
    })
  })

  // ==========================================
  // UNIFIED STRUCTURE VALIDATION
  // ==========================================
  describe('unified structure', () => {
    it('STIG and SRG adapters produce identical structure', () => {
      const stig = {
        id: 1,
        stig_id: 'TEST',
        title: 'Test',
        version: 'V1R1',
        benchmark_date: '2024-01-01',
        stig_rules: []
      }

      const srg = {
        id: 1,
        srg_id: 'TEST',
        title: 'Test',
        version: 'V1R1',
        release_date: '2024-01-01',
        srg_rules: []
      }

      const stigResult = stigToBenchmark(stig)
      const srgResult = srgToBenchmark(srg)

      // Both should have same structure
      expect(Object.keys(stigResult).sort((a, b) => a.localeCompare(b))).toEqual(Object.keys(srgResult).sort((a, b) => a.localeCompare(b)))
      expect(stigResult.benchmark_id).toBe(srgResult.benchmark_id)
      expect(stigResult.date).toBe(srgResult.date)
      expect(Array.isArray(stigResult.rules)).toBe(true)
      expect(Array.isArray(srgResult.rules)).toBe(true)
    })
  })
})
