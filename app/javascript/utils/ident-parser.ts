/**
 * Ident Parser Utility
 *
 * Parses XCCDF ident strings into categorized arrays for display.
 *
 * XCCDF idents include multiple identifier types:
 * - CCIs (CCI-000000): DISA Control Correlation Identifiers
 * - CIS Controls v7 (7:X.Y): CIS Critical Security Controls v7
 * - CIS Controls v8 (8:X.Y): CIS Critical Security Controls v8
 * - MITRE ATT&CK Techniques (T0000): Attack techniques
 * - MITRE ATT&CK Tactics (TA0000): Attack tactics
 * - MITRE ATT&CK Mitigations (M0000): Mitigations
 */

/**
 * Parsed ident categories
 */
export interface IParsedIdents {
  ccis: string[]
  cisV7: string[]
  cisV8: string[]
  mitreTechniques: string[]
  mitreTactics: string[]
  mitreMitigations: string[]
  other: string[]
}

/**
 * Parse a comma-separated ident string into categorized arrays
 *
 * @param ident - Comma-separated string of identifiers
 * @returns Categorized ident arrays
 *
 * @example
 * ```ts
 * const parsed = parseIdents('CCI-000366, 8:3.14, 7:14.9, T1565, TA0001, M1022')
 * // Returns:
 * // {
 * //   ccis: ['CCI-000366'],
 * //   cisV7: ['7:14.9'],
 * //   cisV8: ['8:3.14'],
 * //   mitreTechniques: ['T1565'],
 * //   mitreTactics: ['TA0001'],
 * //   mitreMitigations: ['M1022'],
 * //   other: []
 * // }
 * ```
 */
export function parseIdents(ident: string | null | undefined): IParsedIdents {
  const result: IParsedIdents = {
    ccis: [],
    cisV7: [],
    cisV8: [],
    mitreTechniques: [],
    mitreTactics: [],
    mitreMitigations: [],
    other: [],
  }

  if (!ident)
    return result

  const idents = ident.split(/,\s*/)

  for (const item of idents) {
    const trimmed = item.trim()
    if (!trimmed)
      continue

    if (trimmed.startsWith('CCI-')) {
      result.ccis.push(trimmed)
    }
    else if (trimmed.startsWith('7:')) {
      result.cisV7.push(trimmed)
    }
    else if (trimmed.startsWith('8:')) {
      result.cisV8.push(trimmed)
    }
    else if (/^T\d/.test(trimmed)) {
      result.mitreTechniques.push(trimmed)
    }
    else if (/^TA\d/.test(trimmed)) {
      result.mitreTactics.push(trimmed)
    }
    else if (/^M\d/.test(trimmed)) {
      result.mitreMitigations.push(trimmed)
    }
    else {
      result.other.push(trimmed)
    }
  }

  return result
}

/**
 * Check if parsed idents has any CIS Controls data
 */
export function hasCisControls(parsed: IParsedIdents): boolean {
  return parsed.cisV7.length > 0 || parsed.cisV8.length > 0
}

/**
 * Check if parsed idents has any MITRE ATT&CK data
 */
export function hasMitreData(parsed: IParsedIdents): boolean {
  return parsed.mitreTechniques.length > 0
    || parsed.mitreTactics.length > 0
    || parsed.mitreMitigations.length > 0
}

/**
 * Format CIS Control for display (strips version prefix)
 * @example formatCisControl('8:3.14') => '3.14'
 */
export function formatCisControl(control: string): string {
  return control.replace(/^\d:/, '')
}
