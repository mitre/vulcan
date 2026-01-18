/**
 * STIG (Security Technical Implementation Guide) TypeScript interfaces
 */

import type { IBenchmarkCheck, IBenchmarkRuleDescription } from './benchmark'

/**
 * STIG Rule (from parsed XCCDF)
 */
export interface IStigRule {
  id: number
  stig_id: number
  version: string
  title: string
  rule_id?: string
  vuln_id?: string
  rule_severity?: string
  rule_weight?: string
  ident?: string
  ident_system?: string
  legacy_ids?: string
  fix_id?: string
  fixtext?: string
  fixtext_fixref?: string
  srg_id?: string
  // Nested attributes from API (using shared types)
  checks_attributes?: IBenchmarkCheck[]
  disa_rule_descriptions_attributes?: IBenchmarkRuleDescription[]
}

/**
 * Core STIG interface matching Rails Stig model
 */
export interface IStig {
  id: number
  stig_id: string
  title: string
  name: string
  version: string
  description?: string
  benchmark_date?: string
  created_at: string
  updated_at: string
  // Relations (not usually loaded)
  stig_rules?: IStigRule[]
}

/**
 * STIG list item (minimal for listings)
 */
export interface IStigListItem {
  id: number
  name: string
  title: string
  version: string
}

/**
 * STIGs store state interface
 */
export interface IStigsState {
  stigs: IStig[]
  currentStig: IStig | null
  loading: boolean
  error: string | null
}
