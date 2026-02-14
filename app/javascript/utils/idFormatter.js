/**
 * Generic ID Formatter
 *
 * DRY utility to truncate ALL ID types (SRG, STIG, Rule, Component) by removing
 * non-meaningful suffixes while keeping the unique identifier.
 */

/**
 * Truncate any ID type to its significant part
 *
 * Patterns handled:
 * - SRG: "SRG-OS-000480-GPOS-00227" → "SRG-OS-000480" (remove -GPOS-#####)
 * - STIG: "SV-257777r925318_rule" → "SV-257777" (remove r#####_rule)
 * - Component: "CNTR-00-000020" → "CNTR-00-000020" (no change)
 *
 * @param {string|null|undefined} id - Any ID format
 * @returns {string} Truncated ID or empty string if invalid
 *
 * @example
 * truncateId('SRG-OS-000480-GPOS-00227') // => 'SRG-OS-000480'
 * truncateId('SV-257777r925318_rule')    // => 'SV-257777'
 * truncateId('CNTR-00-000020')           // => 'CNTR-00-000020'
 */
export function truncateId(id) {
  if (!id) return "";

  let truncated = id;

  // Remove SRG GPOS suffix: -GPOS-#####
  truncated = truncated.replace(/-GPOS-\d+$/, "");

  // Remove STIG revision suffix: r##### (with or without _rule)
  truncated = truncated.replace(/r\d+(_rule)?$/, "");
  // Remove standalone _rule suffix
  truncated = truncated.replace(/_rule$/, "");

  return truncated;
}

// Backward compatibility - keep old function names as aliases
export const truncateSrgId = truncateId;
export const truncateRuleId = truncateId;
