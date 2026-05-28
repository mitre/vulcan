# Vulcan Database Architecture: Current vs Proposed

**Created:** 2025-11-26
**Updated:** 2025-11-29
**Purpose:** Understand current data model and propose clean 3NF architecture

---

## Terminology

- **SRG** (Security Requirements Guide): DISA-published baseline requirements (e.g., "OS Core SRG" with 263 requirements)
- **STIG** (Security Technical Implementation Guide): Published implementation guidance for specific products
- **Component**: User's work-in-progress STIG (authored implementations of SRG requirements)
- **Rule**: A single security requirement/control implementation
- **Nesting/Consolidation**: When one authored control satisfies multiple SRG requirements

---

## Typical Usage Patterns

### Standard Case (RHEL, Windows, etc.)
- Component based on OS Core SRG (263 requirements)
- ~263 authored Rules (one per SRG requirement)
- **25-40 Rules have nesting** (one control satisfies 2-5 related requirements)
- ~220-240 Rules are 1:1 with SRG requirements

### Extreme Case (Container SRG) - OUTLIER
- 13 authored controls covering 251 requirements
- Most requirements "satisfied by underlying host OS"
- **This is NOT typical** - don't design around this edge case

---

## Current Database Schema

```
┌─────────────────────────────────────────────────────────────────┐
│ Projects                                                         │
│ - name, description, visibility                                 │
└────────────┬────────────────────────────────────────────────────┘
             │ has_many
             ▼
┌─────────────────────────────────────────────────────────────────┐
│ Components                                                       │
│ - name, prefix, version, release                                │
│ - security_requirements_guide_id (which SRG template)           │
│ - component_id (for overlays - optional)                        │
└────────────┬───────────────────────┬────────────────────────────┘
             │ has_many              │ belongs_to
             ▼                       ▼
┌─────────────────────────┐   ┌──────────────────────────────────┐
│ base_rules (STI)        │   │ SecurityRequirementsGuides       │
│ ==================      │   │ - srg_id, title, version         │
│ Type = "Rule"           │   │ - xml (full XCCDF)               │
│ - rule_id, version      │   └──────────────────────────────────┘
│ - title, fixtext        │               │ has_many
│ - status                │               ▼
│ - vendor_comments       │   ┌──────────────────────────────────┐
│ - srg_rule_id ──────────┼──▶│ base_rules (STI)                 │
│ - component_id          │   │ Type = "SrgRule"                 │
│                         │   │ - version (SRG-OS-000023)        │
│ Type = "StigRule"       │   │ - title, fixtext (templates)     │
│ - stig_id, vuln_id      │   │ - security_requirements_guide_id │
└─────────┬───────────────┘   └──────────────────────────────────┘
          │ has_many
          ▼
┌──────────────────────────────────────┐
│ disa_rule_descriptions               │
│ - vuln_discussion, mitigations       │
│ - false_positives, etc. (11 fields)  │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ checks                               │
│ - content (check text)               │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ rule_satisfactions (join table)      │
│ - rule_id                            │
│ - satisfied_by_rule_id               │
│ (Currently: Rule → Rule)             │
└──────────────────────────────────────┘
```

---

## Key Architecture Issues

### Issue 1: Template Content Duplication (3NF Violation)

**Current behavior on component creation:**
1. User creates Component based on SRG (263 requirements)
2. System copies ALL SRG content into new `Rule` records
3. Each Rule gets its own `checks` and `disa_rule_descriptions`
4. User modifies ~30% of content, leaving ~70% as duplicates of SRG templates

**The 3NF Violation:**
```
SrgRule #23:
  - title: "The system must enforce password complexity"
  - checks: [Check with content "Verify password settings..."]
  - disa_rule_descriptions: [Description with vuln_discussion "..."]

Rule #1 (in Component):
  - srg_rule_id: 23
  - title: "The system must enforce password complexity"  ← DUPLICATE
  - checks: [Check with content "Verify password settings..."]  ← DUPLICATE
  - disa_rule_descriptions: [Description with vuln_discussion "..."]  ← DUPLICATE
```

**Impact:**
- ~70% of Rule content is duplicated from SRG templates
- Storage bloat: O(components × requirements) instead of O(requirements)
- Update propagation: Fixing SRG typo doesn't fix copied Rules

### Issue 2: Satisfactions Link Rule → Rule (Should Be Rule → SrgRule)

**Current:**
```ruby
rule.satisfies     # Other Rules in same component
rule.satisfied_by  # Other Rules in same component
```

**Problem:** When nesting, we create "placeholder" Rules just to have something to link to.

**Example (current):**
```
Component has 264 Rules:
  - 13 authored controls (user's actual work)
  - 251 placeholder Rules (imported just for satisfaction links)

Satisfaction: Rule #5 → satisfies → Rule #200 (placeholder)
```

**Should be:**
```
Component has 263 Rules (user's implementations)

Satisfaction: Rule #5 → satisfies → SrgRule #200 (template, not duplicated)
```

### Issue 3: STI is Appropriate (Not a Problem)

The Single Table Inheritance for `Rule`, `SrgRule`, `StigRule` is **correct**:
- They share 90% of fields
- STI is the standard Rails pattern for this
- The issue is content duplication, not STI itself

---

## Proposed 3NF Architecture

### Core Principle: Store Overrides, Not Copies

```
┌─────────────────────────────────────────────────────────────────┐
│ SrgRule (TEMPLATE - read-only, shared across all components)    │
│ - version (SRG-OS-000023)                                       │
│ - title, fixtext (DEFAULT content)                              │
│ - has_many :checks (DEFAULT check content)                      │
│ - has_many :disa_rule_descriptions (DEFAULT vuln_discussion)    │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ belongs_to :srg_rule
                              │
┌─────────────────────────────────────────────────────────────────┐
│ Rule (USER'S IMPLEMENTATION - stores only overrides)            │
│ - belongs_to :component                                         │
│ - belongs_to :srg_rule (the requirement this implements)        │
│                                                                 │
│ OVERRIDE FIELDS (NULL = use SRG default):                       │
│ - title (NULL or user override)                                 │
│ - fixtext (NULL or user override)                               │
│                                                                 │
│ USER-SPECIFIC FIELDS (always on Rule):                          │
│ - status, vendor_comments, status_justification                 │
│ - inspec_control_body, artifact_description                     │
│                                                                 │
│ ASSOCIATED OVERRIDES:                                           │
│ - checks: only if user modified (else use srg_rule.checks)      │
│ - disa_rule_descriptions: only if modified                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ rule_satisfactions (for nesting - CHANGED)                      │
│ - rule_id (the primary control in component)                    │
│ - srg_rule_id (the SRG requirement it satisfies)               │
│                                                                 │
│ Example: RHEL SSH control satisfies 3 SRG requirements         │
│   rule_id=5 | srg_rule_id=23                                   │
│   rule_id=5 | srg_rule_id=24                                   │
│   rule_id=5 | srg_rule_id=25                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Display Logic (Fallback Pattern)

```ruby
class Rule < BaseRule
  belongs_to :srg_rule

  # Title with fallback to SRG template
  def display_title
    title.presence || srg_rule&.title
  end

  # Fixtext with fallback
  def display_fixtext
    fixtext.presence || srg_rule&.fixtext
  end

  # Check content with fallback
  def display_check_content
    checks.first&.content.presence || srg_rule&.checks&.first&.content
  end

  # Vuln discussion with fallback
  def display_vuln_discussion
    disa_rule_descriptions.first&.vuln_discussion.presence ||
      srg_rule&.disa_rule_descriptions&.first&.vuln_discussion
  end
end
```

---

## How This Works for Both Cases

### Typical Case: RHEL 9 STIG (25-40 nestings)

```
Component: RHEL 9 V1R1
  - 263 Rules (one per SRG requirement)
  - Each Rule.srg_rule_id points to its SRG requirement

Rule #1 (SSH Config):
  srg_rule_id: 23 (SRG-OS-000023)
  title: NULL (uses SRG default)
  fixtext: "Configure /etc/ssh/sshd_config..." (USER OVERRIDE)
  status: "Applicable - Configurable"
  checks: [user-authored check]

  # Nesting: this control also satisfies related requirements
  satisfies: [srg_rule_id: 24, srg_rule_id: 25]

Rule #2 (Password Length):
  srg_rule_id: 47
  title: NULL (uses SRG default)
  fixtext: NULL (uses SRG default - inherently meets)
  status: "Applicable - Inherently Meets"
  checks: [] (uses SRG default)
  satisfies: []

... 261 more Rules (most with NULL overrides, using SRG defaults)
```

### Extreme Case: Container SRG (high consolidation)

```
Component: Container SRG V1R1
  - 263 Rules (still one per SRG requirement)
  - Most have status "Not Applicable" (host handles it)

Rule #1 (No Direct Login):
  srg_rule_id: 23
  title: "Containers must not provide direct login..." (OVERRIDE)
  fixtext: "Configure container runtime..." (OVERRIDE)
  status: "Applicable - Configurable"

  # Heavy nesting: covers many requirements
  satisfies: [srg_rule_id: 24, 25, 26, ... 40 more]

Rule #2 through #251 (Host Inherits):
  srg_rule_id: various
  title: NULL
  fixtext: NULL
  status: "Not Applicable"
  vendor_comments: "Satisfied by underlying host OS"
  satisfies: []
```

---

## Comparison: Current vs Proposed

| Aspect | Current | Proposed 3NF |
|--------|---------|--------------|
| Template content | Copied to every Rule | Stored once in SrgRule, Rules store overrides |
| Typical component storage | 263 Rules × full content | 263 Rules × only overrides (~30% have content) |
| Satisfactions | Rule → Rule (same component) | Rule → SrgRule (reference to template) |
| SRG update propagation | Manual (copies don't update) | Automatic (NULL fields get new SRG values) |
| Nesting implementation | Create placeholder Rules | Link directly to SrgRule |

### Storage Efficiency Example

**RHEL 9 Component (263 requirements, ~30% customized):**

| Data | Current | Proposed |
|------|---------|----------|
| Rule records | 263 | 263 |
| checks records | 263 (all copied) | ~80 (only overrides) |
| disa_rule_descriptions | 263 (all copied) | ~80 (only overrides) |
| Total rows | ~789 | ~423 |

---

## Migration Path

### Phase 1: Add Fallback Logic (Non-Breaking)
1. Add `display_*` methods to Rule model
2. Update views/API to use `display_*` methods
3. No database changes yet

### Phase 2: Change Satisfactions Table
1. Add `srg_rule_id` column to `rule_satisfactions`
2. Migrate existing Rule → Rule links to Rule → SrgRule
3. Remove `satisfied_by_rule_id` column

### Phase 3: Clean Up Duplicate Content
1. For Rules where content matches SRG template, set to NULL
2. Remove orphaned checks/disa_rule_descriptions
3. Add validation: new Rules default to NULL (use template)

### Phase 4: Update Import/Export
1. Import creates Rules with NULL fields (template defaults)
2. Only store user overrides
3. Export still works (reads display_* methods)

---

## Decision Framework

**Do Phase 1 now (v2.3.0):**
- Low risk, no database changes
- Establishes pattern for future
- ~2-3 hours

**Do Phases 2-4 later (v2.4.0 or v3.0):**
- Requires careful data migration
- Should be done with full test coverage
- ~8-12 hours total

---

## Future Feature: Benchmark Diff/Changeset Architecture

### The Problem

Vulcan's core mission is lifecycle management of security guidance. When benchmarks evolve:

1. **Version-to-Version Changes**: V2R1 → V2R2 is really just a set of changes between requirements. The bulk of V2R2 is the same as V2R1.
2. **SRG Baseline Changes**: If a user wrote a STIG on Web SRG V1R2, but now V2R1 is released, they need to know how the SRG changed and how their Component needs adjustment.

Currently, users must manually diff XCCDF files or visually compare - there's no structured changeset tracking.

### Proposed Solution: Computed Changesets

```
┌─────────────────────────────────────────────────────────────────────┐
│  benchmark_changesets                                               │
│  - benchmark_type: "stig" | "srg"                                  │
│  - benchmark_id: integer (stig_id or srg_id)                       │
│  - from_version: string ("V2R1")                                   │
│  - to_version: string ("V2R2")                                     │
│  - computed_at: timestamp                                          │
│  - changes: jsonb [                                                │
│      { type: "added", rule_id: "SV-12345", title: "..." },        │
│      { type: "modified", rule_id: "SV-54321",                     │
│        fields: { fixtext: { old: "...", new: "..." } } },         │
│      { type: "removed", rule_id: "SV-99999", title: "..." }       │
│    ]                                                               │
│  - summary: jsonb { added: 3, modified: 12, removed: 1 }          │
└─────────────────────────────────────────────────────────────────────┘
```

### Materialized View: Cross-Version History

```sql
CREATE MATERIALIZED VIEW requirement_history AS
SELECT
  rule_id,
  benchmark_type,
  array_agg(version ORDER BY release_date) as versions,
  array_agg(title ORDER BY release_date) as title_history,
  first_version,
  last_version,
  times_modified
FROM srg_rules
GROUP BY rule_id, benchmark_type;

-- Queryable: "Show me the history of SRG-OS-000023 across all versions"
```

### Use Cases

1. **Import New Version** → Automatically compute diff from previous version
   - "RHEL 9 V2R2 has 3 new requirements, 12 modified, 1 removed"

2. **SRG Update Impact Analysis** → Show which Component rules need review
   - "Web SRG V2R1 changed these 15 requirements - your Component implementations may need updates"

3. **Audit Trail** → Historical view of requirement evolution
   - "SRG-OS-000023 was added in V1R1, modified in V1R3 and V2R1"

4. **Overlay Compatibility** → When overlaying another STIG
   - "The base STIG changed - here's what's different from your overlay source"

### Implementation Approach

**Phase 1: Compute on Import**
- When new STIG/SRG imported, find previous version
- Compute changeset and store in `benchmark_changesets`
- Show summary to user: "Imported V2R2 - 16 changes from V2R1"

**Phase 2: UI for Diff Viewing**
- Side-by-side diff view for individual requirements
- Summary page showing all changes between versions
- Filter by change type (added/modified/removed)

**Phase 3: Component Impact Analysis**
- "Your Component is based on SRG V1R2. V2R1 is now available."
- "These 8 SRG requirements changed - review these Component rules"
- Link directly to affected rules in Component editor

### PostgreSQL Efficiency

- JSONB column for changes (fast queries, flexible schema)
- Compute once at import time (not on every query)
- Materialized view refreshed on import
- GIN index on changes column for searching specific rule_ids

### Integration with 3NF Refactor

The changeset feature benefits from the 3NF refactor:
- With Rule → SrgRule links, we can directly query "which Rules reference changed SrgRules"
- No need to search through duplicated content
- Impact analysis becomes a simple join

---

## Appendix: Why STI is Correct

Single Table Inheritance for `Rule`, `SrgRule`, `StigRule` is appropriate because:

1. **Shared fields (90%):** title, fixtext, version, rule_severity, ident, etc.
2. **Shared associations:** checks, disa_rule_descriptions, references
3. **Polymorphic behavior:** All can be searched, displayed, exported similarly
4. **Rails convention:** STI is the standard pattern for this inheritance

The architecture issue is **content duplication**, not the STI pattern itself.

---

## See Also

- `docs-spa/DATABASE-SCHEMA-3NF.md` - Complete schema diagram with relationships
- `docs-spa/SEARCH-ABBREVIATIONS.md` - Search query transformation documentation

---

**Status:** Proposed architecture reviewed, awaiting implementation decision
