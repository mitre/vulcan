/**
 * SRG ID Formatter
 *
 * Truncates long SRG IDs for compact display.
 */

/**
 * Truncate SRG ID to significant part (remove GPOS suffix)
 *
 * @param {string|null|undefined} srgId - Full SRG ID (e.g., "SRG-OS-000480-GPOS-00227")
 * @returns {string} Truncated SRG ID (e.g., "SRG-OS-000480") or empty string
 *
 * @example
 * truncateSrgId('SRG-OS-000480-GPOS-00227') // => 'SRG-OS-000480'
 * truncateSrgId('SRG-APP-000123-GPOS-00456') // => 'SRG-APP-000123'
 */
export function truncateSrgId(srgId) {
  if (!srgId) return "";

  // SRG IDs follow pattern: SRG-{DOMAIN}-{NUMBER}-GPOS-{NUMBER}
  // We want to show: SRG-{DOMAIN}-{NUMBER}
  // Remove the -GPOS-##### suffix
  const truncated = srgId.replace(/-GPOS-\d+$/, "");

  return truncated;
}
