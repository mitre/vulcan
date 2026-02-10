/**
 * Date Formatting Utilities
 *
 * Provides consistent date formatting across the application.
 */

/**
 * Parse date string to local Date object (avoiding timezone shifts)
 *
 * @param {string|Date} dateString - ISO date string or Date object
 * @returns {Date|null} Local date or null if invalid
 */
function parseLocalDate(dateString) {
  if (dateString instanceof Date) return dateString;
  if (!dateString) return null;

  // For date-only strings (YYYY-MM-DD), parse as local date to avoid UTC timezone shift
  const dateOnlyPattern = /^\d{4}-\d{2}-\d{2}$/;
  if (dateOnlyPattern.test(dateString)) {
    const [year, month, day] = dateString.split("-").map(Number);
    return new Date(year, month - 1, day); // Month is 0-indexed
  }

  // For datetime strings, use default parsing
  const date = new Date(dateString);
  return isNaN(date.getTime()) ? null : date;
}

/**
 * Format date to short month format: "Nov 26, 2025"
 *
 * @param {string|Date|null|undefined} dateString - ISO date string or Date object
 * @returns {string} Formatted date or empty string if invalid
 */
export function formatDate(dateString) {
  const date = parseLocalDate(dateString);
  if (!date) return "";

  const options = { year: "numeric", month: "short", day: "numeric" };
  return date.toLocaleDateString("en-US", options);
}

/**
 * Format date to long month format: "November 26, 2025"
 *
 * @param {string|Date|null|undefined} dateString - ISO date string or Date object
 * @returns {string} Formatted date or empty string if invalid
 */
export function formatDateLong(dateString) {
  const date = parseLocalDate(dateString);
  if (!date) return "";

  const options = { year: "numeric", month: "long", day: "numeric" };
  return date.toLocaleDateString("en-US", options);
}
