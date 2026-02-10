/**
 * SRG Name Abbreviator
 *
 * Abbreviates long SRG names for compact table display.
 */

// Known SRG name mappings
const SRG_ABBREVIATIONS = {
  "General Purpose Operating System Security Requirements Guide": "GPOS SRG",
  "Application Security and Development Security Requirements Guide": "App Sec & Dev SRG",
};

/**
 * Abbreviate SRG name for compact display
 *
 * @param {string|null|undefined} srgName - Full SRG name
 * @returns {string} Abbreviated name or empty string if invalid
 */
export function abbreviateSrgName(srgName) {
  if (!srgName) return "";

  // Check known abbreviations first
  if (SRG_ABBREVIATIONS[srgName]) {
    return SRG_ABBREVIATIONS[srgName];
  }

  // If name ends with "Security Requirements Guide", strip it and add " SRG"
  if (srgName.endsWith("Security Requirements Guide")) {
    const baseName = srgName.replace(/\s*Security Requirements Guide\s*$/, "").trim();
    return `${baseName} SRG`;
  }

  // If name already contains "SRG", return as-is
  if (srgName.toUpperCase().includes("SRG")) {
    return srgName;
  }

  // Otherwise return as-is (might be already short or custom format)
  return srgName;
}
