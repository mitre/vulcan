# Vulcan Database Complete Redesign

**Created:** 2025-11-30
**Status:** Design Document
**Scope:** Complete 3NF redesign of entire Vulcan database

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Problems Identified](#problems-identified)
3. [Proposed 3NF Schema](#proposed-3nf-schema)
4. [Diff & Changelog Features](#diff--changelog-features)
5. [SRG Upgrade Workflow](#srg-upgrade-workflow)
6. [Migration Strategy](#migration-strategy)
7. [Performance Optimizations](#performance-optimizations)
8. [Implementation Phases](#implementation-phases)

---

## Current State Analysis

### All Current Tables (22 tables)

| Table | Rows (typical) | Purpose | Issues |
|-------|---------------|---------|--------|
| `users` | 100s | User accounts | ✅ OK |
| `projects` | 10-100 | Project containers | ✅ OK |
| `components` | 10-500 | STIG in progress | ✅ OK |
| `security_requirements_guides` | 10-50 | SRG templates | ✅ OK |
| `stigs` | 100-500 | Published STIGs | ✅ OK |
| `base_rules` (STI) | 10,000-100,000+ | Rules/Controls | ❌ MAJOR ISSUES |
| `checks` | Same as rules | Check content | ❌ DUPLICATED |
| `disa_rule_descriptions` | Same as rules | Description fields | ❌ DUPLICATED |
| `rule_descriptions` | Rarely used | Non-DISA descriptions | ⚠️ Sparse |
| `references` | Rarely used | DC references | ⚠️ Sparse |
| `rule_satisfactions` | 100s-1000s | Nesting relationships | ❌ WRONG DESIGN |
| `reviews` | 100s-1000s | Review workflow | ✅ OK |
| `memberships` | 100s | User permissions | ✅ OK |
| `audits` | 10,000s+ | Change history | ⚠️ GROWS FAST |
| `additional_questions` | 10s | Custom questions | ✅ OK |
| `additional_answers` | 100s | Question answers | ✅ OK |
| `project_metadata` | = projects | JSON metadata | ⚠️ WHY SEPARATE? |
| `component_metadata` | = components | JSON metadata | ⚠️ WHY SEPARATE? |
| `project_access_requests` | 10s | Access requests | ✅ OK |
| `search_abbreviations` | 10s | Search expansion | ✅ OK (new) |

### STI Model (`base_rules` table)

```
base_rules (Single Table Inheritance)
├── type = "SrgRule"      → Template from SRG (read-only, shared)
├── type = "StigRule"     → Published STIG rule (reference)
└── type = "Rule"         → User's authored implementation
```

**Current Column Count:** 30+ columns in base_rules
**Storage:** Massive duplication - every Component copies ALL SRG content

---

## Problems Identified

### CRITICAL: 3NF Violations

#### Problem 1: Content Duplication (Biggest Issue)

```
When user creates Component from SRG (263 requirements):
  → Creates 263 Rule records (copies ALL content from SrgRules)
  → Creates 263 Check records (copies ALL check content)
  → Creates 263 DisaRuleDescription records (copies ALL 11 fields)

Result: ~70% of data is duplicated from templates
```

**Impact:**
- Database bloat: O(components × requirements) instead of O(requirements)
- Update propagation: SRG typo fix doesn't update copied Rules
- Sync issues: Components can drift from SRG baseline

#### Problem 2: Wrong Satisfaction Model

```
Current: Rule → Rule (same component)
  - Creates "placeholder" Rules just to have linking targets
  - Confusing: "satisfied_by" links to another Rule in same component

Should be: Rule → SrgRule (template)
  - Direct link to SRG requirement
  - No placeholder Rules needed
  - Clear semantics: "this control satisfies SRG requirement X"
```

#### Problem 3: No Version/Diff Tracking

```
Current: SRG versions are separate records
  - No structured way to diff V2R1 → V2R2
  - User manually compares XCCDF files
  - No "what changed in my baseline?" feature

Need: Computed changesets on import
  - Store diffs between versions
  - Show impact on Components when SRG updates
```

#### Problem 4: Metadata Tables Unnecessary

```
project_metadata: { data: jsonb }  → Should be columns on projects
component_metadata: { data: jsonb } → Should be columns on components

No clear schema = no validation, no indexing, harder queries
```

### MODERATE: Performance Issues

#### Problem 5: N+1 Queries in Rules

```ruby
# Current: Fetching component with rules
component.rules.each do |rule|
  rule.checks           # N+1
  rule.disa_rule_descriptions  # N+1
  rule.satisfies        # N+1
  rule.satisfied_by     # N+1
end
```

**Partial fix exists:** `batch_rules_summary` in Component model
**Still needed:** Better eager loading, materialized views

#### Problem 6: Audits Table Growth

```
Every rule update creates audit record
Every check update creates audit record
Every description update creates audit record

100 components × 263 rules × 10 updates each = 263,000 audit records
```

**Need:** Audit retention policy, archival strategy

### MINOR: Schema Cleanup

#### Problem 7: Unused/Sparse Columns

- `rule_descriptions` - Rarely populated (non-DISA format)
- `references` - Rarely populated (DC metadata)
- Many columns on base_rules that only apply to specific types

#### Problem 8: Inconsistent Naming

- `security_requirements_guide_id` vs `srg_id`
- `component_id` used for both "overlay parent" and "belongs to"
- `rule_id` (string) vs `id` (bigint primary key)

---

## Proposed 3NF Schema

### Core Design Principles

1. **Store overrides, not copies** - Rules only store user modifications
2. **Template inheritance** - Display methods fall back to SRG/STIG
3. **Direct SRG linking** - Satisfactions link Rule → SrgRule
4. **Materialized aggregates** - Pre-compute expensive counts
5. **Structured versioning** - Track diffs between benchmark versions

### New Schema Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           VULCAN 3NF SCHEMA v3.0                             │
└─────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
AUTHENTICATION & AUTHORIZATION
═══════════════════════════════════════════════════════════════════════════════

┌───────────────────────┐         ┌───────────────────────┐
│ users                 │         │ memberships           │
│───────────────────────│         │───────────────────────│
│ id (PK)               │◄────────│ user_id (FK)          │
│ email                 │         │ membership_type       │──▶ 'Project' | 'Component'
│ name                  │         │ membership_id         │
│ admin                 │         │ role                  │──▶ 'admin' | 'reviewer' | 'author' | 'viewer'
│ provider              │         │ created_at            │
│ uid                   │         └───────────────────────┘
│ encrypted_password    │
│ ...devise fields...   │
└───────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
PROJECT HIERARCHY
═══════════════════════════════════════════════════════════════════════════════

┌───────────────────────┐         ┌───────────────────────┐
│ projects              │         │ components            │
│───────────────────────│         │ (STIG in progress)    │
│ id (PK)               │◄────────│───────────────────────│
│ name                  │         │ id (PK)               │
│ description           │         │ project_id (FK)       │
│ visibility            │         │ srg_id (FK)           │──────────────────────┐
│ admin_name            │         │ overlay_component_id  │ (self-ref for overlay)│
│ admin_email           │         │ name                  │                       │
│ memberships_count     │         │ prefix                │                       │
│ metadata (jsonb)  [NEW]         │ version               │                       │
│ created_at            │         │ release               │                       │
│ updated_at            │         │ title                 │                       │
└───────────────────────┘         │ description           │                       │
                                  │ released              │                       │
                                  │ rules_count           │                       │
                                  │ admin_name            │                       │
                                  │ admin_email           │                       │
                                  │ advanced_fields       │                       │
                                  │ metadata (jsonb)  [NEW]                       │
                                  │ created_at            │                       │
                                  │ updated_at            │                       │
                                  └───────────────────────┘                       │
                                                                                  │
═══════════════════════════════════════════════════════════════════════════════ │
BENCHMARKS (Templates - Read-Only After Import)                                  │
═══════════════════════════════════════════════════════════════════════════════ │
                                                                                  │
┌─────────────────────────────────┐                                              │
│ security_requirements_guides    │◄─────────────────────────────────────────────┘
│ (SRG)                           │
│─────────────────────────────────│
│ id (PK)                         │
│ srg_id                          │
│ title                           │
│ name                            │
│ version                         │
│ release_date                    │
│ xml                             │
│ created_at                      │
│ updated_at                      │
└───────────┬─────────────────────┘
            │ has_many
            ▼
┌─────────────────────────────────┐
│ srg_rules                       │   [SEPARATE TABLE - No longer STI]
│ (SRG Template Requirements)     │
│─────────────────────────────────│
│ id (PK)                         │
│ srg_id (FK)                     │◄── security_requirements_guide
│ rule_identifier                 │    (renamed from rule_id string)
│ version                         │    e.g., "SRG-OS-000023"
│ title                           │
│ fixtext                         │
│ ident                           │    CCI-001234
│ ident_system                    │
│ rule_severity                   │
│ rule_weight                     │
│ fix_id                          │
│ fixtext_fixref                  │
│ legacy_ids                      │
│ created_at                      │
└───────────┬─────────────────────┘
            │ has_many
            ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ srg_checks                  [NEW]│   │ srg_descriptions            [NEW]│
│─────────────────────────────────│   │─────────────────────────────────│
│ id (PK)                         │   │ id (PK)                         │
│ srg_rule_id (FK)                │   │ srg_rule_id (FK)                │
│ system                          │   │ vuln_discussion                 │
│ content_ref_name                │   │ false_positives                 │
│ content_ref_href                │   │ false_negatives                 │
│ content                         │   │ documentable                    │
└─────────────────────────────────┘   │ mitigations                     │
                                      │ severity_override_guidance      │
                                      │ potential_impacts               │
                                      │ third_party_tools               │
                                      │ mitigation_control              │
                                      │ responsibility                  │
                                      │ ia_controls                     │
                                      └─────────────────────────────────┘

┌─────────────────────────────────┐
│ stigs                           │   (Published STIGs - Reference)
│─────────────────────────────────│
│ id (PK)                         │
│ stig_id                         │
│ title                           │
│ name                            │
│ version                         │
│ description                     │
│ benchmark_date                  │
│ xml                             │
│ created_at                      │
└───────────┬─────────────────────┘
            │ has_many
            ▼
┌─────────────────────────────────┐
│ stig_rules                      │   [SEPARATE TABLE - No longer STI]
│ (Published STIG Controls)       │
│─────────────────────────────────│
│ id (PK)                         │
│ stig_id (FK)                    │
│ rule_identifier                 │
│ version                         │
│ vuln_id                         │   e.g., "V-230221"
│ srg_version                     │   e.g., "SRG-OS-000023" (reference)
│ title                           │
│ fixtext                         │
│ ... (all published content)     │
└───────────┬─────────────────────┘
            │ has_many
            ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ stig_checks                 [NEW]│   │ stig_descriptions           [NEW]│
│─────────────────────────────────│   │─────────────────────────────────│
│ (same structure as srg_checks)  │   │ (same structure as srg_desc)    │
└─────────────────────────────────┘   └─────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
USER-AUTHORED CONTENT (Overrides Only)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ rules                                                                        │
│ (User's Implementation - Stores ONLY Overrides)                             │
│─────────────────────────────────────────────────────────────────────────────│
│ id (PK)                                                                      │
│ component_id (FK)        ──▶ components                                     │
│ srg_rule_id (FK)         ──▶ srg_rules (the requirement this implements)    │
│ display_number           (e.g., "000001" - for PREFIX-000001)               │
│                                                                              │
│ ─── USER-SPECIFIC FIELDS (Always stored on Rule) ───                        │
│ status                   ('Not Yet Determined', 'Applicable - Configurable', etc.)
│ status_justification                                                         │
│ artifact_description                                                         │
│ vendor_comments                                                              │
│ inspec_control_body                                                          │
│ inspec_control_file                                                          │
│ locked                                                                       │
│ review_requestor_id      ──▶ users                                          │
│ changes_requested                                                            │
│ deleted_at               (soft delete)                                       │
│                                                                              │
│ ─── OVERRIDE FIELDS (NULL = use SRG template) ───                           │
│ title_override           (NULL or user's custom title)                       │
│ fixtext_override         (NULL or user's custom fix)                         │
│ ident_override           (NULL or user's custom CCIs)                        │
│ severity_override        (NULL or user's custom severity)                    │
│                                                                              │
│ created_at                                                                   │
│ updated_at                                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                           │
                           │ has_one (optional - only if user overrides)
                           ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ rule_check_overrides        [NEW]│   │ rule_description_overrides  [NEW]│
│─────────────────────────────────│   │─────────────────────────────────│
│ id (PK)                         │   │ id (PK)                         │
│ rule_id (FK)                    │   │ rule_id (FK)                    │
│ content                         │   │ vuln_discussion                 │
│ system                          │   │ mitigations                     │
│ created_at                      │   │ ... (only modified fields)      │
│ updated_at                      │   │ created_at                      │
└─────────────────────────────────┘   │ updated_at                      │
                                      └─────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
SATISFACTION RELATIONSHIPS (Correct Model)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ rule_satisfactions                                                           │
│─────────────────────────────────────────────────────────────────────────────│
│ id (PK)                  [NEW - add primary key]                            │
│ rule_id (FK)             ──▶ rules (the control doing the satisfying)       │
│ srg_rule_id (FK)         ──▶ srg_rules (the SRG requirement being satisfied)│
│ created_at               [NEW]                                              │
│                                                                              │
│ UNIQUE INDEX: (rule_id, srg_rule_id)                                        │
│                                                                              │
│ Example: SSH config control satisfies 3 SRG requirements                    │
│ ┌──────────┬─────────────┐                                                  │
│ │ rule_id  │ srg_rule_id │                                                  │
│ ├──────────┼─────────────┤                                                  │
│ │    5     │     23      │  Rule #5 satisfies SRG-OS-000023                 │
│ │    5     │     24      │  Rule #5 satisfies SRG-OS-000024                 │
│ │    5     │     25      │  Rule #5 satisfies SRG-OS-000025                 │
│ └──────────┴─────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
REVIEW WORKFLOW (Unchanged)
═══════════════════════════════════════════════════════════════════════════════

┌───────────────────────┐
│ reviews               │
│───────────────────────│
│ id (PK)               │
│ rule_id (FK)          │──▶ rules
│ user_id (FK)          │──▶ users
│ action                │
│ comment               │
│ created_at            │
└───────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
BENCHMARK VERSIONING (New Feature)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ benchmark_changesets                                                     [NEW]│
│─────────────────────────────────────────────────────────────────────────────│
│ id (PK)                                                                      │
│ benchmark_type          ('srg' | 'stig')                                    │
│ benchmark_id            (srg.id or stig.id)                                 │
│ from_version            ('V2R1')                                            │
│ to_version              ('V2R2')                                            │
│ computed_at                                                                  │
│ changes (jsonb) [                                                           │
│   { type: "added", rule_version: "SRG-OS-000500", title: "..." },           │
│   { type: "modified", rule_version: "SRG-OS-000023",                        │
│     fields: { fixtext: { old: "...", new: "..." } } },                      │
│   { type: "removed", rule_version: "SRG-OS-000099", title: "..." }          │
│ ]                                                                           │
│ summary (jsonb)         { added: 3, modified: 12, removed: 1 }              │
│                                                                              │
│ INDEX: (benchmark_type, benchmark_id, from_version, to_version) UNIQUE      │
└─────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
MATERIALIZED VIEWS (Performance)
═══════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────────┐
│ component_statistics                                              [MATERIALIZED]│
│─────────────────────────────────────────────────────────────────────────────│
│ component_id                                                                 │
│ total_rules                                                                  │
│ locked_count                                                                 │
│ under_review_count                                                           │
│ not_yet_determined_count                                                     │
│ applicable_configurable_count                                                │
│ applicable_inherently_meets_count                                            │
│ applicable_does_not_meet_count                                               │
│ not_applicable_count                                                         │
│ primary_controls_count        (rules that satisfy other requirements)        │
│ nested_requirements_count     (requirements satisfied by other rules)        │
│ refreshed_at                                                                 │
│                                                                              │
│ REFRESH: On rule status change, review action, or manually                  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ project_statistics                                                [MATERIALIZED]│
│─────────────────────────────────────────────────────────────────────────────│
│ project_id                                                                   │
│ total_components                                                             │
│ total_rules                                                                  │
│ ... (aggregate of component stats)                                          │
│ refreshed_at                                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Display Logic (Fallback Pattern)

```ruby
class Rule < ApplicationRecord
  belongs_to :srg_rule
  has_one :check_override, class_name: 'RuleCheckOverride'
  has_one :description_override, class_name: 'RuleDescriptionOverride'

  # Title with fallback to SRG template
  def display_title
    title_override.presence || srg_rule.title
  end

  # Fixtext with fallback
  def display_fixtext
    fixtext_override.presence || srg_rule.fixtext
  end

  # Check content with fallback
  def display_check_content
    check_override&.content.presence || srg_rule.srg_check&.content
  end

  # Vuln discussion with fallback
  def display_vuln_discussion
    description_override&.vuln_discussion.presence ||
      srg_rule.srg_description&.vuln_discussion
  end

  # Generic display method
  def display_field(field)
    override_value = send("#{field}_override") rescue nil
    override_value.presence || srg_rule.send(field)
  end
end
```

---

## Diff & Changelog Features

### Use Cases

1. **"What changed in this SRG version?"** - Compare SRG V2R1 → V2R2
2. **"What changed in this STIG release?"** - Compare RHEL 9 V1R1 → V1R2
3. **"What did I change from the SRG template?"** - Show Component overrides
4. **"What changed in my Component since last week?"** - Audit history view
5. **"How does my Component compare to the published STIG?"** - STIG diff

### Database Support

#### Benchmark Changesets (SRG/STIG Version Diffs)

```sql
-- Computed on import of new SRG/STIG version
CREATE TABLE benchmark_changesets (
  id BIGSERIAL PRIMARY KEY,

  -- Which benchmark
  benchmark_type VARCHAR NOT NULL,  -- 'srg' | 'stig'
  from_benchmark_id BIGINT NOT NULL,
  to_benchmark_id BIGINT NOT NULL,

  -- Version info
  from_version VARCHAR NOT NULL,    -- 'V2R1'
  to_version VARCHAR NOT NULL,      -- 'V2R2'

  -- The actual diff (computed on import)
  changes JSONB NOT NULL DEFAULT '[]',
  /*
  [
    {
      "type": "added",
      "rule_version": "SRG-OS-000500",
      "title": "New requirement for..."
    },
    {
      "type": "removed",
      "rule_version": "SRG-OS-000099",
      "title": "Deprecated requirement..."
    },
    {
      "type": "modified",
      "rule_version": "SRG-OS-000023",
      "fields": {
        "title": { "old": "...", "new": "..." },
        "fixtext": { "old": "...", "new": "..." },
        "severity": { "old": "medium", "new": "high" }
      }
    }
  ]
  */

  -- Summary counts
  summary JSONB NOT NULL DEFAULT '{}',
  /* { "added": 3, "removed": 1, "modified": 12, "unchanged": 247 } */

  computed_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_benchmark_changesets_unique
ON benchmark_changesets(benchmark_type, from_benchmark_id, to_benchmark_id);
```

#### Component Override Tracking

```sql
-- Track what user has customized from SRG template
-- This is implicit in the override tables, but we can query it:

-- "What did user override from template?"
SELECT
  r.id,
  r.display_number,
  sr.version as srg_requirement,
  CASE WHEN r.title_override IS NOT NULL THEN 'title' END,
  CASE WHEN r.fixtext_override IS NOT NULL THEN 'fixtext' END,
  CASE WHEN rco.id IS NOT NULL THEN 'check' END,
  CASE WHEN rdo.id IS NOT NULL THEN 'description' END
FROM rules r
JOIN srg_rules sr ON r.srg_rule_id = sr.id
LEFT JOIN rule_check_overrides rco ON rco.rule_id = r.id
LEFT JOIN rule_description_overrides rdo ON rdo.rule_id = r.id
WHERE r.component_id = ?
  AND (r.title_override IS NOT NULL
       OR r.fixtext_override IS NOT NULL
       OR rco.id IS NOT NULL
       OR rdo.id IS NOT NULL);
```

#### Component History (Leveraging Audits)

```ruby
# app/models/component.rb

def changelog(since: 1.week.ago)
  # Get all audits for this component's rules
  Audited::Audit
    .where(auditable_type: 'Rule')
    .where(auditable_id: rules.pluck(:id))
    .where('created_at > ?', since)
    .includes(:user)
    .order(created_at: :desc)
    .group_by { |a| a.created_at.to_date }
end

def diff_from_srg
  # Returns all overrides grouped by rule
  rules.includes(:srg_rule, :check_override, :description_override)
       .select { |r| r.has_overrides? }
       .map { |r| r.override_summary }
end
```

### API Endpoints

```ruby
# config/routes.rb

namespace :api do
  # SRG/STIG version diff
  get 'srgs/:id/diff/:other_id', to: 'srgs#diff'
  get 'stigs/:id/diff/:other_id', to: 'stigs#diff'

  # Component diff from template
  get 'components/:id/overrides', to: 'components#overrides'
  get 'components/:id/changelog', to: 'components#changelog'

  # Component diff from STIG
  get 'components/:id/diff_stig/:stig_id', to: 'components#diff_stig'
end
```

### Frontend Views

```
┌─────────────────────────────────────────────────────────────────┐
│ SRG Version Diff: General Purpose OS V2R1 → V2R2                │
├─────────────────────────────────────────────────────────────────┤
│ Summary: +3 Added | -1 Removed | ~12 Modified | 247 Unchanged   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ➕ ADDED                                                        │
│ ├── SRG-OS-000500: New container isolation requirement          │
│ ├── SRG-OS-000501: New cloud deployment requirement             │
│ └── SRG-OS-000502: New MFA requirement for privileged access    │
│                                                                 │
│ ➖ REMOVED                                                       │
│ └── SRG-OS-000099: Legacy audit requirement (merged into 023)   │
│                                                                 │
│ 📝 MODIFIED                                                     │
│ ├── SRG-OS-000023: [title] [fixtext] [severity: medium→high]   │
│ ├── SRG-OS-000024: [check]                                     │
│ └── ...                                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## SRG Upgrade Workflow

### The Problem (Current)

When SRG V2R1 is replaced by V2R2:
1. User imports new SRG (creates new SrgRules)
2. Existing Components still point to V2R1 SrgRules
3. User must manually "duplicate to new SRG"
4. All customizations lost or require manual re-application

### The Solution (New Design)

#### Database Support

```sql
-- Track SRG lineage (same SRG, different versions)
ALTER TABLE security_requirements_guides
ADD COLUMN srg_family_id VARCHAR;  -- e.g., "General_Purpose_OS_SRG"

-- Index for quick lookup of versions
CREATE INDEX idx_srg_family ON security_requirements_guides(srg_family_id, version);

-- Track rule lineage across SRG versions
CREATE TABLE srg_rule_lineage (
  id BIGSERIAL PRIMARY KEY,

  -- The requirement across versions
  rule_version VARCHAR NOT NULL,      -- 'SRG-OS-000023' (stable identifier)

  -- Version mapping
  from_srg_rule_id BIGINT REFERENCES srg_rules(id),
  to_srg_rule_id BIGINT REFERENCES srg_rules(id),

  -- What changed
  change_type VARCHAR NOT NULL,       -- 'unchanged' | 'modified' | 'added' | 'removed'
  field_changes JSONB DEFAULT '{}',   -- { "fixtext": true, "severity": true }

  created_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_srg_rule_lineage
ON srg_rule_lineage(from_srg_rule_id, to_srg_rule_id);
```

#### Upgrade Service

```ruby
# app/services/component_srg_upgrade_service.rb

class ComponentSrgUpgradeService
  def initialize(component, new_srg)
    @component = component
    @old_srg = component.security_requirements_guide
    @new_srg = new_srg
  end

  def preview
    # Return what WOULD happen without making changes
    {
      component: @component.name,
      from_srg: "#{@old_srg.title} #{@old_srg.version}",
      to_srg: "#{@new_srg.title} #{@new_srg.version}",

      # Rules that will be updated (requirement exists in both versions)
      rules_to_update: rules_with_matching_requirements.map { |r|
        {
          rule_id: r.id,
          display_number: r.display_number,
          srg_requirement: r.srg_rule.version,
          has_overrides: r.has_overrides?,
          template_changed: template_changed?(r),
          action: determine_action(r)
        }
      },

      # Rules that will be added (new requirements in new SRG)
      rules_to_add: new_requirements.map { |sr|
        {
          srg_requirement: sr.version,
          title: sr.title
        }
      },

      # Rules that will be marked obsolete (removed from new SRG)
      rules_to_obsolete: removed_requirements.map { |r|
        {
          rule_id: r.id,
          display_number: r.display_number,
          srg_requirement: r.srg_rule.version,
          has_customizations: r.has_overrides?
        }
      }
    }
  end

  def upgrade!(options = {})
    ActiveRecord::Base.transaction do
      # 1. Update component's SRG reference
      @component.update!(security_requirements_guide: @new_srg)

      # 2. Update existing rules to point to new SrgRules
      rules_with_matching_requirements.each do |rule|
        new_srg_rule = find_matching_new_srg_rule(rule)

        if options[:preserve_overrides]
          # Just update the srg_rule_id, keep all overrides
          rule.update!(srg_rule_id: new_srg_rule.id)
        else
          # Update srg_rule_id and optionally refresh template content
          rule.update!(srg_rule_id: new_srg_rule.id)

          # Clear overrides for non-configurable rules if template changed
          if !rule.configurable? && template_changed?(rule)
            rule.clear_overrides! if options[:refresh_non_configurable]
          end
        end
      end

      # 3. Add new rules for new requirements
      new_requirements.each do |new_srg_rule|
        @component.rules.create!(
          srg_rule: new_srg_rule,
          display_number: next_display_number,
          status: 'Not Yet Determined'
        )
      end

      # 4. Handle removed requirements
      removed_requirements.each do |rule|
        if options[:delete_removed]
          rule.destroy!
        else
          # Mark as obsolete but keep for reference
          rule.update!(
            status: 'Not Applicable',
            status_justification: "Requirement #{rule.srg_rule.version} removed in #{@new_srg.version}"
          )
        end
      end

      # 5. Record the upgrade in audit log
      @component.audits.create!(
        action: 'srg_upgrade',
        audited_changes: {
          from_srg: @old_srg.version,
          to_srg: @new_srg.version,
          rules_updated: rules_with_matching_requirements.count,
          rules_added: new_requirements.count,
          rules_removed: removed_requirements.count
        }
      )
    end
  end

  private

  def find_matching_new_srg_rule(rule)
    # Match by SRG requirement version (e.g., SRG-OS-000023)
    @new_srg.srg_rules.find_by(version: rule.srg_rule.version)
  end

  def rules_with_matching_requirements
    @component.rules.select { |r|
      @new_srg.srg_rules.exists?(version: r.srg_rule.version)
    }
  end

  def new_requirements
    existing_versions = @component.rules.joins(:srg_rule).pluck('srg_rules.version')
    @new_srg.srg_rules.where.not(version: existing_versions)
  end

  def removed_requirements
    new_versions = @new_srg.srg_rules.pluck(:version)
    @component.rules.joins(:srg_rule).where.not(srg_rules: { version: new_versions })
  end

  def template_changed?(rule)
    # Check if SRG template content changed between versions
    old_srg_rule = rule.srg_rule
    new_srg_rule = find_matching_new_srg_rule(rule)
    return false unless new_srg_rule

    old_srg_rule.title != new_srg_rule.title ||
      old_srg_rule.fixtext != new_srg_rule.fixtext ||
      old_srg_rule.srg_check&.content != new_srg_rule.srg_check&.content
  end
end
```

#### API Endpoints

```ruby
# config/routes.rb
namespace :api do
  resources :components do
    member do
      get 'upgrade_preview/:new_srg_id', to: 'components#upgrade_preview'
      post 'upgrade/:new_srg_id', to: 'components#upgrade'
    end
  end
end

# app/controllers/api/components_controller.rb
def upgrade_preview
  @new_srg = SecurityRequirementsGuide.find(params[:new_srg_id])
  service = ComponentSrgUpgradeService.new(@component, @new_srg)
  render json: service.preview
end

def upgrade
  @new_srg = SecurityRequirementsGuide.find(params[:new_srg_id])
  service = ComponentSrgUpgradeService.new(@component, @new_srg)

  service.upgrade!(
    preserve_overrides: params[:preserve_overrides] != false,
    refresh_non_configurable: params[:refresh_non_configurable] == true,
    delete_removed: params[:delete_removed] == true
  )

  render json: { success: true, component: @component.reload }
end
```

#### Frontend UI

```
┌─────────────────────────────────────────────────────────────────┐
│ Upgrade RHEL 9 Component: OS SRG V2R1 → V2R2                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ℹ️  Preview of changes:                                         │
│                                                                 │
│ ┌───────────────────────────────────────────────────────────┐  │
│ │ 📝 247 REQUIREMENTS WILL BE UPDATED                       │  │
│ │    ├── 235 unchanged (just re-linked to new SRG)         │  │
│ │    └── 12 template content changed                        │  │
│ │        └── ⚠️ 3 have your customizations (will preserve) │  │
│ └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│ ┌───────────────────────────────────────────────────────────┐  │
│ │ ➕ 3 NEW REQUIREMENTS WILL BE ADDED                       │  │
│ │    ├── SRG-OS-000500: Container isolation                │  │
│ │    ├── SRG-OS-000501: Cloud deployment                   │  │
│ │    └── SRG-OS-000502: MFA for privileged access          │  │
│ └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│ ┌───────────────────────────────────────────────────────────┐  │
│ │ ➖ 1 REQUIREMENT REMOVED FROM SRG                         │  │
│ │    └── SRG-OS-000099: Legacy audit (has customizations)  │  │
│ │        ○ Mark as Not Applicable (recommended)            │  │
│ │        ○ Delete rule                                     │  │
│ └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│ Options:                                                        │
│ ☑️ Preserve my customizations (title, check, fix overrides)    │
│ ☐ Refresh non-configurable rules with new template content     │
│                                                                 │
│ [Cancel]                              [Preview Details] [Upgrade]│
└─────────────────────────────────────────────────────────────────┘
```

### Key Benefits of New Design

1. **Overrides preserved automatically** - Because we only store overrides, upgrading SRG just changes the `srg_rule_id` pointer. User's customizations remain intact.

2. **Clear diff visibility** - Can show exactly what changed in the SRG template vs what user customized.

3. **Granular control** - User decides per-rule whether to refresh template content or keep their version.

4. **Audit trail** - Every upgrade is logged with before/after state.

5. **Reversible** - Can create a backup component before upgrade, or even roll back by re-pointing to old SRG.

---

## Migration Strategy

### Phase Overview

| Phase | Scope | Risk | Effort | Can Ship After? |
|-------|-------|------|--------|-----------------|
| 0 | Preparation & Backup | None | 2h | Yes |
| 1 | Add fallback display methods | Low | 4h | Yes |
| 2 | Split STI into separate tables | Medium | 8h | Yes |
| 3 | Add override tables | Medium | 6h | Yes |
| 4 | Migrate satisfactions | Medium | 4h | Yes |
| 5 | Add versioning/changesets | Low | 6h | Yes |
| 6 | Add materialized views | Low | 4h | Yes |
| 7 | Data cleanup & deduplication | Medium | 4h | Yes |
| 8 | Remove legacy columns | Low | 2h | Yes |

**Total: ~40 hours across 8+ sessions**

---

## Implementation Phases

### Phase 0: Preparation & Backup

```bash
# Full database backup
pg_dump vulcan_production > vulcan_pre_migration_$(date +%Y%m%d).sql

# Record current counts for verification
rails runner "
  puts 'Rules: ' + Rule.count.to_s
  puts 'SrgRules: ' + SrgRule.count.to_s
  puts 'StigRules: ' + StigRule.count.to_s
  puts 'Checks: ' + Check.count.to_s
  puts 'DisaRuleDescriptions: ' + DisaRuleDescription.count.to_s
  puts 'Satisfactions: ' + ActiveRecord::Base.connection.execute('SELECT COUNT(*) FROM rule_satisfactions').first['count']
"
```

### Phase 1: Add Fallback Display Methods

**Goal:** Establish pattern without changing database

```ruby
# app/models/concerns/display_fallback.rb
module DisplayFallback
  extend ActiveSupport::Concern

  included do
    def display_title
      self[:title].presence || srg_rule&.title
    end

    def display_fixtext
      self[:fixtext].presence || srg_rule&.fixtext
    end

    # ... etc
  end
end

# app/models/rule.rb
class Rule < ApplicationRecord
  include DisplayFallback
end
```

Update all blueprints and views to use `display_*` methods.

### Phase 2: Split STI into Separate Tables

**Goal:** Separate SrgRule, StigRule, Rule into distinct tables

```ruby
# db/migrate/YYYYMMDD_split_sti_tables.rb
class SplitStiTables < ActiveRecord::Migration[8.0]
  def up
    # Create srg_rules table
    create_table :srg_rules do |t|
      t.references :security_requirements_guide, foreign_key: true
      t.string :rule_identifier, null: false
      t.string :version
      t.string :title
      t.text :fixtext
      t.string :ident
      t.string :ident_system
      t.string :rule_severity
      t.string :rule_weight
      t.string :fix_id
      t.string :fixtext_fixref
      t.string :legacy_ids
      t.timestamps
    end

    # Create stig_rules table
    create_table :stig_rules do |t|
      t.references :stig, foreign_key: true
      t.string :rule_identifier, null: false
      t.string :version
      t.string :vuln_id
      t.string :srg_version
      # ... all stig-specific fields
      t.timestamps
    end

    # Migrate data
    execute <<~SQL
      INSERT INTO srg_rules (id, security_requirements_guide_id, rule_identifier, ...)
      SELECT id, security_requirements_guide_id, rule_id, ...
      FROM base_rules WHERE type = 'SrgRule'
    SQL

    # ... similar for stig_rules

    # Create srg_checks, srg_descriptions, stig_checks, stig_descriptions
    # ... migrate check and description data
  end
end
```

### Phase 3: Add Override Tables

```ruby
# db/migrate/YYYYMMDD_create_override_tables.rb
class CreateOverrideTables < ActiveRecord::Migration[8.0]
  def change
    create_table :rule_check_overrides do |t|
      t.references :rule, foreign_key: true, null: false
      t.text :content
      t.string :system
      t.timestamps
    end

    create_table :rule_description_overrides do |t|
      t.references :rule, foreign_key: true, null: false
      t.text :vuln_discussion
      t.text :mitigations
      # ... only commonly overridden fields
      t.timestamps
    end

    # Migrate existing overrides
    # Only create override record if content differs from SRG template
  end
end
```

### Phase 4: Migrate Satisfactions

```ruby
# db/migrate/YYYYMMDD_fix_satisfactions.rb
class FixSatisfactions < ActiveRecord::Migration[8.0]
  def up
    # Add srg_rule_id column
    add_column :rule_satisfactions, :srg_rule_id, :bigint
    add_column :rule_satisfactions, :id, :primary_key
    add_column :rule_satisfactions, :created_at, :datetime

    # Migrate: Find the srg_rule_id for each satisfied_by_rule
    execute <<~SQL
      UPDATE rule_satisfactions rs
      SET srg_rule_id = r.srg_rule_id
      FROM rules r
      WHERE rs.satisfied_by_rule_id = r.id
    SQL

    # Add foreign key and remove old column
    add_foreign_key :rule_satisfactions, :srg_rules
    remove_column :rule_satisfactions, :satisfied_by_rule_id
  end
end
```

### Phase 5: Add Versioning/Changesets

```ruby
# db/migrate/YYYYMMDD_create_benchmark_changesets.rb
class CreateBenchmarkChangesets < ActiveRecord::Migration[8.0]
  def change
    create_table :benchmark_changesets do |t|
      t.string :benchmark_type, null: false
      t.bigint :benchmark_id, null: false
      t.string :from_version, null: false
      t.string :to_version, null: false
      t.jsonb :changes, default: []
      t.jsonb :summary, default: {}
      t.datetime :computed_at, null: false
      t.timestamps
    end

    add_index :benchmark_changesets,
              [:benchmark_type, :benchmark_id, :from_version, :to_version],
              unique: true, name: 'idx_benchmark_changesets_unique'
  end
end
```

### Phase 6: Add Materialized Views

```sql
-- db/migrate/YYYYMMDD_create_materialized_views.rb
CREATE MATERIALIZED VIEW component_statistics AS
SELECT
  c.id as component_id,
  COUNT(r.id) as total_rules,
  COUNT(r.id) FILTER (WHERE r.locked = true) as locked_count,
  COUNT(r.id) FILTER (WHERE r.locked = false AND r.review_requestor_id IS NOT NULL) as under_review_count,
  COUNT(r.id) FILTER (WHERE r.status = 'Not Yet Determined') as not_yet_determined_count,
  COUNT(r.id) FILTER (WHERE r.status = 'Applicable - Configurable') as applicable_configurable_count,
  COUNT(r.id) FILTER (WHERE r.status = 'Applicable - Inherently Meets') as applicable_inherently_meets_count,
  COUNT(r.id) FILTER (WHERE r.status = 'Applicable - Does Not Meet') as applicable_does_not_meet_count,
  COUNT(r.id) FILTER (WHERE r.status = 'Not Applicable') as not_applicable_count,
  COUNT(DISTINCT rs.rule_id) as primary_controls_count,
  COUNT(DISTINCT rs.srg_rule_id) as nested_requirements_count,
  NOW() as refreshed_at
FROM components c
LEFT JOIN rules r ON r.component_id = c.id AND r.deleted_at IS NULL
LEFT JOIN rule_satisfactions rs ON rs.rule_id = r.id
GROUP BY c.id;

CREATE UNIQUE INDEX idx_component_statistics_id ON component_statistics(component_id);

-- Refresh strategy: After rule updates
CREATE OR REPLACE FUNCTION refresh_component_stats()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY component_statistics;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

### Phase 7: Data Cleanup & Deduplication

```ruby
# lib/tasks/cleanup_duplicates.rake
namespace :db do
  desc 'Remove duplicate content, keep only overrides'
  task cleanup_duplicates: :environment do
    Rule.includes(:srg_rule, :check_override, :description_override).find_each do |rule|
      # If rule title matches SRG, set to nil
      if rule.title_override == rule.srg_rule.title
        rule.update_column(:title_override, nil)
      end

      # If check content matches SRG, delete override record
      if rule.check_override&.content == rule.srg_rule.srg_check&.content
        rule.check_override&.destroy
      end

      # ... similar for descriptions
    end
  end
end
```

### Phase 8: Remove Legacy Columns

```ruby
# db/migrate/YYYYMMDD_remove_legacy_columns.rb
class RemoveLegacyColumns < ActiveRecord::Migration[8.0]
  def change
    # Remove old STI columns from rules table
    remove_column :rules, :type
    remove_column :rules, :security_requirements_guide_id
    remove_column :rules, :stig_id
    remove_column :rules, :stig_rule_id

    # Remove duplicate content columns (now in override tables)
    # Keep only _override columns

    # Drop old tables
    drop_table :base_rules  # After verifying all data migrated
    drop_table :checks      # Replaced by srg_checks + rule_check_overrides
    drop_table :disa_rule_descriptions  # Replaced by srg_descriptions + overrides

    # Drop metadata tables (merged into parent)
    drop_table :project_metadata
    drop_table :component_metadata
  end
end
```

---

## Performance Optimizations

### Indexes

```sql
-- Full-text search (already have some)
CREATE INDEX idx_srg_rules_fts ON srg_rules USING gin(
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(fixtext, ''))
);

-- Common queries
CREATE INDEX idx_rules_component_status ON rules(component_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_rules_component_locked ON rules(component_id, locked) WHERE deleted_at IS NULL;

-- Satisfaction lookups
CREATE INDEX idx_satisfactions_rule ON rule_satisfactions(rule_id);
CREATE INDEX idx_satisfactions_srg_rule ON rule_satisfactions(srg_rule_id);
```

### Caching Strategy

```ruby
# app/models/concerns/cached_statistics.rb
module CachedStatistics
  extend ActiveSupport::Concern

  included do
    def rules_summary
      Rails.cache.fetch("component/#{id}/rules_summary", expires_in: 5.minutes) do
        # Read from materialized view
        ComponentStatistic.find_by(component_id: id)&.attributes || calculate_summary
      end
    end
  end
end
```

### Blueprint Optimization

```ruby
# app/blueprints/rule_blueprint.rb
class RuleBlueprint < Blueprinter::Base
  # Use display methods that handle fallback
  field :title do |rule|
    rule.display_title
  end

  field :fixtext do |rule|
    rule.display_fixtext
  end

  # Eager load SRG rule for fallback
  association :srg_rule, blueprint: SrgRuleLightBlueprint

  # Only include override data if present
  field :has_title_override do |rule|
    rule.title_override.present?
  end
end
```

---

## Rollback Plan

Each phase has independent rollback capability:

1. **Phase 1:** Remove display methods (no DB changes)
2. **Phase 2-4:** Keep both old and new tables during migration, drop old only after verification
3. **Phase 5-6:** New tables/views can be dropped without affecting core functionality
4. **Phase 7-8:** Maintain backups, only remove after extended verification period

---

## Success Metrics

After migration:

| Metric | Current | Target |
|--------|---------|--------|
| Storage per Component | ~2MB | ~0.5MB |
| Rule fetch time (avg) | 50ms | 20ms |
| Component load time | 500ms | 200ms |
| Audit table growth/mo | 50,000 rows | 20,000 rows |
| Duplicate content | ~70% | 0% |

---

## Next Steps

1. **Review this document** - Get stakeholder alignment
2. **Create feature branch** - `feat/database-3nf-v3`
3. **Start Phase 0** - Backups and baseline metrics
4. **Incremental implementation** - One phase per session

---

**Ready to begin?** Start with Phase 0 (backup) and Phase 1 (display methods).
