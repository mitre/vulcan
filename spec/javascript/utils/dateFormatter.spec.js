import { describe, it, expect } from 'vitest'
import { formatDate, formatDateLong } from '@/utils/dateFormatter'

/**
 * Date Formatter Tests
 *
 * REQUIREMENTS:
 *
 * 1. formatDate(dateString)
 *    - Converts ISO date to readable format: "Nov 26, 2025"
 *    - Handles null/undefined gracefully (returns empty string)
 *    - Handles invalid dates (returns empty string)
 *
 * 2. formatDateLong(dateString)
 *    - Converts ISO date to full format: "November 26, 2025"
 *    - Handles null/undefined gracefully (returns empty string)
 *    - Handles invalid dates (returns empty string)
 */
describe('Date Formatter', () => {
  describe('formatDate', () => {
    it('formats ISO date to short month format', () => {
      const result = formatDate('2025-11-26')
      expect(result).toBe('Nov 26, 2025')
    })

    it('formats date without time', () => {
      const result = formatDate('2025-01-15')
      expect(result).toBe('Jan 15, 2025')
    })

    it('handles null gracefully', () => {
      const result = formatDate(null)
      expect(result).toBe('')
    })

    it('handles undefined gracefully', () => {
      const result = formatDate(undefined)
      expect(result).toBe('')
    })

    it('handles empty string gracefully', () => {
      const result = formatDate('')
      expect(result).toBe('')
    })

    it('handles invalid date string gracefully', () => {
      const result = formatDate('not-a-date')
      expect(result).toBe('')
    })

    it('formats various months correctly', () => {
      expect(formatDate('2025-01-01')).toBe('Jan 1, 2025')
      expect(formatDate('2025-02-01')).toBe('Feb 1, 2025')
      expect(formatDate('2025-03-01')).toBe('Mar 1, 2025')
      expect(formatDate('2025-12-31')).toBe('Dec 31, 2025')
    })
  })

  describe('formatDateLong', () => {
    it('formats ISO date to long month format', () => {
      const result = formatDateLong('2025-11-26')
      expect(result).toBe('November 26, 2025')
    })

    it('formats date without time', () => {
      const result = formatDateLong('2025-01-15')
      expect(result).toBe('January 15, 2025')
    })

    it('handles null gracefully', () => {
      const result = formatDateLong(null)
      expect(result).toBe('')
    })

    it('handles undefined gracefully', () => {
      const result = formatDateLong(undefined)
      expect(result).toBe('')
    })

    it('handles invalid date string gracefully', () => {
      const result = formatDateLong('not-a-date')
      expect(result).toBe('')
    })
  })
})
