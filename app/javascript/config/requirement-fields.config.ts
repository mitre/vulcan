/**
 * Requirement Fields Configuration
 *
 * Defines which fields are displayed/editable for each status.
 * This is the source of truth for the status → fields relationship.
 *
 * Field Categories:
 * - rule: Core rule fields (status, title, fixtext, etc.)
 * - disa: DISA rule description fields (vuln_discussion, mitigations, etc.)
 * - check: Check/test script fields
 */

// All possible rule statuses
export const RULE_STATUSES = [
  'Not Yet Determined',
  'Applicable - Configurable',
  'Applicable - Inherently Meets',
  'Applicable - Does Not Meet',
  'Not Applicable',
] as const

export type RuleStatusType = (typeof RULE_STATUSES)[number]

// Field visibility/editability configuration
export interface FieldConfig {
  displayed: string[]
  disabled: string[]
}

export interface StatusFieldConfig {
  rule: FieldConfig
  disa: FieldConfig
  check: FieldConfig
  tooltips: Record<string, string | null>
}

/**
 * Field configurations by status
 */
export const STATUS_FIELD_CONFIG: Record<RuleStatusType, StatusFieldConfig> = {
  /**
   * NOT YET DETERMINED
   * Triage state - user must bucket into another status
   * Fields are mostly inherited from SRG (readonly)
   */
  'Not Yet Determined': {
    rule: {
      displayed: ['status', 'title', 'vendor_comments'],
      disabled: ['title'], // Inherited from SRG
    },
    disa: {
      displayed: ['vuln_discussion'],
      disabled: ['vuln_discussion'], // Inherited from SRG
    },
    check: {
      displayed: [],
      disabled: [],
    },
    tooltips: {
      status: 'Select how this requirement applies to your product',
      title: 'Inherited from SRG - will be editable after status selection',
      vuln_discussion: 'Inherited from SRG - will be editable after status selection',
    },
  },

  /**
   * APPLICABLE - CONFIGURABLE
   * The main authoring status - these become STIG rules
   * All core fields are editable
   */
  'Applicable - Configurable': {
    rule: {
      displayed: [
        'status',
        'title',
        'rule_severity',
        'fixtext',
        'vendor_comments',
      ],
      disabled: [],
    },
    disa: {
      displayed: ['vuln_discussion'],
      disabled: [],
    },
    check: {
      displayed: ['content'], // The check/test script
      disabled: [],
    },
    tooltips: {
      status: 'Applicable - Configurable: The product requires configuration to achieve compliance',
      title: 'Describe the vulnerability for this control',
      rule_severity: 'CAT I (High), CAT II (Medium), CAT III (Low), or Info',
      fixtext: 'Describe how to correctly configure the requirement to remediate the vulnerability',
      vuln_discussion: 'Discuss, in detail, the rationale for this control\'s vulnerability',
      content: 'The check/test script to validate compliance',
      vendor_comments: 'Internal notes - not published in final STIG',
    },
  },

  /**
   * APPLICABLE - INHERENTLY MEETS
   * Hardcoded compliant - user doesn't need to configure anything
   * Requires justification and evidence
   * WARNING: High risk - these are "forgotten" after initial adjudication
   */
  'Applicable - Inherently Meets': {
    rule: {
      displayed: [
        'status',
        'status_justification',
        'artifact_description',
        'vendor_comments',
      ],
      disabled: [],
    },
    disa: {
      displayed: [],
      disabled: [],
    },
    check: {
      displayed: [],
      disabled: [],
    },
    tooltips: {
      status: 'Applicable - Inherently Meets: The product is compliant by default and cannot be reconfigured to a noncompliant state',
      status_justification: 'Explain WHY this requirement is inherently met by the product',
      artifact_description: 'Provide evidence (code files, documentation, screenshots) that the control is inherently met',
      vendor_comments: 'Internal notes - not published in final STIG',
    },
  },

  /**
   * APPLICABLE - DOES NOT MEET
   * Cannot comply - always a FAIL until code changes
   * Requires justification + either Mitigation OR POA&M (XOR)
   */
  'Applicable - Does Not Meet': {
    rule: {
      displayed: [
        'status',
        'status_justification',
        'vendor_comments',
      ],
      disabled: [],
    },
    disa: {
      displayed: [
        'mitigations_available',
        'mitigations',
        'poam_available',
        'poam',
      ],
      disabled: [],
    },
    check: {
      displayed: [],
      disabled: [],
    },
    tooltips: {
      status: 'Applicable - Does Not Meet: There are no technical means to achieve compliance',
      status_justification: 'Explain WHY this requirement cannot be met',
      mitigations_available: 'Toggle if mitigations are available for this vulnerability',
      mitigations: 'Describe how the system mitigates this vulnerability in the absence of a configuration',
      poam_available: 'Toggle if a Plan of Action & Milestones exists (only if no mitigations)',
      poam: 'Describe the POA&M action, including start and end dates',
      vendor_comments: 'Internal notes - not published in final STIG',
    },
  },

  /**
   * NOT APPLICABLE
   * Requirement addresses capability the product doesn't support
   * Requires justification and evidence
   */
  'Not Applicable': {
    rule: {
      displayed: [
        'status',
        'status_justification',
        'artifact_description',
        'vendor_comments',
      ],
      disabled: [],
    },
    disa: {
      displayed: [],
      disabled: [],
    },
    check: {
      displayed: [],
      disabled: [],
    },
    tooltips: {
      status: 'Not Applicable: The requirement addresses a capability or use case that the product does not support',
      status_justification: 'Explain WHY this requirement is not applicable to the product',
      artifact_description: 'Provide evidence that the control is not applicable to the system',
      vendor_comments: 'Internal notes - not published in final STIG',
    },
  },
}

/**
 * Get field configuration for a given status
 */
export function getFieldConfig(status: RuleStatusType): StatusFieldConfig {
  return STATUS_FIELD_CONFIG[status] || STATUS_FIELD_CONFIG['Not Yet Determined']
}

/**
 * Check if a field should be displayed for a given status
 */
export function isFieldDisplayed(
  status: RuleStatusType,
  fieldName: string,
  category: 'rule' | 'disa' | 'check' = 'rule',
): boolean {
  const config = getFieldConfig(status)
  return config[category].displayed.includes(fieldName)
}

/**
 * Check if a field should be disabled for a given status
 */
export function isFieldDisabled(
  status: RuleStatusType,
  fieldName: string,
  category: 'rule' | 'disa' | 'check' = 'rule',
): boolean {
  const config = getFieldConfig(status)
  return config[category].disabled.includes(fieldName)
}

/**
 * Get tooltip for a field in a given status context
 */
export function getFieldTooltip(status: RuleStatusType, fieldName: string): string | null {
  const config = getFieldConfig(status)
  return config.tooltips[fieldName] ?? null
}

/**
 * Special handling for merged rules (satisfied_by relationship)
 * Behaves like Configurable but with some fields disabled
 */
export function getMergedRuleFieldConfig(): StatusFieldConfig {
  const base = { ...STATUS_FIELD_CONFIG['Applicable - Configurable'] }
  return {
    ...base,
    rule: {
      ...base.rule,
      disabled: ['title', 'fixtext'], // Inherited from satisfying rule
    },
  }
}

/**
 * Risk levels by status for UI indicators
 */
export const STATUS_RISK_LEVELS: Record<RuleStatusType, 'none' | 'low' | 'medium' | 'high'> = {
  'Not Yet Determined': 'none',
  'Applicable - Configurable': 'low',
  'Applicable - Inherently Meets': 'high',
  'Applicable - Does Not Meet': 'medium',
  'Not Applicable': 'medium',
}

/**
 * Get risk level for a status
 */
export function getStatusRiskLevel(status: RuleStatusType): 'none' | 'low' | 'medium' | 'high' {
  return STATUS_RISK_LEVELS[status] || 'none'
}

/**
 * Risk level descriptions for tooltips
 */
export const RISK_LEVEL_DESCRIPTIONS: Record<string, string> = {
  low: 'Low risk: Actively reviewed and monitored in the STIG',
  medium: 'Medium risk: Should be periodically reviewed',
  high: 'High risk: May be forgotten after initial adjudication - review periodically',
}
