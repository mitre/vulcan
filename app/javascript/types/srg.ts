/**
 * Security Requirements Guide (SRG) TypeScript interfaces
 */

import type { IBenchmarkCheck, IBenchmarkRuleDescription } from './benchmark'

/**
 * SRG Rule (from parsed XCCDF)
 */
export interface ISrgRule {
  id: number
  rule_id: string
  version: string
  title: string
  ident?: string
  ident_system?: string
  legacy_ids?: string
  fixtext?: string
  fixtext_fixref?: string
  fix_id?: string
  rule_severity: string
  rule_weight?: string
  security_requirements_guide_id: number
  // Nested attributes from API (using shared types)
  checks_attributes?: IBenchmarkCheck[]
  disa_rule_descriptions_attributes?: IBenchmarkRuleDescription[]
}

/**
 * Core SRG interface matching Rails SecurityRequirementsGuide model
 */
export interface ISecurityRequirementsGuide {
  id: number
  srg_id: string
  title: string
  name: string
  version: string
  release_date?: string
  created_at: string
  updated_at: string
  // Computed
  full_title?: string
  // Relations (not usually loaded)
  srg_rules?: ISrgRule[]
}

/**
 * SRG list item (minimal for dropdowns)
 */
export interface ISrgListItem {
  id: number
  title: string
  version: string
}

/**
 * SRGs store state interface
 */
export interface ISrgsState {
  srgs: ISecurityRequirementsGuide[]
  latestSrgs: ISrgListItem[]
  currentSrg: ISecurityRequirementsGuide | null
  loading: boolean
  error: string | null
}
