# Requirements Grouping by Focus Area

## Overview

This document describes the architecture for intelligently grouping requirements by their major security focus area to help users understand the scope of active requirements and areas under consideration.

---

## Current State: Data Already Available

The system already has the foundation for NIST-based grouping:

### 1. CCI Identifiers
Every rule has an `ident` field containing a CCI (Control Correlation Identifier):
- Example: `CCI-000015`, `CCI-000044`, `CCI-000048`

### 2. CCI-to-NIST Mapping
Located in `app/lib/cci_map/constants.rb`:
```ruby
CCI_TO_NIST_CONSTANT = {
  'CCI-000001' => 'AC-1 a 1',    # Access Control - Policy
  'CCI-000007' => 'AC-2 a',      # Access Control - Account Management
  'CCI-000015' => 'AC-2 (1)',    # Access Control - Automated Mgmt
  'CCI-000044' => 'AC-7 b',      # Access Control - Login Attempts
  'CCI-000048' => 'AC-8 a',      # Access Control - System Use
  # ... 1000+ mappings
}
```

### 3. Existing Model Method
`BaseRule#nist_control_family` already computes the NIST family from CCI:
```ruby
# app/models/base_rule.rb
def nist_control_family
  cci = ident&.gsub(/^CCI-0*/, '')
  CCI_MAP.dig(cci, 'nist') || 'Unknown'
end
```

---

## NIST Control Families Reference

| Code | Full Name | Typical Requirements |
|------|-----------|---------------------|
| **AC** | Access Control | Account management, session controls, permissions |
| **AU** | Audit and Accountability | Logging, audit trails, retention |
| **AT** | Awareness and Training | User training, security awareness |
| **CA** | Security Assessment | Assessments, authorizations, monitoring |
| **CM** | Configuration Management | Baseline configs, change control |
| **CP** | Contingency Planning | Backup, recovery, continuity |
| **IA** | Identification & Authentication | Passwords, MFA, certificates |
| **IR** | Incident Response | Detection, reporting, handling |
| **MA** | Maintenance | System maintenance procedures |
| **MP** | Media Protection | Media handling, sanitization |
| **PE** | Physical Protection | Physical access controls |
| **PL** | Planning | Security planning documentation |
| **PM** | Program Management | Security program oversight |
| **PS** | Personnel Security | Personnel screening, termination |
| **RA** | Risk Assessment | Risk identification, analysis |
| **SA** | System Acquisition | Acquisition policies, supply chain |
| **SC** | System & Comms Protection | Encryption, network security |
| **SI** | System & Info Integrity | Malware, patching, monitoring |

---

## Option A: NIST Family Grouping (Phase 2.x - Immediate)

Use existing NIST mapping directly. No database changes required.

### UI Mockup - Table View with Grouping

```
┌─────────────────────────────────────────────────────────────────┐
│ RHEL 9 STIG - Requirements                                       │
│ [📋 Table] [✏️ Focus]                                            │
├─────────────────────────────────────────────────────────────────┤
│ Group by: [NIST Family ▼]  Filter: [All ▼]  Search: [________]  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ▼ AC - Access Control (45 requirements)              [12/45 ✓]  │
│ ├─────────┬─────────────────────────────────┬──────┬──────────┤ │
│ │ Status  │ Title                           │ Sev  │ NIST     │ │
│ ├─────────┼─────────────────────────────────┼──────┼──────────┤ │
│ │ 🟢 Done │ Configure account lockout       │ CAT I│ AC-7     │ │
│ │ 🟡 WIP  │ Set session timeout             │ CAT II│ AC-11   │ │
│ │ ⚪ New  │ Disable guest accounts          │ CAT II│ AC-2    │ │
│ └─────────┴─────────────────────────────────┴──────┴──────────┘ │
│                                                                  │
│ ▼ AU - Audit and Accountability (32 requirements)    [8/32 ✓]   │
│ ├─────────┬─────────────────────────────────┬──────┬──────────┤ │
│ │ 🟢 Done │ Enable audit logging            │ CAT I│ AU-3     │ │
│ │ ⚪ New  │ Configure audit retention       │ CAT II│ AU-4    │ │
│ └─────────┴─────────────────────────────────┴──────┴──────────┘ │
│                                                                  │
│ ► CM - Configuration Management (28 requirements)    [0/28 ✓]   │
│ ► IA - Identification & Authentication (41 req)      [15/41 ✓]  │
│ ► SC - System & Comms Protection (35 requirements)   [5/35 ✓]   │
│ ► SI - System & Info Integrity (29 requirements)     [3/29 ✓]   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### UI Mockup - Summary Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│ Component Progress by Focus Area                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Access Control (AC)          ████████████░░░░░░░░  45/85  53%  │
│  Audit (AU)                   ██████████████░░░░░░  32/48  67%  │
│  Config Management (CM)       ████░░░░░░░░░░░░░░░░  12/62  19%  │
│  Identification (IA)          ██████████████████░░  41/52  79%  │
│  System Protection (SC)       ██████░░░░░░░░░░░░░░  18/55  33%  │
│  System Integrity (SI)        ████████████░░░░░░░░  29/44  66%  │
│                                                                  │
│  Overall Progress             ████████████░░░░░░░░  177/346 51% │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation Details

#### Backend: Add to Rules Serializer
```ruby
# app/serializers/rule_serializer.rb
def nist_family
  return nil unless object.ident.present?

  nist = object.nist_control_family
  return nil if nist == 'Unknown'

  # Extract family code (e.g., "AC-2 (1)" → "AC")
  nist.split('-').first
end

def nist_control
  object.nist_control_family
end
```

#### Frontend: Grouping Logic
```typescript
// composables/useRequirementsGrouping.ts
import { computed } from 'vue'
import type { Rule } from '@/types'

const NIST_FAMILIES = {
  AC: 'Access Control',
  AU: 'Audit and Accountability',
  AT: 'Awareness and Training',
  CA: 'Security Assessment',
  CM: 'Configuration Management',
  CP: 'Contingency Planning',
  IA: 'Identification & Authentication',
  IR: 'Incident Response',
  MA: 'Maintenance',
  MP: 'Media Protection',
  PE: 'Physical Protection',
  PL: 'Planning',
  PM: 'Program Management',
  PS: 'Personnel Security',
  RA: 'Risk Assessment',
  SA: 'System Acquisition',
  SC: 'System & Comms Protection',
  SI: 'System & Info Integrity',
} as const

export function useRequirementsGrouping(rules: Ref<Rule[]>) {
  const groupedByNist = computed(() => {
    const groups: Record<string, Rule[]> = {}

    for (const rule of rules.value) {
      const family = rule.nist_family || 'Unknown'
      if (!groups[family]) {
        groups[family] = []
      }
      groups[family].push(rule)
    }

    // Sort by family code
    return Object.entries(groups)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([code, rules]) => ({
        code,
        name: NIST_FAMILIES[code] || 'Unknown',
        rules,
        total: rules.length,
        completed: rules.filter(r => r.status === 'Applicable').length,
      }))
  })

  return { groupedByNist }
}
```

---

## Option B: Meta-Category Grouping (Phase 3 - Future)

Higher-level categories that combine related NIST families for business-friendly views.

### Proposed Meta-Categories

| Meta-Category | NIST Families | User-Friendly Description |
|--------------|---------------|---------------------------|
| **Identity & Access** | AC, IA | Who can access what |
| **Audit & Monitoring** | AU, SI | Logging and detection |
| **System Hardening** | CM, SC | Secure configuration |
| **Data Protection** | MP, SC | Protecting data at rest/transit |
| **Operations** | MA, IR, CP | Day-to-day security ops |
| **Governance** | PL, PM, RA, CA | Planning and oversight |
| **Personnel** | AT, PS | People-related controls |
| **Physical** | PE | Physical security |

### UI Mockup - Meta-Category View

```
┌─────────────────────────────────────────────────────────────────┐
│ Component Progress by Security Domain                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│ │ 🔐 Identity &   │  │ 📊 Audit &      │  │ 🛡️ System       │   │
│ │    Access       │  │    Monitoring   │  │    Hardening    │   │
│ │                 │  │                 │  │                 │   │
│ │   86 reqs       │  │   80 reqs       │  │   90 reqs       │   │
│ │   ████████░░    │  │   ██████████    │  │   ████░░░░░░    │   │
│ │   65% complete  │  │   85% complete  │  │   32% complete  │   │
│ │                 │  │                 │  │                 │   │
│ │ [View Details]  │  │ [View Details]  │  │ [View Details]  │   │
│ └─────────────────┘  └─────────────────┘  └─────────────────┘   │
│                                                                  │
│ ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│ │ 💾 Data         │  │ ⚙️ Operations   │  │ 📋 Governance   │   │
│ │    Protection   │  │                 │  │                 │   │
│ │   45 reqs       │  │   35 reqs       │  │   30 reqs       │   │
│ │   ██████░░░░    │  │   ████████░░    │  │   ██████████    │   │
│ │   48% complete  │  │   72% complete  │  │   90% complete  │   │
│ └─────────────────┘  └─────────────────┘  └─────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Database Schema (Future)

```sql
-- Optional: Store meta-category mappings
CREATE TABLE focus_areas (
  id SERIAL PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  icon VARCHAR(50),
  display_order INTEGER DEFAULT 0
);

CREATE TABLE focus_area_nist_mappings (
  id SERIAL PRIMARY KEY,
  focus_area_id INTEGER REFERENCES focus_areas(id),
  nist_family VARCHAR(5) NOT NULL,
  UNIQUE(focus_area_id, nist_family)
);

-- Seed data
INSERT INTO focus_areas (code, name, icon, display_order) VALUES
  ('identity', 'Identity & Access', 'bi-key', 1),
  ('audit', 'Audit & Monitoring', 'bi-graph-up', 2),
  ('hardening', 'System Hardening', 'bi-shield-check', 3),
  ('data', 'Data Protection', 'bi-database-lock', 4),
  ('operations', 'Operations', 'bi-gear', 5),
  ('governance', 'Governance', 'bi-clipboard-check', 6);

INSERT INTO focus_area_nist_mappings (focus_area_id, nist_family) VALUES
  (1, 'AC'), (1, 'IA'),           -- Identity & Access
  (2, 'AU'), (2, 'SI'),           -- Audit & Monitoring
  (3, 'CM'), (3, 'SC'),           -- System Hardening
  (4, 'MP'),                       -- Data Protection
  (5, 'MA'), (5, 'IR'), (5, 'CP'), -- Operations
  (6, 'PL'), (6, 'PM'), (6, 'RA'), (6, 'CA'); -- Governance
```

---

## Implementation Phases

### Phase 2.x: Option A - NIST Family Grouping
**Scope**: Use existing data, minimal changes

1. **Backend** (2-3 hours)
   - Add `nist_family` and `nist_control` to rule serializer
   - Add tests

2. **Frontend** (4-6 hours)
   - Create `useRequirementsGrouping` composable
   - Add "Group by" dropdown to RequirementsToolbar
   - Implement collapsible group headers in table
   - Add group progress indicators

3. **Testing** (2 hours)
   - Frontend composable tests
   - Integration tests

**Total: ~8-11 hours**

### Phase 3: Option B - Meta-Categories
**Scope**: Database + configurable groupings

1. **Database** (2 hours)
   - Migration for focus_areas tables
   - Seed data

2. **Backend** (4 hours)
   - FocusArea model and associations
   - API endpoints for focus areas
   - Add to rule serializer

3. **Frontend** (8 hours)
   - Dashboard summary view
   - Card-based meta-category display
   - Drill-down from meta-category to NIST family to rules

4. **Admin UI** (4 hours - optional)
   - Allow admins to customize meta-categories
   - Drag-and-drop NIST family assignment

**Total: ~14-18 hours**

---

## API Response Changes

### Current Rule Response
```json
{
  "id": 123,
  "rule_id": "SV-230221r858734_rule",
  "title": "RHEL 9 must enable audit logging",
  "rule_severity": "high",
  "status": "Applicable - Configurable",
  "ident": "CCI-000169"
}
```

### Enhanced Rule Response (Option A)
```json
{
  "id": 123,
  "rule_id": "SV-230221r858734_rule",
  "title": "RHEL 9 must enable audit logging",
  "rule_severity": "high",
  "status": "Applicable - Configurable",
  "ident": "CCI-000169",
  "nist_family": "AU",
  "nist_control": "AU-3"
}
```

### Enhanced Rule Response (Option B)
```json
{
  "id": 123,
  "rule_id": "SV-230221r858734_rule",
  "title": "RHEL 9 must enable audit logging",
  "rule_severity": "high",
  "status": "Applicable - Configurable",
  "ident": "CCI-000169",
  "nist_family": "AU",
  "nist_control": "AU-3",
  "focus_area": {
    "code": "audit",
    "name": "Audit & Monitoring"
  }
}
```

---

## Files to Modify

### Option A (NIST Grouping)
- `app/serializers/rule_serializer.rb` - Add nist_family, nist_control
- `app/javascript/composables/useRequirementsGrouping.ts` - New file
- `app/javascript/components/requirements/RequirementsToolbar.vue` - Add dropdown
- `app/javascript/components/requirements/RequirementsTable.vue` - Group rendering
- `spec/serializers/rule_serializer_spec.rb` - Tests
- `app/javascript/composables/__tests__/useRequirementsGrouping.spec.ts` - Tests

### Option B (Meta-Categories) - Future
- `db/migrate/xxx_create_focus_areas.rb` - Migration
- `app/models/focus_area.rb` - Model
- `app/serializers/focus_area_serializer.rb` - Serializer
- `app/controllers/api/focus_areas_controller.rb` - API
- `app/javascript/apis/focusAreas.api.ts` - Frontend API
- `app/javascript/stores/focusAreas.store.ts` - Store
- `app/javascript/components/dashboard/FocusAreaCards.vue` - UI

---

## Related Documentation

- `CONTROLS-PAGE-LAYOUTS.md` - Table/Focus view layouts
- `REQUIREMENTS-EDITOR-IMPLEMENTATION-PLAN.md` - Phased implementation
- `PINIA-ARCHITECTURE.md` - Store patterns
