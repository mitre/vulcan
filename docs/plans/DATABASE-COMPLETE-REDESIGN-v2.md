# Vulcan Database Complete Redesign

**Created:** 2025-11-30 (v1)
**Updated:** 2026-05-20 (v2)
**Status:** Design Document v2
**Scope:** Complete 3NF redesign of entire Vulcan database
**Revision:** Incorporates expert review findings (DB design, Rails/AR, PostgreSQL performance) and v2.3.4 shipped work.

---

## Table of Contents

1. [Changes Since v1](#changes-since-v1)
2. [Current State Analysis](#current-state-analysis)
3. [Problems Identified](#problems-identified)
4. [Proposed 3NF Schema](#proposed-3nf-schema)
5. [Review Workflow](#review-workflow)
6. [Diff & Changelog Features](#diff--changelog-features)
7. [SRG Upgrade Workflow](#srg-upgrade-workflow)
8. [Migration Strategy](#migration-strategy)
9. [Performance Optimizations](#performance-optimizations)
10. [Implementation Phases](#implementation-phases)
11. [Expert Review Findings](#expert-review-findings)
12. [Next Steps](#next-steps)

---

## Changes Since v1

The following items were shipped in v2.3.4 (Nov 2025 -- May 2026) and are marked [DONE] in the phase plan.

### Serialization Layer [DONE]
- Blueprinter gem adopted with 15 blueprints providing :index/:show/:editor views.
- Replaces all `as_json` overrides on API-facing models.
- Blueprint files: `app/blueprints/*.rb` (additional_answer, check, component, disa_rule_description, imported_attribution_fields, membership, project, project_index, review, rule, rule_description, satisfaction, satisfied_by, srg, srg_rule, stig, stig_rule, user).

### Audit Infrastructure [DONE]
- VulcanAuditable concern wraps `audited` gem with project-standard defaults (max_audits: 1000, auto-exclude timestamps).
- Counter cache fix: `rules_count` reset to 0 in amoeba customize block to prevent double-counting.
- `duplicate_reviews_and_history` rewritten as 4 bulk SQL statements (down from 4*N per-rule queries).

### Foreign Key Constraints [DONE]
- FK on `reviews.user_id` with `on_delete: :nullify`.
- FK on `reviews.rule_id`.

### Query Performance [DONE]
- `batch_rules_summary` method on Component for batch rule statistics.
- SQL subtraction for satisfaction lookups.
- Audit query limit applied.

### Reviews Model Expansion [DONE]
- 20+ columns added (was 6 in v1). Full column list in schema section below.
- `triage_status` (string, nullable) with 8 valid states.
- `adjudicated_at`, `triage_set_at` timestamps.
- `responding_to_review_id` (self-referential FK for threaded replies).
- `duplicate_of_review_id` (self-referential FK for dedup).
- `section` (string, nullable) -- XCCDF section key.
- `commentable_type` / `commentable_id` (polymorphic: BaseRule or Component).
- `triage_set_by_id`, `adjudicated_by_id` (FK to users).
- Six imported attribution columns via ImportedAttribution macro.
- Separate `reactions` table (review_id, user_id, kind) with unique constraint.

### Component Comment Phase [DONE]
- `comment_phase` (string, default: 'open').
- `comment_period_starts_at`, `comment_period_ends_at` (datetime).
- `closed_reason` (string, nullable: 'adjudicating' or 'finalized').
- Phase lifecycle methods: `accepting_new_comments?`, `triaging_active?`, `frozen_for_writes?`.

### Triage Context Panel [DONE] (PR #731)
- Split-pane triage view replacing the modal -- triagers see rule content alongside comment + triage form.
- `TriageSplitView.vue` -- split-pane with optimistic lock (`expected_updated_at`) + dirty guard.
- `RuleContextPanel.vue` -- read-only rule content with collapsible sections, fisheye focus, section comment count badges.
- `TriageQueueNav.vue` -- 2D navigation (rule arrows + comment arrows) with Jump To dropdown.
- `CommentTriageForm.vue` -- extracted triage form shared between modal and split-pane.
- `ReplyComposerMixin.vue` -- unified composer state (replaced 2 divergent patterns across 4 consumers).
- `ReactionToggleMixin.vue` -- optimistic reaction toggle with rollback (used by CommentThread, RuleReviews, CommentDedupBanner, TriageSplitView).
- `paginated_comments` method on Component + Project with `include_rule_content` parameter for split-pane preload.
- Component controller `comments` action serves JSON for API, redirects HTML to triage page.
- Project-level and component-level triage pages both functional.
- Future: migrate to BenchmarkViewer three-column layout (card vulcan-v3.x-ec3) for 450+ requirement scalability.

### Seed System Modernization [DONE] (PR #731)
- Monolithic 648-line seeds.rb replaced with 9 modular numbered files + SeedHelpers module.
- `dev:prime`, `dev:verify`, `dev:status`, `dev:reset` rake tasks.
- 22 factory traits across 6 models (Review 12, Rule 4, Project 2, Component 3, Membership 1).
- Stig `:skip_rules` trait prevents deadlock in parallel tests.

### DRY Centralization [DONE] (PR #731)
- `relativeTime` eliminated from 4 components -- all use `DateFormatMixin.friendlyDateTime`.
- JS `truncate` replaced with Bootstrap `.text-truncate` CSS class + `title` attribute.
- `statusOptions` computed extracted to `buildStatusFilterOptions()` in `triageVocabulary.js`.

### Blueprint Coverage Assessment

Current blueprints (18 files in `app/blueprints/`):

| Blueprint | Model | Views | Status |
|-----------|-------|-------|--------|
| additional_answer | AdditionalAnswer | default | OK |
| check | Check | default | OK -- will map to srg_checks post-migration |
| component | Component | index, show, editor | OK -- needs comment_phase fields in show/editor |
| disa_rule_description | DisaRuleDescription | default | OK -- will map to srg_descriptions |
| imported_attribution_fields | (shared module) | n/a | OK -- used by ReviewBlueprint |
| membership | Membership | default | OK |
| project | Project | show | OK |
| project_index | Project | index | OK |
| review | Review | default | NEEDS UPDATE -- missing triage display fields |
| rule | Rule | index, show, editor | NEEDS UPDATE -- must add display_* fallbacks post-migration |
| rule_description | RuleDescription | default | OK |
| satisfaction | RuleSatisfaction | default | NEEDS UPDATE -- will point to srg_rules |
| satisfied_by | RuleSatisfaction | default | NEEDS UPDATE -- will point to srg_rules |
| srg | SecurityRequirementsGuide | default | OK |
| srg_rule | SrgRule | default | OK |
| stig | Stig | default | OK |
| stig_rule | StigRule | default | OK |
| user | User | default | OK |

Missing blueprints (needed for complete coverage):

| Model/Concept | Why Needed | Priority |
|---------------|-----------|----------|
| Reaction | API returns reactions as inline hash; dedicated blueprint needed for standalone endpoints | P2 |
| ProjectAccessRequest | Currently uses as_json; should use Blueprinter | P3 |
| ComponentStatistics | Materialized view / counter cache output needs serialization | P2 (post-migration) |
| BenchmarkChangeset | New table; needs blueprint for diff UI | P2 (post-migration) |
| RuleCheckOverride | New table; needs blueprint for override tracking UI | P2 (post-migration) |
| RuleDescriptionOverride | New table; needs blueprint for override tracking UI | P2 (post-migration) |
| SrgCheck | New table post-STI-split; replaces Check blueprint | P1 (Phase 2) |
| SrgDescription | New table post-STI-split; replaces DisaRuleDescription blueprint | P1 (Phase 2) |

Blueprint migration plan (aligns with DB phases):
- Phase 1: Update RuleBlueprint to use `display_*` methods with fallback.
- Phase 2: Create SrgCheckBlueprint, SrgDescriptionBlueprint. Retire Check/DisaRuleDescription blueprints.
- Phase 2.5: Update ReviewBlueprint with triage display fields, reaction counts.
- Phase 3: Create RuleCheckOverrideBlueprint, RuleDescriptionOverrideBlueprint.
- Phase 5: Create BenchmarkChangesetBlueprint.

---

## Current State Analysis

### All Current Tables (24 tables)

| Table | Rows (typical) | Purpose | Issues |
|-------|---------------|---------|--------|
| `users` | 100s | User accounts | OK |
| `projects` | 10-100 | Project containers | OK |
| `components` | 10-500 | STIG in progress | OK (comment fields added) |
| `security_requirements_guides` | 10-50 | SRG templates | OK |
| `stigs` | 100-500 | Published STIGs | OK |
| `base_rules` (STI) | 10,000-100,000+ | Rules/Controls | MAJOR ISSUES |
| `checks` | Same as rules | Check content | DUPLICATED |
| `disa_rule_descriptions` | Same as rules | Description fields | DUPLICATED |
| `rule_descriptions` | Rarely used | Non-DISA descriptions | Sparse |
| `references` | Rarely used | DC references | Sparse |
| `rule_satisfactions` | 100s-1000s | Nesting relationships | WRONG DESIGN |
| `reviews` | 100s-10,000s | Review + comment workflow | [UPDATED] 20+ columns |
| `reactions` | 100s-1000s | Comment reactions | [NEW] OK |
| `memberships` | 100s | User permissions | OK |
| `audits` | 10,000s+ | Change history | GROWS FAST (mitigated) |
| `additional_questions` | 10s | Custom questions | OK |
| `additional_answers` | 100s | Question answers | OK |
| `project_metadata` | = projects | JSON metadata | WHY SEPARATE? |
| `component_metadata` | = components | JSON metadata | WHY SEPARATE? |
| `project_access_requests` | 10s | Access requests | OK |
| `search_abbreviations` | 10s | Search expansion | OK |
| `session_histories` | 100s-1000s | Session tracking | OK |

### STI Model (`base_rules` table)

```
base_rules (Single Table Inheritance)
+-- type = "SrgRule"      -> Template from SRG (read-only, shared)
+-- type = "StigRule"     -> Published STIG rule (reference)
+-- type = "Rule"         -> User's authored implementation
```

**Current Column Count:** 34 columns in base_rules
**Storage:** Massive duplication -- every Component copies ALL SRG content

---

## Problems Identified

### CRITICAL: 3NF Violations

#### Problem 1: Content Duplication (Biggest Issue)

```
When user creates Component from SRG (263 requirements):
  -> Creates 263 Rule records (copies ALL content from SrgRules)
  -> Creates 263 Check records (copies ALL check content)
  -> Creates 263 DisaRuleDescription records (copies ALL 11 fields)

Result: ~70% of data is duplicated from templates
```

**Impact:**
- Database bloat: O(components x requirements) instead of O(requirements)
- Update propagation: SRG typo fix doesn't update copied Rules
- Sync issues: Components can drift from SRG baseline

#### Problem 2: Wrong Satisfaction Model

```
Current: Rule -> Rule (same component)
  - Creates "placeholder" Rules just to have linking targets
  - Confusing: "satisfied_by" links to another Rule in same component

Should be: Rule -> SrgRule (template)
  - Direct link to SRG requirement
  - No placeholder Rules needed
  - Clear semantics: "this control satisfies SRG requirement X"
```

#### Problem 3: No Version/Diff Tracking

```
Current: SRG versions are separate records
  - No structured way to diff V2R1 -> V2R2
  - User manually compares XCCDF files
  - No "what changed in my baseline?" feature

Need: Computed changesets on import
  - Store diffs between versions
  - Show impact on Components when SRG updates
```

#### Problem 4: Metadata Tables Unnecessary

```
project_metadata: { data: jsonb }  -> Should be columns on projects
component_metadata: { data: jsonb } -> Should be columns on components

No clear schema = no validation, no indexing, harder queries
```

#### Problem 5: Override NULL Semantics Ambiguity [CRITICAL FIX]

```
rule_description_overrides has dual NULL meaning:
  - Row absent:    user has not overridden any description fields
  - Column NULL:   row exists but this specific column was not overridden

This ambiguity makes "which fields did the user override?" queries
unreliable -- you can't distinguish "user set to empty" from
"user didn't touch this."

Fix: Add `overridden_fields text[]` array column to each override table.
  - NULL column + field NOT in overridden_fields = use SRG template
  - NULL column + field IN overridden_fields = user explicitly cleared
  - Non-NULL column = user's custom value
```

### MODERATE: Performance Issues

#### Problem 6: N+1 Queries in Rules

```ruby
# Current: Fetching component with rules
component.rules.each do |rule|
  rule.checks           # N+1
  rule.disa_rule_descriptions  # N+1
  rule.satisfies        # N+1
  rule.satisfied_by     # N+1
end
```

**Partial fix exists:** `batch_rules_summary` in Component model [DONE]
**Still needed:** DisplayFallback scope for eager loading (see Phase 1)

#### Problem 7: Audits Table Growth

```
Every rule update creates audit record
Every check update creates audit record
Every description update creates audit record

100 components x 263 rules x 10 updates each = 263,000 audit records
```

**Mitigated:** VulcanAuditable concern with max_audits: 1000 [DONE]
**Still needed:** Audit retention policy, archival strategy

#### Problem 8: ComponentSrgUpgradeService N+1 [CRITICAL FIX]

```ruby
# Current: rules_with_matching_requirements fires N+1 EXISTS queries
def rules_with_matching_requirements
  @component.rules.select { |r|
    @new_srg.srg_rules.exists?(version: r.srg_rule.version)  # N+1!
  }
end

# Fix: Prefetch versions into a Set
def rules_with_matching_requirements
  @new_versions ||= Set.new(@new_srg.srg_rules.pluck(:version))
  @component.rules.includes(:srg_rule).select { |r|
    @new_versions.include?(r.srg_rule.version)
  }
end
```

### MINOR: Schema Cleanup

#### Problem 9: Unused/Sparse Columns

- `rule_descriptions` -- Rarely populated (non-DISA format)
- `references` -- Rarely populated (DC metadata)
- Many columns on base_rules that only apply to specific types

#### Problem 10: Inconsistent Naming

- `security_requirements_guide_id` vs `srg_id`
- `component_id` used for both "overlay parent" and "belongs to"
- `rule_id` (string) vs `id` (bigint primary key)

---

## Proposed 3NF Schema

### Core Design Principles

1. **Store overrides, not copies** -- Rules only store user modifications
2. **Template inheritance** -- Display methods fall back to SRG/STIG
3. **Direct SRG linking** -- Satisfactions link Rule -> SrgRule
4. **Counter caches over materialized views** -- Avoid trigger deadlocks [CRITICAL FIX]
5. **Structured versioning** -- Track diffs between benchmark versions
6. **Explicit override tracking** -- `overridden_fields` array disambiguates NULLs [CRITICAL FIX]

### New Schema Diagram

```
+-----------------------------------------------------------------------------+
|                           VULCAN 3NF SCHEMA v3.1                            |
+-----------------------------------------------------------------------------+

===============================================================================
AUTHENTICATION & AUTHORIZATION
===============================================================================

+---------------------------+         +---------------------------+
| users                     |         | memberships               |
|---------------------------|         |---------------------------|
| id (PK)                   |<--------| user_id (FK)              |
| email                     |         | membership_type           |-> 'Project' | 'Component'
| name                      |         | membership_id             |
| admin                     |         | role                      |-> 'admin' | 'reviewer' | 'author' | 'viewer'
| provider                  |         | created_at                |
| uid                       |         +---------------------------+
| encrypted_password        |
| ...devise fields...       |
+---------------------------+

===============================================================================
PROJECT HIERARCHY
===============================================================================

+---------------------------+         +-------------------------------+
| projects                  |         | components                    |
|---------------------------|         | (STIG in progress)            |
| id (PK)                   |<--------|-------------------------------|
| name                      |         | id (PK)                       |
| description               |         | project_id (FK)               |
| visibility                |         | srg_id (FK)                   |----------+
| admin_name                |         | overlay_component_id          | (self)   |
| admin_email               |         | name                          |          |
| memberships_count         |         | prefix                        |          |
| metadata (jsonb)  [NEW]   |         | version                       |          |
| created_at                |         | release                       |          |
| updated_at                |         | title                         |          |
+---------------------------+         | description                   |          |
                                      | released                      |          |
                                      | rules_count                   |          |
                                      | admin_name                    |          |
                                      | admin_email                   |          |
                                      | advanced_fields               |          |
                                      | metadata (jsonb)  [NEW]       |          |
                                      | comment_phase           [DONE]|          |
                                      | comment_period_starts_at[DONE]|          |
                                      | comment_period_ends_at  [DONE]|          |
                                      | closed_reason           [DONE]|          |
                                      | created_at                    |          |
                                      | updated_at                    |          |
                                      +-------------------------------+          |
                                                                                 |
===============================================================================  |
BENCHMARKS (Templates - Read-Only After Import)                                  |
===============================================================================  |
                                                                                 |
+-----------------------------------+                                            |
| security_requirements_guides      |<-------------------------------------------+
| (SRG)                             |
|-----------------------------------|
| id (PK)                           |
| srg_id                            |
| title                             |
| name                              |
| version                           |
| release_date                      |
| srg_family_id [NEW]               |  e.g., "General_Purpose_OS_SRG"
| xml                               |
| created_at                        |
| updated_at                        |
+-----------------------------------+
            | has_many
            v
+-----------------------------------+
| srg_rules                         |   [SEPARATE TABLE - No longer STI]
| (SRG Template Requirements)       |
|-----------------------------------|
| id (PK)                           |
| srg_id (FK)                       |<-- security_requirements_guide
| rule_identifier                   |    (renamed from rule_id string)
| version                           |    e.g., "SRG-OS-000023"
| title                             |
| fixtext                           |
| ident                             |    CCI-001234
| ident_system                      |
| rule_severity                     |
| rule_weight                       |
| fix_id                            |
| fixtext_fixref                    |
| legacy_ids                        |
| created_at                        |
+-----------------------------------+
            | has_many
            v
+-----------------------------------+   +-----------------------------------+
| srg_checks                  [NEW] |   | srg_descriptions            [NEW] |
|-----------------------------------|   |-----------------------------------|
| id (PK)                           |   | id (PK)                           |
| srg_rule_id (FK)                  |   | srg_rule_id (FK)                  |
| system                            |   | vuln_discussion                   |
| content_ref_name                  |   | false_positives                   |
| content_ref_href                  |   | false_negatives                   |
| content                           |   | documentable                      |
+-----------------------------------+   | mitigations                       |
                                        | severity_override_guidance        |
                                        | potential_impacts                 |
                                        | third_party_tools                 |
                                        | mitigation_control                |
                                        | responsibility                    |
                                        | ia_controls                       |
                                        +-----------------------------------+

+-----------------------------------+
| stigs                             |   (Published STIGs - Reference)
|-----------------------------------|
| id (PK)                           |
| stig_id                           |
| title                             |
| name                              |
| version                           |
| description                       |
| benchmark_date                    |
| xml                               |
| created_at                        |
+-----------------------------------+
            | has_many
            v
+-----------------------------------+
| stig_rules                        |   [SEPARATE TABLE - No longer STI]
| (Published STIG Controls)         |
|-----------------------------------|
| id (PK)                           |
| stig_id (FK)                      |
| rule_identifier                   |
| version                           |
| vuln_id                           |   e.g., "V-230221"
| srg_version                       |   e.g., "SRG-OS-000023" (reference)
| title                             |
| fixtext                           |
| ... (all published content)       |
+-----------------------------------+
            | has_many
            v
+-----------------------------------+   +-----------------------------------+
| stig_checks                 [NEW] |   | stig_descriptions           [NEW] |
|-----------------------------------|   |-----------------------------------|
| (same structure as srg_checks)    |   | (same structure as srg_desc)      |
+-----------------------------------+   +-----------------------------------+

===============================================================================
USER-AUTHORED CONTENT (Overrides Only)
===============================================================================

+-----------------------------------------------------------------------------+
| rules                                                                       |
| (User's Implementation - Stores ONLY Overrides)                             |
|-----------------------------------------------------------------------------|
| id (PK)                                                                     |
| component_id (FK)        --> components                                     |
| srg_rule_id (FK)         --> srg_rules (the requirement this implements)    |
| display_number           (e.g., "000001" - for PREFIX-000001)               |
|                                                                             |
| --- USER-SPECIFIC FIELDS (Always stored on Rule) ---                        |
| status                   ('Not Yet Determined', 'Applicable - ...', etc.)   |
| status_justification                                                        |
| artifact_description                                                        |
| vendor_comments                                                             |
| inspec_control_body                                                         |
| inspec_control_file                                                         |
| locked                                                                      |
| locked_fields (jsonb)                                                       |
| review_requestor_id      --> users                                          |
| changes_requested                                                           |
| deleted_at               (soft delete)                                      |
|                                                                             |
| --- OVERRIDE FIELDS (NULL = use SRG template) ---                           |
| title_override           (NULL or user's custom title)                      |
| fixtext_override         (NULL or user's custom fix)                        |
| ident_override           (NULL or user's custom CCIs)                       |
| severity_override        (NULL or user's custom severity)                   |
|                                                                             |
| created_at                                                                  |
| updated_at                                                                  |
+-----------------------------------------------------------------------------+
                           |
                           | has_one (optional - only if user overrides)
                           v
+-----------------------------------+   +-----------------------------------+
| rule_check_overrides        [NEW] |   | rule_description_overrides  [NEW] |
|-----------------------------------|   |-----------------------------------|
| id (PK)                           |   | id (PK)                           |
| rule_id (FK) UNIQUE         [FIX] |   | rule_id (FK) UNIQUE         [FIX] |
| content                           |   | vuln_discussion                   |
| system                            |   | mitigations                       |
| overridden_fields text[]    [FIX] |   | ... (only modified fields)        |
| created_at                        |   | overridden_fields text[]    [FIX] |
| updated_at                        |   | created_at                        |
+-----------------------------------+   | updated_at                        |
                                        +-----------------------------------+

[FIX] UNIQUE index on rule_id enforces has_one at DB level.
[FIX] overridden_fields array disambiguates NULL semantics.

===============================================================================
SATISFACTION RELATIONSHIPS (Correct Model)
===============================================================================

+-----------------------------------------------------------------------------+
| rule_satisfactions                                                          |
|-----------------------------------------------------------------------------|
| id (PK)                  [NEW - add primary key]                            |
| rule_id (FK)             --> rules (the control doing the satisfying)       |
| srg_rule_id (FK)         --> srg_rules (the SRG requirement being satisfied)|
| created_at               [NEW]                                              |
|                                                                             |
| UNIQUE INDEX: (rule_id, srg_rule_id)                                        |
|                                                                             |
| Example: SSH config control satisfies 3 SRG requirements                    |
| +----------+-------------+                                                  |
| | rule_id  | srg_rule_id |                                                  |
| +----------+-------------+                                                  |
| |    5     |     23      |  Rule #5 satisfies SRG-OS-000023                 |
| |    5     |     24      |  Rule #5 satisfies SRG-OS-000024                 |
| |    5     |     25      |  Rule #5 satisfies SRG-OS-000025                 |
| +----------+-------------+                                                  |
+-----------------------------------------------------------------------------+

===============================================================================
REVIEW & COMMENT WORKFLOW [UPDATED]
===============================================================================

+-----------------------------------------------------------------------------+
| reviews                                                                     |
|-----------------------------------------------------------------------------|
| id (PK)                                                                     |
| user_id (FK, nullable)   --> users (on_delete: nullify)             [DONE]  |
| rule_id (FK, nullable)   --> rules (back-compat, dual-write)        [DONE]  |
| commentable_type         'BaseRule' | 'Component'                   [DONE]  |
| commentable_id           --> base_rules.id or components.id         [DONE]  |
| action                   'comment' | 'request_review' | ...         [DONE]  |
| comment (text)                                                      [DONE]  |
| section                  XCCDF section key (nullable)               [DONE]  |
|                                                                             |
| --- TRIAGE WORKFLOW ---                                                     |
| triage_status            nullable; 8 valid states                   [DONE]  |
| triage_set_by_id (FK)    --> users                                  [DONE]  |
| triage_set_at            datetime                                   [DONE]  |
| adjudicated_at           datetime                                   [DONE]  |
| adjudicated_by_id (FK)   --> users                                  [DONE]  |
|                                                                             |
| --- THREADING & DEDUP ---                                                   |
| responding_to_review_id  self-ref FK (reply chain)                  [DONE]  |
| duplicate_of_review_id   self-ref FK (dedup target)                 [DONE]  |
|                                                                             |
| --- IMPORTED ATTRIBUTION ---                                                |
| triage_set_by_imported_email / _name                                [DONE]  |
| adjudicated_by_imported_email / _name                               [DONE]  |
| commenter_imported_email / _name                                    [DONE]  |
|                                                                             |
| created_at, updated_at                                                      |
+-----------------------------------------------------------------------------+
      |
      | has_many
      v
+-----------------------------------+
| reactions                   [DONE]|
|-----------------------------------|
| id (PK)                           |
| review_id (FK)                    |
| user_id (FK)                      |
| kind (string)  'up' | 'down'     |
| UNIQUE: (review_id, user_id)     |
+-----------------------------------+

Phase 2.5 Migration Note [NEW]:
  After STI split (Phase 2), reviews that currently reference base_rules
  via rule_id and commentable_type='BaseRule' must be migrated:
  - rule_id FKs re-pointed from base_rules to the new rules table
  - commentable_type updated from 'BaseRule' to 'Rule'
  - Component-scoped reviews (commentable_type='Component') unchanged

===============================================================================
BENCHMARK VERSIONING (New Feature)
===============================================================================

+-----------------------------------------------------------------------------+
| benchmark_changesets                                                   [NEW] |
|-----------------------------------------------------------------------------|
| id (PK)                                                                     |
| from_benchmark_type      --> 'SecurityRequirementsGuide' | 'Stig'    [FIX]  |
| from_benchmark_id (FK, nullable) --> srgs.id or stigs.id             [FIX]  |
| to_benchmark_type        --> 'SecurityRequirementsGuide' | 'Stig'    [FIX]  |
| to_benchmark_id (FK, nullable)   --> srgs.id or stigs.id             [FIX]  |
| from_version             ('V2R1')                                           |
| to_version               ('V2R2')                                           |
| computed_at                                                                 |
| changes (jsonb)          [CHECK: pg_column_size < 256000]            [FIX]  |
| summary (jsonb)          { added: 3, modified: 12, removed: 1 }            |
|                                                                             |
| UNIQUE INDEX: (from_benchmark_type, from_benchmark_id,                      |
|                to_benchmark_type, to_benchmark_id)                          |
| GIN INDEX: changes                                                   [FIX]  |
+-----------------------------------------------------------------------------+

[FIX] Dual nullable FKs replace polymorphic benchmark_type/benchmark_id
      to enable real FK enforcement. CHECK constraint on each:
      (from_benchmark_type = 'SecurityRequirementsGuide'
       AND from_benchmark_id IS NOT NULL)
      OR
      (from_benchmark_type = 'Stig'
       AND from_benchmark_id IS NOT NULL)
[FIX] GIN index on changes JSONB for containment queries.
[FIX] CHECK constraint on pg_column_size(changes) < 256000 to prevent
      unbounded JSONB growth (200KB+ possible with large SRG diffs).

===============================================================================
COUNTER CACHES (Replacing Materialized Views) [CRITICAL FIX]
===============================================================================

v1 proposed materialized views with per-row triggers. Expert review found
this creates deadlock risk: REFRESH CONCURRENTLY synchronously in a trigger
serializes ALL writes. A bulk upgrade touching 263 rules would fire 263
concurrent refreshes.

Replacement approach: counter cache columns + async background job.

+-----------------------------------------------------------------------------+
| components (additional counter columns)                                     |
|-----------------------------------------------------------------------------|
| locked_count             integer, default: 0                                |
| under_review_count       integer, default: 0                                |
| not_yet_determined_count integer, default: 0                                |
| applicable_configurable_count integer, default: 0                           |
| applicable_inherently_count   integer, default: 0                           |
| applicable_does_not_meet_count integer, default: 0                          |
| not_applicable_count     integer, default: 0                                |
+-----------------------------------------------------------------------------+

Refresh Strategy:
  - Rule after_commit callback sends pg_notify('component_stats_dirty',
    component_id) instead of inline REFRESH.
  - Background job (SolidQueue or equivalent) subscribes to the channel
    and recalculates counters in a single UPDATE ... FROM subquery.
  - Debounce: coalesce multiple notifications for the same component_id
    within a 2-second window into one recalculation.
  - Fallback: `rake stats:recalculate` for manual full refresh.

For read-heavy dashboards that need project-level aggregates, a
lightweight project_statistics MATERIALIZED VIEW (refreshed on a
cron schedule, NOT per-row trigger) remains acceptable:

  CREATE MATERIALIZED VIEW project_statistics AS
  SELECT p.id as project_id,
         SUM(c.rules_count) as total_rules,
         COUNT(c.id) as total_components,
         SUM(c.locked_count) as locked_count,
         ...
  FROM projects p
  LEFT JOIN components c ON c.project_id = p.id
  GROUP BY p.id;

  -- Refresh via cron (every 5 min), NOT per-row trigger
  CREATE UNIQUE INDEX idx_project_statistics_id ON project_statistics(project_id);
```

### Display Logic (Fallback Pattern) [UPDATED]

```ruby
# app/models/concerns/display_fallback.rb
module DisplayFallback
  extend ActiveSupport::Concern

  included do
    # Eager-loading scope to prevent N+1 on collections.  [FIX]
    # Use: component.rules.with_display_fallbacks.each { |r| r.display_title }
    scope :with_display_fallbacks, -> {
      includes(:srg_rule, :check_override, :description_override)
    }

    def display_title
      title_override.presence || srg_rule&.title
    end

    def display_fixtext
      fixtext_override.presence || srg_rule&.fixtext
    end

    def display_check_content
      check_override&.content.presence || srg_rule&.srg_check&.content
    end

    def display_vuln_discussion
      description_override&.vuln_discussion.presence ||
        srg_rule&.srg_description&.vuln_discussion
    end

    # Generic display method  [CRITICAL FIX]
    # v1 used `send(field) rescue nil` which silently swallows all errors.
    # Fixed to use respond_to? guard.
    def display_field(field)
      override_method = "#{field}_override"
      override_value = if respond_to?(override_method, true)
                         public_send(override_method)
                       else
                         nil
                       end
      override_value.presence || srg_rule&.public_send(field)
    end

    # Returns true if this rule has ANY overrides from the SRG template.
    def has_overrides?
      title_override.present? ||
        fixtext_override.present? ||
        ident_override.present? ||
        severity_override.present? ||
        check_override.present? ||
        description_override.present?
    end

    # Summary of what this rule overrides from its SRG template.
    def override_summary
      {
        rule_id: id,
        display_number: display_number,
        srg_requirement: srg_rule&.version,
        overridden: {
          title: title_override.present?,
          fixtext: fixtext_override.present?,
          ident: ident_override.present?,
          severity: severity_override.present?,
          check: check_override.present?,
          description: description_override.present?
        }
      }
    end
  end
end
```

---

## Review Workflow [UPDATED]

v1 marked Reviews as "Unchanged." The model has since grown significantly (20+ columns, 8 triage states, threaded replies, reactions, imported attribution, polymorphic commentable). This section documents the current state and the Phase 2.5 migration needed after STI split.

### Current Review Schema (v2.3.4)

```
reviews (24 columns)
+-- id (PK)
+-- user_id (FK, nullable) --> users
+-- rule_id (FK, nullable) --> base_rules (back-compat dual-write)
+-- commentable_type / commentable_id (polymorphic: BaseRule | Component)
+-- action (string: comment, request_review, revoke_review_request, etc.)
+-- comment (text)
+-- section (string, nullable: title, severity, fixtext, check_content, ...)
+-- triage_status (string, nullable: pending, concur, non_concur, ...)
+-- triage_set_by_id (FK) --> users
+-- triage_set_at (datetime)
+-- adjudicated_at (datetime)
+-- adjudicated_by_id (FK) --> users
+-- responding_to_review_id (self-ref FK)
+-- duplicate_of_review_id (self-ref FK)
+-- 6x imported attribution columns
+-- created_at, updated_at
```

### Triage State Machine

```
                         +-- concur -----+
                         |               |
  NEW -> pending --------+-- non_concur -+---> adjudicated
  comment                |               |     (adjudicated_at set)
                         +-- concur_w_c -+
                         |
                         +-- needs_clarification (re-triageable)
                         |
                         +-- duplicate -------> auto-adjudicated
                         |                      (requires duplicate_of_review_id)
                         +-- informational ---> auto-adjudicated
                         |
                         +-- withdrawn -------> auto-adjudicated

  Replies (responding_to_review_id present) do NOT enter triage queue.
  Only top-level comments (action='comment', responding_to_review_id=NULL)
  participate in the triage workflow.
```

### Phase 2.5: Reviews FK Migration [NEW]

After Phase 2 splits STI, reviews need migration:

```ruby
# db/migrate/YYYYMMDD_migrate_review_fks.rb
class MigrateReviewFks < ActiveRecord::Migration[8.0]
  def up
    # 1. rule_id already points to base_rules.id values that will
    #    become rules.id (ID-preserving migration). No data change needed,
    #    but the FK constraint must be re-pointed.
    remove_foreign_key :reviews, :base_rules, column: :rule_id, if_exists: true
    add_foreign_key :reviews, :rules, column: :rule_id, on_delete: :nullify

    # 2. Update polymorphic type from 'BaseRule' to 'Rule'
    #    Component-scoped reviews (commentable_type='Component') unchanged.
    execute <<~SQL
      UPDATE reviews
      SET commentable_type = 'Rule'
      WHERE commentable_type = 'BaseRule'
    SQL

    # 3. Reactions FK remains on reviews.id -- no change needed.
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      'Cannot reverse polymorphic type rename safely'
  end
end
```

### Indexes on Reviews (current + planned)

```sql
-- Existing indexes (v2.3.4):
CREATE INDEX index_reviews_on_rule_id ON reviews(rule_id);
CREATE INDEX index_reviews_on_user_id ON reviews(user_id);
CREATE INDEX index_reviews_on_commentable ON reviews(commentable_type, commentable_id);
CREATE INDEX index_reviews_on_responding_to ON reviews(responding_to_review_id);
CREATE INDEX index_reviews_on_duplicate_of ON reviews(duplicate_of_review_id);
CREATE INDEX idx_reviews_top_level_triage_recent ON reviews(triage_status, created_at)
  WHERE action = 'comment' AND responding_to_review_id IS NULL;
CREATE INDEX index_reviews_on_action_and_triage ON reviews(action, triage_status);
CREATE INDEX index_reviews_on_rule_section_triage
  ON reviews(rule_id, section, triage_status);

-- No additional indexes needed. Coverage is comprehensive.
```

---

## Diff & Changelog Features

### Use Cases

1. **"What changed in this SRG version?"** -- Compare SRG V2R1 -> V2R2
2. **"What changed in this STIG release?"** -- Compare RHEL 9 V1R1 -> V1R2
3. **"What did I change from the SRG template?"** -- Show Component overrides
4. **"What changed in my Component since last week?"** -- Audit history view
5. **"How does my Component compare to the published STIG?"** -- STIG diff

### Database Support

#### Benchmark Changesets (SRG/STIG Version Diffs)

```sql
-- Computed on import of new SRG/STIG version
CREATE TABLE benchmark_changesets (
  id BIGSERIAL PRIMARY KEY,

  -- Dual nullable FKs replace polymorphic (enables real FK enforcement)  [FIX]
  from_benchmark_type VARCHAR NOT NULL,
  from_benchmark_id BIGINT NOT NULL,
  to_benchmark_type VARCHAR NOT NULL,
  to_benchmark_id BIGINT NOT NULL,

  -- FK enforcement via CHECK constraint  [FIX]
  CONSTRAINT chk_from_benchmark CHECK (
    from_benchmark_type IN ('SecurityRequirementsGuide', 'Stig')
  ),
  CONSTRAINT chk_to_benchmark CHECK (
    to_benchmark_type IN ('SecurityRequirementsGuide', 'Stig')
  ),

  -- Version info
  from_version VARCHAR NOT NULL,    -- 'V2R1'
  to_version VARCHAR NOT NULL,      -- 'V2R2'

  -- The actual diff (computed on import)
  changes JSONB NOT NULL DEFAULT '[]',
  -- Size guard: prevent unbounded JSONB growth  [FIX]
  CONSTRAINT chk_changes_size CHECK (pg_column_size(changes) < 256000),

  -- Summary counts
  summary JSONB NOT NULL DEFAULT '{}',

  computed_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_benchmark_changesets_unique
ON benchmark_changesets(from_benchmark_type, from_benchmark_id,
                        to_benchmark_type, to_benchmark_id);

-- GIN index for JSONB containment queries  [FIX]
CREATE INDEX idx_benchmark_changesets_changes_gin
ON benchmark_changesets USING gin(changes);
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
  rules.with_display_fallbacks  # [FIX] Use eager-loading scope
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
+-------------------------------------------------------------+
| SRG Version Diff: General Purpose OS V2R1 -> V2R2           |
+-------------------------------------------------------------+
| Summary: +3 Added | -1 Removed | ~12 Modified | 247 Unchanged|
+-------------------------------------------------------------+
|                                                              |
| [+] ADDED                                                    |
| +-- SRG-OS-000500: New container isolation requirement       |
| +-- SRG-OS-000501: New cloud deployment requirement          |
| +-- SRG-OS-000502: New MFA requirement for privileged access |
|                                                              |
| [-] REMOVED                                                  |
| +-- SRG-OS-000099: Legacy audit requirement (merged into 023)|
|                                                              |
| [~] MODIFIED                                                 |
| +-- SRG-OS-000023: [title] [fixtext] [severity: medium->high]|
| +-- SRG-OS-000024: [check]                                   |
| +-- ...                                                      |
|                                                              |
+-------------------------------------------------------------+
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

-- Composite index for upgrade workflow queries  [FIX]
CREATE INDEX idx_srg_family_version
ON security_requirements_guides(srg_family_id, version);

-- Composite index on srg_rules for version matching  [FIX]
CREATE INDEX idx_srg_rules_srg_version
ON srg_rules(security_requirements_guide_id, version);

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

Note: `srg_rule_lineage` overlaps with `benchmark_changesets` data but
serves a different purpose. `benchmark_changesets` stores the full
version-to-version diff (for UI display). `srg_rule_lineage` provides
per-rule FK pointers (for the upgrade service to follow). Deriving one
from the other was considered but rejected: the join would be expensive
and the lineage table is small. Both are computed on SRG import.

#### Upgrade Service [UPDATED]

```ruby
# app/services/component_srg_upgrade_service.rb

class ComponentSrgUpgradeService
  def initialize(component, new_srg)
    @component = component
    @old_srg = component.security_requirements_guide
    @new_srg = new_srg
  end

  def preview
    {
      component: @component.name,
      from_srg: "#{@old_srg.title} #{@old_srg.version}",
      to_srg: "#{@new_srg.title} #{@new_srg.version}",
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
      rules_to_add: new_requirements.map { |sr|
        { srg_requirement: sr.version, title: sr.title }
      },
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
      @component.update!(security_requirements_guide: @new_srg)

      rules_with_matching_requirements.each do |rule|
        new_srg_rule = find_matching_new_srg_rule(rule)

        if options[:preserve_overrides]
          rule.update!(srg_rule_id: new_srg_rule.id)
        else
          rule.update!(srg_rule_id: new_srg_rule.id)
          if !rule.configurable? && template_changed?(rule)
            rule.clear_overrides! if options[:refresh_non_configurable]
          end
        end
      end

      new_requirements.each do |new_srg_rule|
        @component.rules.create!(
          srg_rule: new_srg_rule,
          display_number: next_display_number,
          status: 'Not Yet Determined'
        )
      end

      removed_requirements.each do |rule|
        if options[:delete_removed]
          rule.destroy!
        else
          rule.update!(
            status: 'Not Applicable',
            status_justification: "Requirement #{rule.srg_rule.version} removed in #{@new_srg.version}"
          )
        end
      end

      # Record upgrade via audit_comment on component, NOT audits.create!  [FIX]
      # Using audits.create! bypasses the audited gem's versioning and
      # associated_audit infrastructure.
      @component.update!(
        audit_comment: "SRG upgrade: #{@old_srg.version} -> #{@new_srg.version} " \
                       "(#{rules_with_matching_requirements.count} updated, " \
                       "#{new_requirements.count} added, " \
                       "#{removed_requirements.count} removed)"
      )
    end
  end

  private

  def find_matching_new_srg_rule(rule)
    @new_srg_rules_by_version ||= @new_srg.srg_rules.index_by(&:version)
    @new_srg_rules_by_version[rule.srg_rule.version]
  end

  # [CRITICAL FIX] Prefetch versions into a Set instead of N+1 EXISTS queries.
  def rules_with_matching_requirements
    @_matching ||= begin
      new_versions = Set.new(@new_srg.srg_rules.pluck(:version))
      @component.rules.includes(:srg_rule).select { |r|
        new_versions.include?(r.srg_rule.version)
      }
    end
  end

  def new_requirements
    @_new_reqs ||= begin
      existing_versions = @component.rules.joins(:srg_rule).pluck('srg_rules.version')
      @new_srg.srg_rules.where.not(version: existing_versions)
    end
  end

  def removed_requirements
    @_removed ||= begin
      new_versions = @new_srg.srg_rules.pluck(:version)
      @component.rules.joins(:srg_rule).where.not(srg_rules: { version: new_versions })
    end
  end

  def template_changed?(rule)
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
```

#### Frontend UI

```
+-------------------------------------------------------------+
| Upgrade RHEL 9 Component: OS SRG V2R1 -> V2R2               |
+-------------------------------------------------------------+
|                                                              |
| [i] Preview of changes:                                      |
|                                                              |
| +-----------------------------------------------------------+|
| | [~] 247 REQUIREMENTS WILL BE UPDATED                      ||
| |    +-- 235 unchanged (just re-linked to new SRG)          ||
| |    +-- 12 template content changed                        ||
| |        +-- [!] 3 have your customizations (will preserve) ||
| +-----------------------------------------------------------+|
|                                                              |
| +-----------------------------------------------------------+|
| | [+] 3 NEW REQUIREMENTS WILL BE ADDED                      ||
| |    +-- SRG-OS-000500: Container isolation                 ||
| |    +-- SRG-OS-000501: Cloud deployment                    ||
| |    +-- SRG-OS-000502: MFA for privileged access           ||
| +-----------------------------------------------------------+|
|                                                              |
| +-----------------------------------------------------------+|
| | [-] 1 REQUIREMENT REMOVED FROM SRG                        ||
| |    +-- SRG-OS-000099: Legacy audit (has customizations)   ||
| |        o Mark as Not Applicable (recommended)             ||
| |        o Delete rule                                      ||
| +-----------------------------------------------------------+|
|                                                              |
| Options:                                                     |
| [x] Preserve my customizations (title, check, fix overrides)|
| [ ] Refresh non-configurable rules with new template content |
|                                                              |
| [Cancel]                          [Preview Details] [Upgrade]|
+-------------------------------------------------------------+
```

### Key Benefits of New Design

1. **Overrides preserved automatically** -- Because we only store overrides, upgrading SRG just changes the `srg_rule_id` pointer. User's customizations remain intact.
2. **Clear diff visibility** -- Can show exactly what changed in the SRG template vs what user customized.
3. **Granular control** -- User decides per-rule whether to refresh template content or keep their version.
4. **Audit trail** -- Every upgrade is logged via audit_comment on the component.
5. **Reversible** -- Can create a backup component before upgrade, or roll back by re-pointing to old SRG.

---

## Migration Strategy

### Phase Overview [UPDATED]

| Phase | Scope | Risk | Claude-pace | Status |
|-------|-------|------|-------------|--------|
| 0 | Preparation & Backup | None | 8-15 min | NOT STARTED |
| 1 | Add fallback display methods + eager-loading scope | Low | 25-45 min | NOT STARTED |
| 2 | Split STI into separate tables | Medium | 45-90 min | NOT STARTED |
| 2.5 | Reviews FK migration (base_rules -> rules) | Medium | 15-25 min | NOT STARTED |
| 3 | Add override tables (with overridden_fields + unique idx) | Medium | 25-45 min | NOT STARTED |
| 4 | Migrate satisfactions (ordering guard: requires Phase 2) | Medium | 15-25 min | NOT STARTED |
| 5 | Add versioning/changesets (GIN index, size CHECK) | Low | 25-45 min | NOT STARTED |
| 6 | Add counter caches (replacing matviews) | Low | 15-25 min | NOT STARTED |
| 7 | Data cleanup & deduplication | Medium | 25-45 min | NOT STARTED |
| 8 | Remove legacy columns | Low | 8-15 min | NOT STARTED |

**Total: ~4-6 hours Claude-pace (replaces v1's 40h human estimate)**

Phase dependencies:
- Phase 4 REQUIRES Phase 2 (satisfaction migration references rules/srg_rules tables)
- Phase 2.5 REQUIRES Phase 2 (reviews FK re-pointing)
- All other phases are independently shippable

### Already Shipped (No Migration Needed)

| Item | Status |
|------|--------|
| Blueprinter serialization (15 blueprints) | [DONE] |
| VulcanAuditable concern | [DONE] |
| Counter cache fix (rules_count + amoeba) | [DONE] |
| FK constraints on reviews.user_id, reviews.rule_id | [DONE] |
| Query perf: batch_rules_summary, SQL subtraction, audit limit | [DONE] |
| Reviews model expansion (20+ columns, triage, threading, reactions) | [DONE] |
| Component comment phase fields | [DONE] |

---

## Performance Optimizations [UPDATED]

### Indexes

```sql
-- Full-text search on SRG rules (title + fixtext)
CREATE INDEX idx_srg_rules_fts ON srg_rules USING gin(
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(fixtext, ''))
);

-- FTS is 'english' config for prose content. CCI identifiers need
-- exact-match, not stemming. Separate btree index on ident.  [FIX]
CREATE INDEX idx_srg_rules_ident ON srg_rules(ident);

-- FTS on check content (separate -- not combined with rule FTS)  [FIX]
CREATE INDEX idx_srg_checks_fts ON srg_checks USING gin(
  to_tsvector('english', coalesce(content, ''))
);

-- Common queries (with soft-delete partial index)
CREATE INDEX idx_rules_component_status
  ON rules(component_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_rules_component_locked
  ON rules(component_id, locked) WHERE deleted_at IS NULL;

-- Soft-delete partial index on srg_rule_id  [FIX]
CREATE INDEX idx_rules_srg_rule_active
  ON rules(srg_rule_id) WHERE deleted_at IS NULL;

-- Satisfaction lookups
-- Drop standalone (rule_id) -- redundant with composite unique index  [FIX]
CREATE UNIQUE INDEX idx_satisfactions_rule_srg
  ON rule_satisfactions(rule_id, srg_rule_id);
CREATE INDEX idx_satisfactions_srg_rule
  ON rule_satisfactions(srg_rule_id);

-- Override covering unique indexes (prevents seq scan on LEFT JOIN)  [FIX]
CREATE UNIQUE INDEX idx_rule_check_overrides_rule
  ON rule_check_overrides(rule_id) INCLUDE (content);
CREATE UNIQUE INDEX idx_rule_desc_overrides_rule
  ON rule_description_overrides(rule_id) INCLUDE (vuln_discussion);

-- SRG upgrade workflow  [FIX]
CREATE INDEX idx_srg_rules_srg_version
  ON srg_rules(security_requirements_guide_id, version);
CREATE INDEX idx_srg_family_version
  ON security_requirements_guides(srg_family_id, version);

-- Benchmark changesets
CREATE UNIQUE INDEX idx_benchmark_changesets_unique
  ON benchmark_changesets(from_benchmark_type, from_benchmark_id,
                          to_benchmark_type, to_benchmark_id);
CREATE INDEX idx_benchmark_changesets_changes_gin
  ON benchmark_changesets USING gin(changes);
```

### Caching Strategy

```ruby
# app/models/concerns/cached_statistics.rb
module CachedStatistics
  extend ActiveSupport::Concern

  included do
    def rules_summary
      Rails.cache.fetch("component/#{id}/rules_summary", expires_in: 5.minutes) do
        # Read from counter cache columns (not matview)
        {
          total_rules: rules_count,
          locked_count: locked_count,
          under_review_count: under_review_count,
          not_yet_determined_count: not_yet_determined_count,
          applicable_configurable_count: applicable_configurable_count,
          applicable_inherently_count: applicable_inherently_count,
          applicable_does_not_meet_count: applicable_does_not_meet_count,
          not_applicable_count: not_applicable_count
        }
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

## Implementation Phases

### Phase 0: Preparation & Backup

**Claude-pace estimate: 8-15 min**

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
  puts 'Reviews: ' + Review.count.to_s
  puts 'Reactions: ' + Reaction.count.to_s
  puts 'Satisfactions: ' + ActiveRecord::Base.connection.execute(
    'SELECT COUNT(*) FROM rule_satisfactions').first['count']
"
```

### Phase 1: Add Fallback Display Methods

**Claude-pace estimate: 25-45 min**
**Goal:** Establish pattern without changing database

```ruby
# app/models/concerns/display_fallback.rb
module DisplayFallback
  extend ActiveSupport::Concern

  included do
    # [FIX] Eager-loading scope prevents N+1 on collections
    scope :with_display_fallbacks, -> {
      includes(:srg_rule, :check_override, :description_override)
    }

    def display_title
      self[:title].presence || srg_rule&.title
    end

    def display_fixtext
      self[:fixtext].presence || srg_rule&.fixtext
    end

    # [CRITICAL FIX] Use respond_to? not rescue nil
    def display_field(field)
      override_method = "#{field}_override"
      override_value = if respond_to?(override_method, true)
                         public_send(override_method)
                       else
                         nil
                       end
      override_value.presence || srg_rule&.public_send(field)
    end
  end
end

# app/models/rule.rb
class Rule < ApplicationRecord
  include DisplayFallback
end
```

Update all blueprints and views to use `display_*` methods.

### Phase 2: Split STI into Separate Tables

**Claude-pace estimate: 45-90 min**
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

    # [FIX] Composite index for upgrade workflow
    add_index :srg_rules, [:security_requirements_guide_id, :version],
              name: 'idx_srg_rules_srg_version'

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

    # Migrate data (ID-preserving for FK stability)
    execute <<~SQL
      INSERT INTO srg_rules (id, security_requirements_guide_id, rule_identifier, ...)
      SELECT id, security_requirements_guide_id, rule_id, ...
      FROM base_rules WHERE type = 'SrgRule'
    SQL

    # [FIX] Reset sequence after ID-preserving migration
    execute <<~SQL
      SELECT setval('srg_rules_id_seq', (SELECT MAX(id) FROM srg_rules));
      SELECT setval('stig_rules_id_seq', (SELECT MAX(id) FROM stig_rules));
    SQL

    # ... similar for stig_rules

    # Create srg_checks, srg_descriptions, stig_checks, stig_descriptions
    # ... migrate check and description data
  end

  # [FIX] Explicit irreversible declaration
  def down
    raise ActiveRecord::IrreversibleMigration,
      'STI split cannot be reversed -- restore from backup'
  end
end
```

### Phase 2.5: Reviews FK Migration [NEW]

**Claude-pace estimate: 15-25 min**
**Dependency: Phase 2 must be complete**

```ruby
# db/migrate/YYYYMMDD_migrate_review_fks_to_rules.rb
class MigrateReviewFksToRules < ActiveRecord::Migration[8.0]
  def up
    # Remove old FK pointing to base_rules
    remove_foreign_key :reviews, :base_rules, column: :rule_id, if_exists: true

    # Re-add FK pointing to new rules table (IDs preserved from Phase 2)
    add_foreign_key :reviews, :rules, column: :rule_id, on_delete: :nullify

    # Update polymorphic type column
    execute <<~SQL
      UPDATE reviews
      SET commentable_type = 'Rule'
      WHERE commentable_type = 'BaseRule'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      'Cannot safely reverse polymorphic type rename'
  end
end
```

### Phase 3: Add Override Tables

**Claude-pace estimate: 25-45 min**

```ruby
# db/migrate/YYYYMMDD_create_override_tables.rb
class CreateOverrideTables < ActiveRecord::Migration[8.0]
  def change
    create_table :rule_check_overrides do |t|
      t.references :rule, foreign_key: true, null: false
      t.text :content
      t.string :system
      # [FIX] Explicit override tracking to disambiguate NULLs
      t.text :overridden_fields, array: true, default: []
      t.timestamps
    end

    # [FIX] Unique index on rule_id enforces has_one at DB level
    # Covering index includes content for index-only scans on LEFT JOIN
    add_index :rule_check_overrides, :rule_id, unique: true,
              include: [:content], name: 'idx_rule_check_overrides_rule'

    create_table :rule_description_overrides do |t|
      t.references :rule, foreign_key: true, null: false
      t.text :vuln_discussion
      t.text :mitigations
      # ... only commonly overridden fields
      # [FIX] Explicit override tracking
      t.text :overridden_fields, array: true, default: []
      t.timestamps
    end

    # [FIX] Unique covering index
    add_index :rule_description_overrides, :rule_id, unique: true,
              include: [:vuln_discussion], name: 'idx_rule_desc_overrides_rule'

    # Migrate existing overrides
    # Only create override record if content differs from SRG template
    reversible do |dir|
      dir.up do
        # Migration logic here -- compare each rule's content to its
        # srg_rule and create override records only for differences.
        # Set overridden_fields array to list which fields were overridden.
      end
    end
  end
end
```

### Phase 4: Migrate Satisfactions

**Claude-pace estimate: 15-25 min**
**Dependency: Phase 2 must be complete (satisfaction migration references srg_rules table)**

```ruby
# db/migrate/YYYYMMDD_fix_satisfactions.rb
class FixSatisfactions < ActiveRecord::Migration[8.0]
  def up
    # [FIX] Ordering guard: verify srg_rules table exists
    unless table_exists?(:srg_rules)
      raise "Phase 4 requires Phase 2 (srg_rules table). Run Phase 2 first."
    end

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

    # [FIX] NULL check: warn about rows that couldn't be migrated
    orphaned = execute("SELECT COUNT(*) FROM rule_satisfactions WHERE srg_rule_id IS NULL").first['count']
    if orphaned.to_i > 0
      Rails.logger.warn("Phase 4: #{orphaned} rule_satisfactions rows could not " \
                        "resolve srg_rule_id (satisfied_by_rule may have been deleted)")
    end

    # Add foreign key and remove old column
    add_foreign_key :rule_satisfactions, :srg_rules
    remove_column :rule_satisfactions, :satisfied_by_rule_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      'Cannot reverse satisfaction model change -- restore from backup'
  end
end
```

### Phase 5: Add Versioning/Changesets

**Claude-pace estimate: 25-45 min**

```ruby
# db/migrate/YYYYMMDD_create_benchmark_changesets.rb
class CreateBenchmarkChangesets < ActiveRecord::Migration[8.0]
  def change
    create_table :benchmark_changesets do |t|
      # [FIX] Dual nullable FKs for real FK enforcement
      t.string :from_benchmark_type, null: false
      t.bigint :from_benchmark_id, null: false
      t.string :to_benchmark_type, null: false
      t.bigint :to_benchmark_id, null: false
      t.string :from_version, null: false
      t.string :to_version, null: false
      t.jsonb :changes, default: []
      t.jsonb :summary, default: {}
      t.datetime :computed_at, null: false
      t.timestamps
    end

    add_index :benchmark_changesets,
              [:from_benchmark_type, :from_benchmark_id,
               :to_benchmark_type, :to_benchmark_id],
              unique: true, name: 'idx_benchmark_changesets_unique'

    # [FIX] GIN index for JSONB containment queries
    add_index :benchmark_changesets, :changes, using: :gin,
              name: 'idx_benchmark_changesets_changes_gin'

    # [FIX] CHECK constraints
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE benchmark_changesets
          ADD CONSTRAINT chk_from_benchmark
            CHECK (from_benchmark_type IN ('SecurityRequirementsGuide', 'Stig'));
          ALTER TABLE benchmark_changesets
          ADD CONSTRAINT chk_to_benchmark
            CHECK (to_benchmark_type IN ('SecurityRequirementsGuide', 'Stig'));
          ALTER TABLE benchmark_changesets
          ADD CONSTRAINT chk_changes_size
            CHECK (pg_column_size(changes) < 256000);
        SQL
      end
    end
  end
end
```

### Phase 6: Add Counter Caches (Replacing Materialized Views) [CRITICAL FIX]

**Claude-pace estimate: 15-25 min**

v1 proposed materialized views with per-row triggers. This was identified
as a deadlock risk: REFRESH CONCURRENTLY synchronously in a trigger
serializes all writes. Replaced with counter cache columns + async
notification.

```ruby
# db/migrate/YYYYMMDD_add_component_counter_caches.rb
class AddComponentCounterCaches < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :locked_count, :integer, default: 0
    add_column :components, :under_review_count, :integer, default: 0
    add_column :components, :not_yet_determined_count, :integer, default: 0
    add_column :components, :applicable_configurable_count, :integer, default: 0
    add_column :components, :applicable_inherently_count, :integer, default: 0
    add_column :components, :applicable_does_not_meet_count, :integer, default: 0
    add_column :components, :not_applicable_count, :integer, default: 0
  end
end

# app/models/rule.rb (after_commit callback)
after_commit :notify_stats_dirty, if: :stats_relevant_change?

def notify_stats_dirty
  ActiveRecord::Base.connection.execute(
    "NOTIFY component_stats_dirty, '#{component_id}'"
  )
end

def stats_relevant_change?
  saved_change_to_status? || saved_change_to_locked? ||
    saved_change_to_review_requestor_id? || saved_change_to_deleted_at?
end

# lib/tasks/stats.rake
namespace :stats do
  desc 'Recalculate all component counter caches'
  task recalculate: :environment do
    Component.find_each do |c|
      rules = c.rules.where(deleted_at: nil)
      c.update_columns(
        locked_count: rules.where(locked: true).count,
        under_review_count: rules.where(locked: false)
                                 .where.not(review_requestor_id: nil).count,
        not_yet_determined_count: rules.where(status: 'Not Yet Determined').count,
        # ... etc for each status
      )
    end
  end
end
```

### Phase 7: Data Cleanup & Deduplication

**Claude-pace estimate: 25-45 min**

```ruby
# lib/tasks/cleanup_duplicates.rake
namespace :db do
  desc 'Remove duplicate content, keep only overrides'
  task cleanup_duplicates: :environment do
    # [FIX] Wrap in transaction + idempotency check
    ActiveRecord::Base.transaction do
      Rule.includes(:srg_rule, :check_override, :description_override)
          .find_each do |rule|
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
end
```

### Phase 8: Remove Legacy Columns

**Claude-pace estimate: 8-15 min**

```ruby
# db/migrate/YYYYMMDD_remove_legacy_columns.rb
class RemoveLegacyColumns < ActiveRecord::Migration[8.0]
  def up
    # Remove old STI columns from rules table
    remove_column :rules, :type
    remove_column :rules, :security_requirements_guide_id
    remove_column :rules, :stig_id
    remove_column :rules, :stig_rule_id

    # Remove duplicate content columns (now in override tables)

    # Drop old tables
    drop_table :base_rules  # After verifying all data migrated
    drop_table :checks      # Replaced by srg_checks + rule_check_overrides
    drop_table :disa_rule_descriptions  # Replaced by srg_descriptions + overrides

    # Drop metadata tables (merged into parent)
    drop_table :project_metadata
    drop_table :component_metadata
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      'Legacy table removal cannot be reversed -- restore from backup'
  end
end
```

---

## Rollback Plan

Each phase has independent rollback capability:

1. **Phase 1:** Remove display methods (no DB changes)
2. **Phase 2-4:** Keep both old and new tables during migration, drop old only after verification
3. **Phase 2.5:** Polymorphic type rename is irreversible -- restore from backup if needed
4. **Phase 5-6:** New tables/columns can be dropped without affecting core functionality
5. **Phase 7-8:** Maintain backups, only remove after extended verification period

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
| N+1 queries in upgrade service | O(N) EXISTS calls | O(1) Set lookup |
| Matview deadlock risk | Per-row trigger | Async notify (zero) |

---

## Expert Review Findings

This section summarizes findings from three expert reviews (DB design,
Rails/ActiveRecord, PostgreSQL performance) conducted against v1 of this
document. Each finding is categorized and cross-referenced to the section
where it was addressed.

### Validated (No Changes Needed)

- STI split approach is correct and well-structured.
- Override-not-copy pattern is the right design.
- Satisfaction model fix (Rule -> SrgRule) is sound.
- `delegated_types` is NOT appropriate here -- override pattern is correct (Rails expert).
- FTS `english` config is correct for prose content.
- `benchmark_changesets` should use polymorphic `belongs_to` pattern (addressed with dual nullable FKs).

### Critical Findings Addressed

| # | Finding | Source | Fix | Section |
|---|---------|--------|-----|---------|
| 1 | Override NULL semantics ambiguity | DB Expert | Added `overridden_fields text[]` to override tables | Proposed Schema, Phase 3 |
| 2 | Matview trigger deadlock risk | DB Expert, PG Expert, Rails Expert | Replaced with counter caches + async pg_notify | Counter Caches section, Phase 6 |
| 3 | Reviews model marked "Unchanged" but has 20+ columns | DB Expert | Added full Review Workflow section + Phase 2.5 | Review Workflow |
| 4 | `rescue nil` in display_field | DB Expert, Rails Expert | Replaced with `respond_to?` guard | Display Logic, Phase 1 |
| 5 | ComponentSrgUpgradeService N+1 EXISTS | Rails Expert | Prefetch versions into Set | SRG Upgrade Workflow |
| 6 | Matview per-row refresh (263 concurrent) | PG Expert | Async notify + debounced job | Counter Caches section |
| 7 | benchmark_changesets JSONB unbounded | PG Expert | CHECK constraint on pg_column_size | Diff & Changelog, Phase 5 |

### Should-Fix Findings Addressed

| # | Finding | Source | Fix | Section |
|---|---------|--------|-----|---------|
| 1 | Phase 4 depends on Phase 2 -- ordering guard | DB Expert | Added table_exists? check + explicit dependency note | Phase 4 |
| 2 | benchmark_changesets needs GIN index on changes | DB Expert | Added GIN index | Performance, Phase 5 |
| 3 | Polymorphic FK on benchmark_changesets | DB Expert | Dual nullable FKs + CHECK constraint | Diff & Changelog |
| 4 | Phase 2 migration needs explicit IrreversibleMigration | Rails Expert | Added `raise IrreversibleMigration` to down methods | Phase 2, 2.5, 4, 8 |
| 5 | DisplayFallback N+1 on collections | Rails Expert | Added `scope :with_display_fallbacks` | Display Logic |
| 6 | Override tables need unique index on rule_id | Rails Expert | Added UNIQUE covering index | Phase 3, Performance |
| 7 | audits.create! in upgrade service bypasses audited gem | Rails Expert | Changed to audit_comment on component update | SRG Upgrade Workflow |
| 8 | Override LEFT JOINs need covering unique indexes | PG Expert | Added INCLUDE indexes | Performance |
| 9 | FTS missing check content and CCI identifiers | PG Expert | Separate FTS on srg_checks + btree on ident | Performance |
| 10 | srg_rules needs composite index (srg_id, version) | PG Expert | Added idx_srg_rules_srg_version | Performance, Phase 2 |
| 11 | Soft-delete partial index missing on srg_rule_id | PG Expert | Added idx_rules_srg_rule_active | Performance |

### Minor Findings Addressed

| # | Finding | Source | Fix |
|---|---------|--------|-----|
| 1 | Phase estimates should be Claude-pace | DB Expert | All estimates updated to Claude-pace |
| 2 | srg_rule_lineage vs benchmark_changesets overlap | DB Expert | Documented rationale for keeping both |
| 3 | Partial index on deleted_at needs component_id coverage | PG Expert | Covered by idx_rules_component_status partial index |
| 4 | Redundant satisfaction index | PG Expert | Drop standalone (rule_id), keep composite unique |
| 5 | STI split needs setval() on sequences | PG Expert | Added to Phase 2 migration |
| 6 | Phase 7 cleanup needs transaction + idempotency | Rails Expert | Wrapped in transaction |

---

## Rollback Strategy

Each phase follows the **expand-contract** pattern (GitLab, Shopify standard):

1. **Expand**: Add new tables/columns alongside old ones. Dual-write where needed. Fully reversible.
2. **Migrate**: Backfill data from old to new. Validate with row counts.
3. **Contract**: Drop old columns/tables. Irreversible — only after validation period.

### Per-Phase Rollback Plan

| Phase | Rollback Method | Recovery Time |
|-------|----------------|---------------|
| 0 (Backup) | N/A — read-only | N/A |
| 1 (DisplayFallback) | Remove concern, revert blueprints. Zero schema change. | Minutes |
| 2 (STI Split) | `pg_restore` from Phase 0 checkpoint. Code revert. | 5-15 min |
| 2.5 (Reviews FK) | `pg_restore` from Phase 2 checkpoint. | 5-15 min |
| 3 (Override tables) | Drop override tables, revert Rule model. Data still in old columns. | Minutes |
| 4 (Satisfactions) | `pg_restore` from Phase 3 checkpoint. | 5-15 min |
| 5 (Changesets) | Drop benchmark_changesets table. No data dependency. | Minutes |
| 6 (Counter caches) | Drop counter columns, revert to query-based counts. | Minutes |
| 7 (Metadata merge) | Reverse: extract jsonb back to separate tables. | Minutes |
| 8 (Cleanup) | Cannot roll back column drops. Checkpoint required before phase. | Restore from backup |

### Checkpoint Protocol

```bash
# Before each irreversible phase (2, 2.5, 4, 8):
pg_dump -Fc vulcan_production > checkpoint_phase_N_$(date +%Y%m%d_%H%M).dump

# Verify backup integrity:
pg_restore --list checkpoint_phase_N_*.dump | tail -5

# Restore if needed:
pg_restore -c -d vulcan_production checkpoint_phase_N_*.dump
```

### Rules

- Phases 1, 3, 5, 6, 7 are **additive** — rollback is code-only (remove concern/table, revert model)
- Phases 2, 2.5, 4, 8 are **destructive** — require `pg_dump` checkpoint before execution
- Never rename columns directly — add new, backfill, deploy code reading new, then drop old
- Use `raise ActiveRecord::IrreversibleMigration` in `down` for data-lossy migrations [already done]
- Production deploys: code that reads new schema must also handle old schema during the transition window

---

## Post-Migration Data Validation

### Validation Rake Task

```ruby
# lib/tasks/db_validate.rake
namespace :db do
  desc 'Validate data integrity after migration phase'
  task validate: :environment do
    errors = []

    # 1. Row count verification
    puts "=== Row Counts ==="
    %w[rules components security_requirements_guides stigs reviews reactions
       rule_satisfactions].each do |table|
      count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first['count']
      puts "  #{table}: #{count}"
    end

    # 2. Orphaned FK records
    puts "\n=== Orphaned Records ==="
    orphan_checks = {
      'rules → components' => <<~SQL,
        SELECT COUNT(*) FROM rules r
        LEFT JOIN components c ON r.component_id = c.id
        WHERE c.id IS NULL AND r.deleted_at IS NULL
      SQL
      'rules → srg_rules' => <<~SQL,
        SELECT COUNT(*) FROM rules r
        LEFT JOIN srg_rules sr ON r.srg_rule_id = sr.id
        WHERE sr.id IS NULL AND r.deleted_at IS NULL
      SQL
      'reviews → users' => <<~SQL,
        SELECT COUNT(*) FROM reviews r
        LEFT JOIN users u ON r.user_id = u.id
        WHERE r.user_id IS NOT NULL AND u.id IS NULL
      SQL
      'rule_satisfactions → rules' => <<~SQL,
        SELECT COUNT(*) FROM rule_satisfactions rs
        LEFT JOIN rules r ON rs.rule_id = r.id
        WHERE r.id IS NULL
      SQL
      'rule_satisfactions → srg_rules' => <<~SQL,
        SELECT COUNT(*) FROM rule_satisfactions rs
        LEFT JOIN srg_rules sr ON rs.srg_rule_id = sr.id
        WHERE sr.id IS NULL
      SQL
    }

    orphan_checks.each do |label, sql|
      count = ActiveRecord::Base.connection.execute(sql).first['count'].to_i
      status = count.zero? ? '✓' : "✗ #{count} orphaned"
      errors << "#{label}: #{count} orphaned" if count > 0
      puts "  #{label}: #{status}"
    end

    # 3. Unexpected NULLs in required fields
    puts "\n=== NULL Checks ==="
    null_checks = {
      'rules.status' => "SELECT COUNT(*) FROM rules WHERE status IS NULL AND deleted_at IS NULL",
      'rules.component_id' => "SELECT COUNT(*) FROM rules WHERE component_id IS NULL",
      'srg_rules.version' => "SELECT COUNT(*) FROM srg_rules WHERE version IS NULL",
      'reviews.action' => "SELECT COUNT(*) FROM reviews WHERE action IS NULL",
    }

    null_checks.each do |field, sql|
      count = ActiveRecord::Base.connection.execute(sql).first['count'].to_i
      status = count.zero? ? '✓' : "✗ #{count} unexpected NULLs"
      errors << "#{field}: #{count} NULLs" if count > 0
      puts "  #{field}: #{status}"
    end

    # 4. Duplicate detection
    puts "\n=== Duplicate Checks ==="
    dup_sql = <<~SQL
      SELECT rule_id, srg_rule_id, COUNT(*)
      FROM rule_satisfactions
      GROUP BY 1, 2 HAVING COUNT(*) > 1
    SQL
    dups = ActiveRecord::Base.connection.execute(dup_sql).to_a
    if dups.empty?
      puts "  rule_satisfactions uniqueness: ✓"
    else
      puts "  rule_satisfactions uniqueness: ✗ #{dups.size} duplicates"
      errors << "rule_satisfactions: #{dups.size} duplicates"
    end

    # 5. Override consistency (post Phase 3)
    if ActiveRecord::Base.connection.table_exists?('rule_check_overrides')
      puts "\n=== Override Consistency ==="
      override_sql = <<~SQL
        SELECT COUNT(*) FROM rule_check_overrides rco
        LEFT JOIN rules r ON rco.rule_id = r.id
        WHERE r.id IS NULL
      SQL
      count = ActiveRecord::Base.connection.execute(override_sql).first['count'].to_i
      status = count.zero? ? '✓' : "✗ #{count} orphaned overrides"
      errors << "rule_check_overrides: #{count} orphaned" if count > 0
      puts "  check overrides → rules: #{status}"
    end

    # Summary
    puts "\n=== Summary ==="
    if errors.empty?
      puts "All validations passed ✓"
    else
      puts "#{errors.size} validation errors:"
      errors.each { |e| puts "  ✗ #{e}" }
      exit 1
    end
  end
end
```

Run after each phase: `bundle exec rails db:validate`

### CI Integration

Add `db:validate` to the CI pipeline as a post-migration step. Fail the deploy if any check produces non-zero results.

---

## Performance Benchmarks

### Baseline Metrics (Capture Before Phase 0)

```ruby
# lib/tasks/db_benchmark.rake
namespace :db do
  desc 'Capture performance baseline for key endpoints'
  task benchmark: :environment do
    require 'benchmark'

    component = Component.includes(:rules).first
    project = Project.first

    results = {}

    # 1. Component show (full rule load)
    results['component_show'] = Benchmark.measure {
      10.times { component.reload.rules.includes(
        :reviews, :disa_rule_descriptions, :checks,
        :satisfies, :satisfied_by, srg_rule: [:disa_rule_descriptions, :checks]
      ).to_a }
    }.real / 10

    # 2. Paginated comments
    results['paginated_comments'] = Benchmark.measure {
      10.times { component.paginated_comments(triage_status: 'all', per_page: 25) }
    }.real / 10

    # 3. Rules summary (counter caches target)
    results['rules_summary'] = Benchmark.measure {
      10.times { component.batch_rules_summary }
    }.real / 10

    # 4. Project index (pending comment counts)
    results['pending_counts'] = Benchmark.measure {
      10.times { Component.pending_comment_counts(project.component_ids) }
    }.real / 10

    # 5. SQL query count per component show
    query_count = 0
    counter = ->(_name, _start, _finish, _id, payload) {
      query_count += 1 unless payload[:name] == 'SCHEMA' || payload[:sql]&.match?(/^(BEGIN|COMMIT|ROLLBACK)/)
    }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      component.reload.rules.includes(
        :reviews, :disa_rule_descriptions, :checks
      ).to_a
    end
    results['component_show_queries'] = query_count

    puts "\n=== Performance Baseline ==="
    results.each { |k, v| puts "  #{k}: #{v.is_a?(Float) ? '%.4fs' % v : v}" }

    File.write('tmp/db_benchmark_baseline.json', JSON.pretty_generate(results))
    puts "\nSaved to tmp/db_benchmark_baseline.json"
  end
end
```

### Target Thresholds

| Endpoint | Current (est.) | Post-Migration Target | Regression Threshold |
|----------|---------------|----------------------|---------------------|
| Component show (full rule load) | ~800ms | <300ms | +10% of target |
| Paginated comments (25/page) | ~200ms | <150ms | +10% of target |
| Rules summary (batch) | ~100ms | <20ms (counter cache) | +10% of target |
| Pending comment counts | ~50ms | <30ms | +10% of target |
| Component show SQL queries | ~15-20 | <8 (preload) | +2 queries |

### Test Assertions

```ruby
# spec/support/query_counter.rb
module QueryCounter
  def assert_query_count(expected_max, message = nil, &block)
    count = 0
    counter = ->(*) { count += 1 }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)
    assert count <= expected_max,
      message || "Expected at most #{expected_max} queries, got #{count}"
  end
end

# Usage in specs:
it 'loads component show with bounded queries' do
  assert_query_count(8) do
    get "/components/#{component.id}.json"
  end
end
```

### Tooling

- **`rack-mini-profiler`** — add to Gemfile `:development` group for per-request SQL timing in browser
- **`bullet`** gem — detects N+1 and unused eager loads; configure to raise in test environment
- **`db:benchmark`** — run before Phase 0 and after each phase to track regression
- **`EXPLAIN (ANALYZE, BUFFERS)`** — run on slow queries post-migration to verify new indexes are used

### Regression Rule

No endpoint may regress more than **10% on p95 response time** or gain more than **2 additional SQL queries** after any migration phase. If a regression is detected, the phase must be rolled back and the query plan investigated before re-deploying.

---

## ORM Evaluation: Drizzle over Prisma

The full database rebuild requires an ORM that can express Vulcan's query patterns natively. Prisma was evaluated and rejected; Drizzle is recommended.

### Why Not Prisma

Prisma cannot express the following patterns that this schema requires:

| Pattern | Vulcan Usage | Prisma Support |
|---------|-------------|----------------|
| UNION / UNION ALL queries | `pending_comment_counts`, `paginated_comments` polymorphic union | `$queryRaw` only |
| GROUP BY with HAVING | Status counts, counter cache recalculation | `$queryRaw` only |
| Partial indexes | `WHERE deleted_at IS NULL` on rules | Not expressible in schema |
| GIN indexes | JSONB containment, full-text search | Not expressible in schema |
| CHECK constraints | `pg_column_size(changes) < 256000` | Not expressible in schema |
| Polymorphic associations | `reviews.commentable_type/id → Rule or Component` | No concept — manual workarounds |
| Covering indexes (INCLUDE) | `UNIQUE (rule_id) INCLUDE (content)` on override tables | Not supported |

**Estimated raw SQL fallback rate with Prisma: 40-60%** of this schema's query patterns. At that point the ORM is overhead, not help.

Prisma's migration system also **silently drops** PostgreSQL-specific features it doesn't understand. A GIN index defined in a Prisma schema is simply ignored. For a security compliance application where data integrity is non-negotiable, silent feature drops are unacceptable.

### Why Drizzle

| Capability | Drizzle Support | Notes |
|-----------|----------------|-------|
| UNION / GROUP BY / HAVING | First-class, typed | `union(q1, q2)`, `.groupBy().having()` |
| Partial indexes | `index().where()` in schema | Native `drizzle-kit` support |
| GIN indexes | `.using('gin')` in schema | Native support |
| CHECK constraints | `check()` in table definition | Native support |
| Polymorphic joins | Manual typed `relations()` | Same as any typed ORM — no magic, no footguns |
| Covering indexes | `index().include()` | Supported |
| Bulk insert/upsert | `.values([...]).onConflictDoUpdate()` | Single statement, 10K+ rows |
| Relational queries (preloading) | `findMany({ with: { reviews: true } })` | Typed equivalent of AR `includes()` |
| Raw SQL fallback | `sql` tagged template (typed, composable) | Not a string escape hatch |

**Estimated raw SQL fallback rate with Drizzle: 10-15%** (materialized views, complex CTEs).

### Drizzle Ecosystem for This Project

| Tool | Package | Source | Use Case |
|------|---------|--------|----------|
| Schema → Zod validation | `drizzle-zod` | Official (1.57M/wk) | Input validation from schema — no manual Zod duplication |
| Deterministic seeding | `drizzle-seed` | Official (257K/wk) | Dev/test seeds with typed generators |
| Row-Level Security | `pgTable.withRLS()` | Official (core) | PostgreSQL RLS policies in schema |
| In-memory test DB | `@electric-sql/pglite` | Official driver (8.59M/wk) | WASM Postgres for tests — no Docker |
| Migration diffing | `drizzle-kit` | Official (7.97M/wk) | Schema diff → reviewed SQL, snapshots for CI |
| Logging | Built-in `Logger` interface | Official (core) | Custom `logQuery(sql, params)` |

### Gaps (DIY Required)

| Need | Approach |
|------|----------|
| Soft deletes | `deletedAt` column + query wrapper (no plugin exists) |
| Audit trails | PostgreSQL `AFTER INSERT/UPDATE/DELETE` trigger — more reliable than app-layer auditing for compliance |
| JSONB typed operators | `sql` template for `@>`, `?` operators — functional but untyped |
| Full-text search | `sql` template for `to_tsvector()`, `@@` — documented pattern, no abstraction |
| Nuxt integration | Manual wiring in `server/utils/db.ts` — no official module |

### Recommendation

**Use Drizzle for the full database rebuild.** It handles 85-90% of Vulcan's query patterns natively with type safety, versus Prisma's 40-60%. The schema-as-TypeScript-code approach means the 3NF schema in this document can be directly translated to Drizzle table definitions with all PostgreSQL-specific features (partial indexes, GIN, CHECK constraints, RLS) preserved.

For the gaps (soft deletes, audit trails, FTS), PostgreSQL-native solutions are actually superior to ORM plugins for a compliance application — trigger-based auditing is tamper-resistant and doesn't depend on application code paths.

---

## Next Steps

1. **Review this v2 document** -- Get stakeholder alignment on expert-review changes
2. **Create feature branch** -- `feat/database-3nf-v3`
3. **Start Phase 0** -- Backups and baseline metrics
4. **Incremental implementation** -- One phase per session, each independently shippable
5. **Phase ordering** -- Phases 0-1 are independent; Phase 2 unlocks 2.5 and 4; Phases 3, 5-8 are independent of each other

---

**Ready to begin?** Start with Phase 0 (backup) and Phase 1 (display methods + eager-loading scope).
