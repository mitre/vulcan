/**
 * Ident Parser Utilities
 *
 * Parse security control references from rule ident fields.
 * Rules often reference MITRE ATT&CK techniques and CIS Controls
 * in comma-separated ident fields.
 */

/**
 * Parse MITRE ATT&CK technique IDs from ident string
 *
 * Extracts technique IDs in format: T####, T####.###
 * Examples: "T1078", "T1078.004"
 *
 * @param {string|null|undefined} ident - Comma-separated ident string
 * @returns {string[]} Array of MITRE technique IDs
 */
export function parseMitreAttack(ident) {
  if (!ident) return [];

  // Match MITRE ATT&CK technique pattern: T followed by 4 digits, optionally .### for subtechnique
  const mitrePattern = /T\d{4}(?:\.\d{3})?/g;
  const matches = ident.match(mitrePattern);

  return matches || [];
}

/**
 * Parse CIS Control IDs from ident string
 *
 * Extracts control IDs in formats:
 * - Single digit: "18"
 * - Major.Minor: "5.2", "6.1"
 * - Major.Minor.Sub: "5.2.1"
 *
 * @param {string|null|undefined} ident - Comma-separated ident string
 * @returns {string[]} Array of CIS Control IDs
 */
export function parseCisControls(ident) {
  if (!ident) return [];

  // Match CIS Control pattern: Number, Number.Number, or Number.Number.Number
  // Extracts standalone numbers or decimal numbers from comma-separated list
  const cisPattern = /\b\d{1,2}(?:\.\d{1,2}(?:\.\d{1,2})?)?\b/g;
  const matches = ident.match(cisPattern);

  if (!matches) return [];

  // Filter out results that are clearly not CIS controls
  // CIS controls are typically: 1-18 (v7) or with decimals like 5.2
  // Exclude things that look like years (2024), long numbers, etc.
  return matches.filter((match) => {
    const num = Number.parseFloat(match);
    // CIS v7 has controls 1-18, v8 has 1-18 as well
    // Accept single/double digit numbers and decimals in that range
    return num >= 1 && num <= 99 && match.length <= 6;
  });
}
