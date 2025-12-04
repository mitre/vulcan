/**
 * Rule-related TypeScript interfaces
 */

/**
 * Rule status values
 */
export type RuleStatus
  = | 'Not Yet Determined'
    | 'Applicable - Configurable'
    | 'Applicable - Inherently Meets'
    | 'Applicable - Does Not Meet'
    | 'Not Applicable'

/**
 * Rule severity values
 */
export type RuleSeverity = 'low' | 'medium' | 'high'

/**
 * Review action types
 */
export type ReviewAction
  = | 'request_review'
    | 'revoke_review_request'
    | 'request_changes'
    | 'approve'
    | 'lock_control'
    | 'unlock_control'

/**
 * Audited change record
 */
export interface IAuditedChange {
  field: string
  prev_value: unknown
  new_value: unknown
}

/**
 * History/audit record for a rule
 * From VulcanAudit#format
 */
export interface IHistory {
  id: number
  action: 'create' | 'update' | 'destroy'
  auditable_type: string
  auditable_id: number
  name: string // username who made the change
  audited_name?: string // entity being changed
  comment?: string
  created_at: string
  audited_changes: IAuditedChange[]
}

/**
 * DISA Rule Description
 */
export interface IDisaRuleDescription {
  id: number
  rule_id: number
  vuln_discussion?: string
  false_negatives?: string
  false_positives?: string
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
 * Rule Description (non-DISA format)
 */
export interface IRuleDescription {
  id: number
  rule_id: number
  label?: string
  description?: string
}

/**
 * Check content
 */
export interface ICheck {
  id: number
  rule_id: number
  system?: string
  content_ref_name?: string
  content_ref_href?: string
  content?: string
}

/**
 * Review record
 */
export interface IReview {
  id: number
  action: ReviewAction
  comment: string
  created_at: string
  name: string // User name (delegated)
}

/**
 * Additional question/answer
 */
export interface IAdditionalAnswer {
  id: number
  additional_question_id: number
  answer?: string
}

/**
 * SRG Rule attributes (parent rule info)
 */
export interface ISrgRuleAttributes {
  rule_id: string
  version: string
  title: string
  ident?: string
  ident_system?: string
  fixtext?: string
  fixtext_fixref?: string
  fix_id?: string
  rule_severity: RuleSeverity
  rule_weight?: string
  disa_rule_descriptions: IDisaRuleDescription[]
  rule_descriptions: IRuleDescription[]
  checks: ICheck[]
}

/**
 * Rule satisfaction reference (simplified)
 */
export interface IRuleSatisfaction {
  id: number
  rule_id: string
  title?: string
  fixtext?: string
}

/**
 * Slim Rule interface for list views
 * Contains only fields needed for table display (from RuleIndexBlueprint)
 * Full data is fetched on-demand when user opens a rule
 */
/** Slim reference to a satisfied rule (for table row-details) */
export interface ISatisfiedRuleRef {
  id: number
  rule_id: string
  title: string
}

export interface ISlimRule {
  id: number
  rule_id: string
  version: string
  title: string
  status: RuleStatus
  rule_severity: RuleSeverity
  locked: boolean
  review_requestor_id?: number | null
  changes_requested?: boolean
  is_merged: boolean
  satisfies_count?: number
  satisfies_rules?: ISatisfiedRuleRef[]
  satisfied_by?: ISatisfiedRuleRef[]
  updated_at?: string
}

/**
 * Core Rule interface matching Rails Rule model
 */
export interface IRule {
  id: number
  rule_id: string
  version: string
  title: string
  status: RuleStatus
  status_justification?: string
  artifact_description?: string
  vendor_comments?: string
  fixtext?: string
  fixtext_fixref?: string
  fix_id?: string
  ident?: string
  ident_system?: string
  legacy_ids?: string
  rule_severity: RuleSeverity
  rule_weight?: string
  locked: boolean
  changes_requested: boolean
  review_requestor_id?: number | null
  component_id: number
  srg_rule_id: number
  inspec_control_body?: string
  inspec_control_file?: string
  deleted_at?: string | null
  created_at: string
  updated_at: string
  // Computed/joined fields
  displayed_name?: string
  // Relations from as_json
  reviews?: IReview[]
  srg_rule_attributes?: ISrgRuleAttributes
  satisfies?: IRuleSatisfaction[]
  satisfied_by?: IRuleSatisfaction[]
  additional_answers_attributes?: IAdditionalAnswer[]
  disa_rule_descriptions?: IDisaRuleDescription[]
  rule_descriptions?: IRuleDescription[]
  checks?: ICheck[]
  srg_info?: { version: string }
  // History/changelog data
  histories?: IHistory[]
}

/**
 * Rule update data
 */
export interface IRuleUpdate {
  title?: string
  status?: RuleStatus
  status_justification?: string
  artifact_description?: string
  vendor_comments?: string
  fixtext?: string
  rule_severity?: RuleSeverity
  inspec_control_body?: string
  audit_comment?: string
  // Nested attributes
  disa_rule_descriptions_attributes?: Partial<IDisaRuleDescription>[]
  checks_attributes?: Partial<ICheck>[]
  additional_answers_attributes?: Partial<IAdditionalAnswer>[]
}

/**
 * Review creation data
 */
export interface IReviewCreate {
  action: ReviewAction
  comment: string
}

/**
 * Pagination metadata from API
 */
export interface IPagination {
  page: number
  per_page: number
  total_count: number
  total_pages: number
  has_next: boolean
  has_prev: boolean
}

/**
 * Paginated rules response from API
 */
export interface IPaginatedRulesResponse {
  rules: ISlimRule[]
  pagination: IPagination
}

/**
 * Rules store state interface
 */
export interface IRulesState {
  rules: ISlimRule[] // Slim data for list view
  fullRulesCache: Map<number, IRule> // Full data cache (on-demand)
  currentRule: IRule | null // Currently selected (full data)
  pagination: IPagination | null // Pagination state
  loading: boolean
  error: string | null
}
