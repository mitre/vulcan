/**
 * Rule ID Formatter Utilities
 *
 * Handles display formatting for XCCDF rule identifiers.
 */

/**
 * Truncate a rule ID by removing the release/revision suffix.
 *
 * "SV-203591r557031_rule" → "SV-203591"
 * Pattern: strips everything from the first 'r' followed by digits onward.
 *
 * @param {string|null|undefined} ruleId - Full rule ID string
 * @returns {string} Truncated rule ID, or empty string for falsy input
 */
export function truncateRuleId(ruleId) {
  if (!ruleId) return "";
  const idx = ruleId.search(/r\d/);
  return idx === -1 ? ruleId : ruleId.substring(0, idx);
}
