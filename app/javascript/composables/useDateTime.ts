/**
 * DateTime Composable
 * Date formatting utilities
 */

import moment from 'moment'

/**
 * Format datetime to friendly display (e.g., "Nov 27, 2025 3:45 PM")
 */
export function formatDateTime(dateTimeString: string | Date): string {
  return moment(dateTimeString).format('lll')
}

/**
 * Format date only (e.g., "Nov 27, 2025")
 */
export function formatDate(dateTimeString: string | Date): string {
  return moment(dateTimeString).format('ll')
}

/**
 * Format relative time (e.g., "2 hours ago")
 */
export function formatRelative(dateTimeString: string | Date): string {
  return moment(dateTimeString).fromNow()
}

/**
 * Composable wrapper
 */
export function useDateTime() {
  return {
    formatDateTime,
    formatDate,
    formatRelative,
  }
}
