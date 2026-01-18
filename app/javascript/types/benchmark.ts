/**
 * Unified Benchmark Types
 *
 * Both STIGs and SRGs are XCCDF benchmarks with nearly identical structures.
 * This file provides unified types that work for both.
 */

/**
 * Benchmark type discriminator
 */
// =============================================================================
// Type Adapters - Convert existing STIG/SRG types to unified benchmark types
// =============================================================================

import type { ISecurityRequirementsGuide, ISrgRule } from './srg'
import type { IStig, IStigRule } from './stig'

export type BenchmarkType = 'stig' | 'srg' | 'component'

/**
 * Check content for a rule
 */
export interface IBenchmarkCheck {
  id: number
  system?: string
  content_ref_name?: string
  content_ref_href?: string
  content?: string
}

/**
 * Rule description (DISA format)
 */
export interface IBenchmarkRuleDescription {
  id: number
  vuln_discussion?: string
  false_positives?: string
  false_negatives?: string
  documentable?: string
  mitigations?: string
  severity_override_guidance?: string
  potential_impacts?: string
  third_party_tools?: string
  mitigation_control?: string
  responsibility?: string
  ia_controls?: string
}

/**
 * Unified rule interface matching BaseRule structure
 * Works for both StigRule and SrgRule
 */
export interface IBenchmarkRule {
  id: number
  rule_id: string
  version: string
  title: string
  rule_severity: string
  rule_weight?: string
  status?: string
  ident?: string
  ident_system?: string
  legacy_ids?: string
  fixtext?: string
  fixtext_fixref?: string
  fix_id?: string
  nist_control_family?: string
  // Nested attributes
  checks_attributes?: IBenchmarkCheck[]
  disa_rule_descriptions_attributes?: IBenchmarkRuleDescription[]
  rule_descriptions_attributes?: IBenchmarkRuleDescription[]
  // STIG-specific (via group mapping)
  srg_id?: string
  vuln_id?: string
  // Foreign keys (one will be set)
  stig_id?: number
  security_requirements_guide_id?: number
}

/**
 * Unified benchmark interface
 * Works for both Stig and SecurityRequirementsGuide
 */
export interface IBenchmark {
  id: number
  benchmark_id: string // stig_id or srg_id
  title: string
  name: string
  version: string
  date?: string // benchmark_date or release_date
  description?: string
  created_at?: string
  updated_at?: string
  rules?: IBenchmarkRule[]
}

/**
 * List item for index pages (minimal data)
 */
export interface IBenchmarkListItem {
  id: number
  benchmark_id: string
  title: string
  name?: string
  version: string
  date?: string
}

/**
 * Convert STIG to unified benchmark format
 */
export function stigToBenchmark(stig: IStig): IBenchmark {
  return {
    id: stig.id,
    benchmark_id: stig.stig_id,
    title: stig.title,
    name: stig.name,
    version: stig.version,
    date: stig.benchmark_date,
    description: stig.description,
    created_at: stig.created_at,
    updated_at: stig.updated_at,
    rules: stig.stig_rules?.map(stigRuleToBenchmarkRule),
  }
}

/**
 * Convert SRG to unified benchmark format
 */
export function srgToBenchmark(srg: ISecurityRequirementsGuide): IBenchmark {
  return {
    id: srg.id,
    benchmark_id: srg.srg_id,
    title: srg.title,
    name: srg.name,
    version: srg.version,
    date: srg.release_date,
    created_at: srg.created_at,
    updated_at: srg.updated_at,
    rules: srg.srg_rules?.map(srgRuleToBenchmarkRule),
  }
}

/**
 * Convert STIG rule to unified benchmark rule format
 */
export function stigRuleToBenchmarkRule(rule: IStigRule): IBenchmarkRule {
  return {
    id: rule.id,
    rule_id: rule.rule_id || '',
    version: rule.version,
    title: rule.title,
    rule_severity: rule.rule_severity || 'medium',
    rule_weight: rule.rule_weight,
    ident: rule.ident,
    ident_system: rule.ident_system,
    legacy_ids: rule.legacy_ids,
    fixtext: rule.fixtext,
    fixtext_fixref: rule.fixtext_fixref,
    fix_id: rule.fix_id,
    vuln_id: rule.vuln_id,
    srg_id: rule.srg_id,
    stig_id: rule.stig_id,
    // Pass through nested attributes from API
    checks_attributes: rule.checks_attributes,
    disa_rule_descriptions_attributes: rule.disa_rule_descriptions_attributes,
  }
}

/**
 * Convert SRG rule to unified benchmark rule format
 */
export function srgRuleToBenchmarkRule(rule: ISrgRule): IBenchmarkRule {
  return {
    id: rule.id,
    rule_id: rule.rule_id,
    version: rule.version,
    title: rule.title,
    rule_severity: rule.rule_severity,
    rule_weight: rule.rule_weight,
    ident: rule.ident,
    ident_system: rule.ident_system,
    legacy_ids: rule.legacy_ids,
    fixtext: rule.fixtext,
    fixtext_fixref: rule.fixtext_fixref,
    fix_id: rule.fix_id,
    security_requirements_guide_id: rule.security_requirements_guide_id,
    // Pass through nested attributes from API
    checks_attributes: rule.checks_attributes,
    disa_rule_descriptions_attributes: rule.disa_rule_descriptions_attributes,
  }
}
