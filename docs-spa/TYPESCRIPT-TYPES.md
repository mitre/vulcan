# Vulcan SPA - TypeScript Type Definitions

This document details all TypeScript interfaces used in the Vulcan Vue 3 SPA.

## Location

All types are in `app/javascript/types/` and exported from `index.ts`:

```typescript
import type { IUser, IProject, IRule } from '@/types'
```

---

## User Types (`user.ts`)

### IUser
Core user interface matching Rails User model.

```typescript
interface IUser {
  id: number
  email: string
  name: string
  admin: boolean
  provider?: string | null      // 'ldap', 'oidc', etc.
  uid?: string | null           // Provider user ID
  slack_user_id?: string | null
}
```

### IUserLogin
Login credentials.

```typescript
interface IUserLogin {
  email: string
  password: string
}
```

### IUserRegister
Registration data.

```typescript
interface IUserRegister {
  name: string
  email: string
  password: string
  password_confirmation: string
  slack_user_id?: string
}
```

### IUserUpdate
Admin user update data.

```typescript
interface IUserUpdate {
  name?: string
  email?: string
  admin?: boolean
  slack_user_id?: string
}
```

### IAuthState
Auth store state.

```typescript
interface IAuthState {
  user: IUser | null
  loading: boolean
}
```

### IUsersState
Users admin store state.

```typescript
interface IUsersState {
  users: IUser[]
  histories: IUserHistory[]
  loading: boolean
  error: string | null
}
```

### IUserHistory
Audit record for user changes.

```typescript
interface IUserHistory {
  id: number
  auditable_id: number
  auditable_type: string
  user_id: number | null
  action: string
  audited_changes: Record<string, unknown>
  version: number
  created_at: string
  remote_address?: string
  request_uuid?: string
  comment?: string
}
```

---

## Project Types (`project.ts`)

### IProject
Core project interface.

```typescript
interface IProject {
  id: number
  name: string
  description?: string
  visibility: 'discoverable' | 'hidden'
  created_at: string
  updated_at: string
  memberships?: IProjectMembership[]
  admin?: boolean              // Current user is admin
  is_member?: boolean          // Current user is member
  access_request_id?: number | null
}
```

### IProjectMembership
Project membership record.

```typescript
interface IProjectMembership {
  id: number
  user_id: number
  membership_type: string
  membership_id: number
  role: string
}
```

### IProjectCreate
Project creation data.

```typescript
interface IProjectCreate {
  name: string
  description?: string
  visibility?: 'discoverable' | 'hidden'
  slack_channel_id?: string
}
```

### IProjectUpdate
Project update data.

```typescript
interface IProjectUpdate {
  name?: string
  description?: string
  visibility?: 'discoverable' | 'hidden'
  project_metadata_attributes?: {
    data: Record<string, string>
  }
}
```

### IProjectsState
Projects store state.

```typescript
interface IProjectsState {
  projects: IProject[]
  currentProject: IProject | null
  loading: boolean
  error: string | null
}
```

---

## Component Types (`component.ts`)

### IComponent
Core component interface.

```typescript
interface IComponent {
  id: number
  name: string
  prefix: string
  version: number
  release?: number
  title?: string
  description?: string
  released: boolean
  project_id: number
  component_id?: number | null  // Parent for overlays
  security_requirements_guide_id: number
  admin_name?: string
  admin_email?: string
  rules_count: number
  created_at: string
  updated_at: string
  // Computed from as_json
  based_on_title?: string
  based_on_version?: string
  releasable?: boolean
  rules_summary?: IRulesSummary
  parent_rules_count?: number
  primary_controls_count?: number
  memberships?: IProjectMembership[]
  component_metadata?: IComponentMetadata
}
```

### IRulesSummary
Component rules statistics.

```typescript
interface IRulesSummary {
  total: number
  primary_count: number
  nested_count: number
  locked: number
  under_review: number
  not_under_review: number
  changes_requested: number
  not_yet_determined: number
  applicable_configurable: number
  applicable_inherently_meets: number
  applicable_does_not_meet: number
  not_applicable: number
}
```

### IComponentCreate
Component creation data.

```typescript
interface IComponentCreate {
  name: string
  prefix: string
  version?: number
  release?: number
  title?: string
  description?: string
  security_requirements_guide_id: number
  project_id: number
  component_id?: number  // For overlays
}
```

### IComponentDuplicate
Component duplication options.

```typescript
interface IComponentDuplicate {
  new_name?: string
  new_prefix?: string
  new_version?: number
  new_release?: number
  new_title?: string
  new_description?: string
  new_project_id?: number
  new_srg_id?: number
}
```

---

## Rule Types (`rule.ts`)

### Type Aliases

```typescript
type RuleStatus =
  | 'Not Yet Determined'
  | 'Applicable - Configurable'
  | 'Applicable - Inherently Meets'
  | 'Applicable - Does Not Meet'
  | 'Not Applicable'

type RuleSeverity = 'low' | 'medium' | 'high'

type ReviewAction =
  | 'request_review'
  | 'revoke_review_request'
  | 'request_changes'
  | 'approve'
  | 'lock_control'
  | 'unlock_control'
```

### IRule
Core rule/control interface.

```typescript
interface IRule {
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
  ident?: string              // CCI identifiers
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
  // Relations
  reviews?: IReview[]
  srg_rule_attributes?: ISrgRuleAttributes
  satisfies?: IRuleSatisfaction[]
  satisfied_by?: IRuleSatisfaction[]
  additional_answers_attributes?: IAdditionalAnswer[]
  disa_rule_descriptions?: IDisaRuleDescription[]
  checks?: ICheck[]
}
```

### IDisaRuleDescription
DISA rule description fields.

```typescript
interface IDisaRuleDescription {
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
```

### ICheck
Check content for a rule.

```typescript
interface ICheck {
  id: number
  rule_id: number
  system?: string
  content_ref_name?: string
  content_ref_href?: string
  content?: string
}
```

### IReview
Review record.

```typescript
interface IReview {
  id: number
  action: ReviewAction
  comment: string
  created_at: string
  name: string  // User name (delegated)
}
```

---

## SRG Types (`srg.ts`)

### ISecurityRequirementsGuide
Core SRG interface.

```typescript
interface ISecurityRequirementsGuide {
  id: number
  srg_id: string
  title: string
  name: string
  version: string
  release_date?: string
  created_at: string
  updated_at: string
  full_title?: string
  srg_rules?: ISrgRule[]
}
```

### ISrgListItem
Minimal SRG for dropdowns.

```typescript
interface ISrgListItem {
  id: number
  title: string
  version: string
}
```

---

## STIG Types (`stig.ts`)

### IStig
Core STIG interface.

```typescript
interface IStig {
  id: number
  stig_id: string
  title: string
  name: string
  version: string
  description?: string
  benchmark_date?: string
  created_at: string
  updated_at: string
  stig_rules?: IStigRule[]
}
```

---

## Membership Types (`membership.ts`)

### Type Aliases

```typescript
type MemberRole = 'viewer' | 'author' | 'reviewer' | 'admin'
type MembershipType = 'Project' | 'Component'
```

### IMembership
Membership record.

```typescript
interface IMembership {
  id: number
  user_id: number
  membership_type: MembershipType
  membership_id: number
  role: MemberRole
  created_at: string
  updated_at: string
  name: string   // Delegated from User
  email: string  // Delegated from User
}
```

---

## Access Request Types (`access-request.ts`)

### IProjectAccessRequest
Project access request.

```typescript
interface IProjectAccessRequest {
  id: number
  user_id: number
  project_id: number
  created_at: string
  updated_at: string
  user?: IUser
  project?: IProject
}
```

---

## Usage Examples

### Importing Types

```typescript
// Import specific types
import type { IUser, IProject, IRule } from '@/types'

// Use in component props
const props = defineProps<{
  project: IProject
  rules: IRule[]
}>()

// Use in refs
const user = ref<IUser | null>(null)
const projects = ref<IProject[]>([])
```

### Type Guards

```typescript
function isAdmin(user: IUser | null): boolean {
  return user?.admin === true
}

function isConfigurable(rule: IRule): boolean {
  return rule.status === 'Applicable - Configurable'
}
```

### API Response Typing

```typescript
import { http } from '@/services/http.service'
import type { IProject } from '@/types'

const response = await http.get<IProject[]>('/projects')
// response.data is IProject[]
```
