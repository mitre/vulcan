# Vulcan Database Schema (Proposed 3NF)

**Status:** Proposed for v2.4.0 or v3.0
**Related:** See `DATABASE-ARCHITECTURE-CURRENT-VS-PROPOSED.md` for migration plan

---

## Schema Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    VULCAN 3NF SCHEMA                                     │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   CONTAINER HIERARCHY                                    │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────┐
│ Projects                │
│─────────────────────────│
│ id                      │
│ name                    │
│ description             │
│ visibility              │
└───────────┬─────────────┘
            │ has_many
            ▼
┌─────────────────────────┐      ┌─────────────────────────┐
│ Components              │      │ SecurityRequirements    │
│ (STIG in progress)      │      │ Guides (SRG)            │
│─────────────────────────│      │─────────────────────────│
│ id                      │      │ id                      │
│ project_id        ──────┼──┐   │ srg_id                  │
│ srg_id            ──────┼──┼──▶│ title                   │
│ name                    │  │   │ version                 │
│ prefix                  │  │   │ xml                     │
│ version                 │  │   │ release_date            │
│ release                 │  │   └───────────┬─────────────┘
│ title                   │  │               │ has_many
│ description             │  │               ▼
│ released                │  │   ┌─────────────────────────┐
│ component_id (overlay)  │  │   │ SrgRule (TEMPLATE)      │
└───────────┬─────────────┘  │   │ [Read-only, shared]     │
            │ has_many       │   │─────────────────────────│
            ▼                │   │ id                      │
┌─────────────────────────┐  │   │ srg_id            ──────┼──┐
│ Rule                    │  │   │ version (SRG-OS-000023) │  │
│ (USER IMPLEMENTATION)   │  │   │ title                   │  │
│─────────────────────────│  │   │ fixtext                 │  │
│ id                      │  │   │ rule_severity           │  │
│ component_id      ──────┼──┘   │ ident                   │  │
│ srg_rule_id       ──────┼─────▶│ (template content)      │  │
│                         │      └───────────┬─────────────┘  │
│ OVERRIDES (NULL=default)│                  │                │
│ ────────────────────────│                  │                │
│ title                   │                  │                │
│ fixtext                 │                  │                │
│                         │                  │                │
│ USER-SPECIFIC FIELDS    │                  │                │
│ ────────────────────────│                  │                │
│ status                  │                  │                │
│ vendor_comments         │                  │                │
│ status_justification    │                  │                │
│ artifact_description    │                  │                │
│ inspec_control_body     │                  │                │
│ rule_id (component ID)  │                  │                │
└───────────┬─────────────┘                  │                │
            │                                │                │
            │ has_many (OVERRIDE)            │ has_many       │
            ▼                                ▼                │
┌─────────────────────────┐      ┌─────────────────────────┐  │
│ Check                   │      │ Check                   │  │
│ (user override)         │      │ (SRG template)          │  │
│─────────────────────────│      │─────────────────────────│  │
│ id                      │      │ id                      │  │
│ base_rule_id (Rule)     │      │ base_rule_id (SrgRule)  │  │
│ content                 │      │ content                 │  │
└─────────────────────────┘      └─────────────────────────┘  │
                                                              │
┌─────────────────────────┐      ┌─────────────────────────┐  │
│ DisaRuleDescription     │      │ DisaRuleDescription     │  │
│ (user override)         │      │ (SRG template)          │  │
│─────────────────────────│      │─────────────────────────│  │
│ id                      │      │ id                      │  │
│ base_rule_id (Rule)     │      │ base_rule_id (SrgRule)  │  │
│ vuln_discussion         │      │ vuln_discussion         │  │
│ mitigations             │      │ mitigations             │  │
│ ...                     │      │ ...                     │  │
└─────────────────────────┘      └─────────────────────────┘  │
                                                              │
                                                              │
┌─────────────────────────────────────────────────────────────┘
│
│  SATISFACTION RELATIONSHIPS (Nesting)
│
▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ rule_satisfactions                                                                       │
│─────────────────────────────────────────────────────────────────────────────────────────│
│ rule_id           ──▶ Rule (the authored control that covers multiple requirements)     │
│ srg_rule_id       ──▶ SrgRule (the SRG requirement being satisfied)                     │
│                                                                                          │
│ Example: SSH config control satisfies 3 SRG requirements                                │
│ ┌──────────┬─────────────┐                                                              │
│ │ rule_id  │ srg_rule_id │                                                              │
│ ├──────────┼─────────────┤                                                              │
│ │    5     │     23      │  Rule #5 satisfies SRG-OS-000023                             │
│ │    5     │     24      │  Rule #5 satisfies SRG-OS-000024                             │
│ │    5     │     25      │  Rule #5 satisfies SRG-OS-000025                             │
│ └──────────┴─────────────┘                                                              │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Published STIGs (Reference Only)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                  PUBLISHED STIGS (Reference)                             │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────┐
│ Stig                    │
│ (Published guidance)    │
│─────────────────────────│
│ id                      │
│ stig_id                 │
│ title                   │
│ name                    │
│ version                 │
│ xml                     │
│ benchmark_date          │
└───────────┬─────────────┘
            │ has_many
            ▼
┌─────────────────────────┐
│ StigRule                │
│ (Published controls)    │
│─────────────────────────│
│ id                      │
│ stig_id                 │
│ version                 │
│ vuln_id                 │
│ srg_id (reference)      │
│ title                   │
│ fixtext                 │
│ (full content - frozen) │
└───────────┬─────────────┘
            │ has_many
            ▼
┌─────────────────────────┐
│ Check / DisaRuleDesc    │
│ (full published content)│
└─────────────────────────┘
```

---

## Membership & Authorization

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    MEMBERSHIP & AUTH                                     │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────┐
│ Users                   │
│─────────────────────────│
│ id                      │
│ email                   │
│ name                    │
│ admin                   │
└───────────┬─────────────┘
            │
            │ has_many
            ▼
┌─────────────────────────┐
│ Memberships             │
│ (polymorphic)           │
│─────────────────────────│
│ id                      │
│ user_id                 │
│ membership_type         │──▶ 'Project' or 'Component'
│ membership_id           │──▶ project.id or component.id
│ role                    │──▶ 'admin', 'author', 'viewer'
└─────────────────────────┘
```

---

## STI Summary (base_rules table)

| type | Purpose | Parent FK | Content Pattern |
|------|---------|-----------|-----------------|
| SrgRule | SRG template (read-only, shared) | security_requirements_guide_id | Full (shared) |
| Rule | User implementation (authored) | component_id + srg_rule_id | Overrides only (NULL = use SRG) |
| StigRule | Published STIG (reference) | stig_id | Full (frozen) |

---

## Key Relationships

| From | Relationship | To | Purpose |
|------|--------------|-----|---------|
| Project | has_many | Components | Container hierarchy |
| Component | belongs_to | SRG | Which SRG template used |
| Component | has_many | Rules | User's implementations |
| Rule | belongs_to | SrgRule | Primary requirement (1:1) |
| Rule | has_many through satisfactions | SrgRule | Additional requirements covered (nesting) |
| SRG | has_many | SrgRules | Template requirements |
| Stig | has_many | StigRules | Published reference |

---

## Display Logic (Fallback Pattern)

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

## Typical Usage Patterns

### Standard Case (RHEL, Windows, etc.)
- Component based on OS Core SRG (263 requirements)
- ~263 Rules (one per SRG requirement)
- **25-40 Rules have nesting** (one control satisfies 2-5 related requirements)
- ~30% of Rules have overrides, ~70% use SRG defaults (NULL fields)

### Extreme Case (Container SRG) - OUTLIER
- Still 263 Rules (one per SRG requirement)
- 13 authored controls with heavy nesting (each satisfies many requirements)
- Most Rules have status "Not Applicable" with vendor_comments "Satisfied by host"
- **Don't design around this edge case**

---

## Storage Efficiency

**RHEL 9 Component (263 requirements, ~30% customized):**

| Data | Current (Copies) | Proposed (Overrides) |
|------|------------------|----------------------|
| Rule records | 263 | 263 |
| checks records | 263 (all copied) | ~80 (only overrides) |
| disa_rule_descriptions | 263 (all copied) | ~80 (only overrides) |
| Total rows | ~789 | ~423 |

---

## See Also

- `DATABASE-ARCHITECTURE-CURRENT-VS-PROPOSED.md` - Migration plan and decision framework
- `VULCAN-STANDARDIZATION-PLAN.md` - Terminology standardization
