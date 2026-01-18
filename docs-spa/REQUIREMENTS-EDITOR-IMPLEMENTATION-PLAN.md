# Requirements Editor - Implementation Plan

**Reference Design:** `docs-spa/REQUIREMENTS-EDITOR-FINAL-DESIGN.md`
**Principle:** Fast AND Correct - no shortcuts that break patterns

---

## Phase Overview

| Phase | Focus | Dependencies | Est. Effort |
|-------|-------|--------------|-------------|
| **1** | Enhanced Table View | None | Foundation |
| **2** | Focus View Refactor | Phase 1 | Core editor |
| **2.x** | NIST Family Grouping | Phase 1 | ~8-11 hours |
| **3** | Reference Panel | Phase 2 | Key feature |
| **3.x** | Meta-Category Grouping | Phase 2.x | ~14-18 hours |
| **4** | Field-Level Locking | Phase 2 | Backend + Frontend |
| **5** | Review Integration | Phase 4 | Workflow |
| **6** | Automation Panel | Phase 2 | Future feature |

**Architecture Docs:**
- `docs-spa/REQUIREMENTS-GROUPING-ARCHITECTURE.md` - NIST/Meta-category grouping details

---

## Phase 1: Enhanced Table View

**Goal**: Make Table View the "command center" for triage and overview.

### 1.1 Summary Cards
- Create `SummaryCards.vue` component
- Cards: Pending Review, Recently Changed, Changes Requested, Locked count
- Click card → applies filter to table
- Use existing `useRules` composable for data

### 1.2 Lock Progress Column
- Add lock progress indicator to table (🔒🔒🔓🔓)
- Create `LockProgress.vue` component
- Display 0/4 to 4/4 progress

### 1.3 Review Status Column
- Show review state: Pending, Changes Requested, Approved, None
- Badge with requestor name

### 1.4 Satisfies Column & Card
- Add Satisfies indicator to table: `→3` (satisfies 3) or `←1` (satisfied by 1)
- Create `SatisfiesIndicator.vue` component
- Add "Satisfies Others" Summary Card with click-to-filter
- Show satisfied-by rules are "merged" (status auto-set to Applicable-Configurable)

### 1.5 Enhanced Filters
- Add filter options: Lock Status, Review Status, Satisfies Status
- Extend `RequirementsToolbar.vue`
- Satisfies filters: "Satisfies Others", "Satisfied By", "No Satisfaction"

### 1.6 Bulk Satisfaction Actions
- Extend bulk selection for satisfaction operations
- Action: "Mark Selected as Satisfied By..." → opens SatisfiesSlideout
- Action: "Remove Satisfaction" for satisfied rules
- Multi-select checkbox support (existing pattern from RuleSatisfactions.vue)

### 1.7 Collapsible Status Groups
- Already have `groupByStatus` - enhance with collapse/expand
- Show count per group
- Remember collapse state

**Tests Required:**
- SummaryCards.spec.ts
- LockProgress.spec.ts
- SatisfiesIndicator.spec.ts
- Filter integration tests
- Bulk satisfaction tests

---

## Phase 2: Focus View Refactor

**Goal**: Restructure Focus View for the new layout.

### 2.1 Smart Header
- Create `FocusHeader.vue`
- Shows: Component name, progress bar, filter, current rule, nav arrows
- [Table | Focus] toggle

### 2.2 Editor Fields Component
- Create `EditorField.vue` - reusable field container
- Props: label, locked, lockable, expandable
- Slots: content, actions
- Handles expand modal trigger

### 2.3 Field Expand Modal
- Create `FieldExpandModal.vue`
- Full-screen editing experience
- Character count, auto-save indicator

### 2.4 Slideout Infrastructure
- Use Reka UI Dialog for slideouts
- Create `SlideoutPanel.vue` wrapper
- Standardize slideout behavior

### 2.5 Keyboard Navigation
- Implement j/k navigation in Focus view
- Cmd+S save, Cmd+E expand, Cmd+J jump
- Create `useKeyboardNav` composable

**Tests Required:**
- EditorField.spec.ts
- FieldExpandModal.spec.ts
- useKeyboardNav.spec.ts

---

## Phase 2.x: NIST Family Grouping

**Goal**: Group requirements by security focus area using existing NIST control family data.
**Reference**: `docs-spa/REQUIREMENTS-GROUPING-ARCHITECTURE.md`

### 2.x.1 Backend: Add NIST Fields to Serializer
- Add `nist_family` (2-char code: AC, AU, CM, etc.)
- Add `nist_control` (full control: AC-2, AU-3, etc.)
- Extract from existing `nist_control_family` method
- Add tests to `rule_serializer_spec.rb`

### 2.x.2 Frontend: Grouping Composable
- Create `useRequirementsGrouping.ts`
- `groupedByNist` computed property
- NIST family name mapping (AC → "Access Control")
- Group statistics (total, completed per group)

### 2.x.3 UI: Group By Dropdown
- Add "Group by" dropdown to `RequirementsToolbar.vue`
- Options: None, NIST Family, Severity, Status
- Persist selection in localStorage

### 2.x.4 UI: Collapsible Group Headers
- Modify `RequirementsTable.vue` for grouped rendering
- Collapsible group headers with count/progress
- Remember expand/collapse state

### 2.x.5 UI: Group Progress Indicators
- Show progress per group (12/45 ✓)
- Visual progress bar in header
- Filter to specific group on click

**Tests Required:**
- rule_serializer_spec.rb (nist fields)
- useRequirementsGrouping.spec.ts
- Table grouping integration tests

---

## Phase 3: Reference Panel

**Goal**: Side-by-side reference with scroll-spy sync.

### 3.1 Reference Panel Container
- Create `ReferencePanel.vue`
- Collapsible (Cmd+R toggle)
- Remember state in localStorage

### 3.2 Reference Tabs
- Create `ReferenceTabs.vue`
- Switch between 1-2 primary reference STIGs
- Tab UI component

### 3.3 Scroll-Spy Sync
- Create `useScrollSpy` composable
- Sync reference panel to current editor field
- Highlight active section

### 3.4 Copy to Editor
- Create `CopyButton.vue`
- Smart copy: replace if empty, append if has content
- Toast feedback

### 3.5 More References Slideout
- Port `RelatedRulesModal.vue` to Composition API
- Use slideout pattern instead of modal
- Filter by STIG/Component

### 3.6 Primary Reference STIGs
- Backend: Add `primary_reference_stig_ids` to Component
- API: GET/PUT primary references
- UI: Set primary in More References slideout

### 3.7 Smart Satisfaction Suggestions
- When viewing reference, show satisfaction hints from primary STIGs
- "This reference rule satisfies 4 SRG requirements"
- Highlight shared SRG IDs between current rule and reference
- Button: "Apply similar satisfactions" → opens confirmation dialog
- Hybrid approach: Suggest candidates, require user confirmation

### 3.8 Satisfies Slideout
- Create `SatisfiesPanel.vue` (Reka UI slideout, consistent with other panels)
- Port from `RuleSatisfactions.vue` to Composition API
- Shows: "Also Satisfies" list, "Satisfied By" info
- Add satisfaction: search/select rule from same component
- Remove satisfaction with confirmation
- Multi-select support for bulk add

**Tests Required:**
- ReferencePanel.spec.ts
- useScrollSpy.spec.ts
- RelatedRulesPanel.spec.ts
- SatisfiesPanel.spec.ts
- Smart suggestion tests

---

## Phase 3.x: Meta-Category Grouping (Future)

**Goal**: Higher-level business-friendly groupings that combine related NIST families.
**Reference**: `docs-spa/REQUIREMENTS-GROUPING-ARCHITECTURE.md`

### 3.x.1 Database: Focus Areas Tables
```ruby
create_table :focus_areas do |t|
  t.string :code, null: false
  t.string :name, null: false
  t.text :description
  t.string :icon
  t.integer :display_order, default: 0
  t.timestamps
end

create_table :focus_area_nist_mappings do |t|
  t.references :focus_area, null: false
  t.string :nist_family, null: false
  t.timestamps
end
```

### 3.x.2 Seed Data: Default Meta-Categories
| Meta-Category | NIST Families |
|--------------|---------------|
| Identity & Access | AC, IA |
| Audit & Monitoring | AU, SI |
| System Hardening | CM, SC |
| Data Protection | MP |
| Operations | MA, IR, CP |
| Governance | PL, PM, RA, CA |

### 3.x.3 Backend: FocusArea Model & API
- Create `FocusArea` model with NIST mappings
- API: GET /api/focus_areas
- Add `focus_area` to rule serializer (derived from nist_family)

### 3.x.4 Frontend: Dashboard Summary View
- Create `FocusAreaDashboard.vue`
- Card-based display per meta-category
- Progress indicators per category
- Click to drill down to NIST families

### 3.x.5 Admin UI (Optional)
- Allow admins to customize meta-categories
- Drag-and-drop NIST family assignment
- Add/remove categories

**Tests Required:**
- focus_area_spec.rb
- FocusAreaDashboard.spec.ts
- API integration tests

---

## Phase 4: Field-Level Locking

**Goal**: Lock individual fields for SRG workflow.

### 4.1 Database Migration
```ruby
add_column :rules, :title_locked_at, :datetime
add_column :rules, :title_locked_by_id, :bigint
add_column :rules, :vuln_discussion_locked_at, :datetime
add_column :rules, :vuln_discussion_locked_by_id, :bigint
add_column :rules, :check_locked_at, :datetime
add_column :rules, :check_locked_by_id, :bigint
add_column :rules, :fix_locked_at, :datetime
add_column :rules, :fix_locked_by_id, :bigint
```

### 4.2 Backend API
- `POST /api/rules/:id/lock_field` - Lock single field
- `POST /api/rules/:id/unlock_field` - Unlock single field
- `POST /api/rules/:id/lock_all` - Lock all unlocked fields
- Update RuleBlueprint to include lock info

### 4.3 Frontend Store
- Update `rules.store.ts` with lock actions
- Update `useRules` composable

### 4.4 Field Lock UI
- Create `FieldLock.vue` component
- Shows lock state, who locked, when
- Lock/Unlock button based on permissions

### 4.5 Lock Actions in Focus View
- [Lock] button per field
- [Lock Remaining] footer action
- [Lock All] footer action

**Tests Required:**
- Backend: field_locking_spec.rb
- Frontend: FieldLock.spec.ts
- API integration tests

---

## Phase 5: Review Integration

**Goal**: Integrate existing review workflow with new UI.

### 5.1 Reviews Slideout
- Create `ReviewsPanel.vue`
- Show review history with comments
- Add comment form
- Review action buttons (based on permissions)

### 5.2 Review Status in Focus View
- Show current review state in header
- Disable editing when under review
- Show reviewer info

### 5.3 Review Filters in Table
- Filter: My Review Requests, Needs My Review
- Summary card: Changes Requested count

### 5.4 History Slideout
- Create `HistoryPanel.vue`
- Show audit log (already exists via `audited`)
- View diff, revert functionality

**Tests Required:**
- ReviewsPanel.spec.ts
- HistoryPanel.spec.ts

---

## Phase 6: Automation Panel (Future)

**Goal**: Add InSpec/Ansible/Chef/Shell scripts.

### 6.1 Database
- Create `automation_scripts` table
- `rule_id`, `script_type`, `content`

### 6.2 Backend API
- CRUD for automation scripts

### 6.3 Automation Panel UI
- Create `AutomationPanel.vue`
- Tabbed interface per script type
- Syntax highlighting (CodeMirror or Monaco)
- Expand to full editor

**Deferred**: Implement after core editor is stable.

---

## Implementation Order

```
Phase 1 (Table View) - COMPLETE ✓
├─ 1.1 Summary Cards ✓
├─ 1.2 Lock Progress Column ✓
├─ 1.3 Review Status Column ✓
├─ 1.4 Satisfies Column & Card ✓
├─ 1.5 Enhanced Filters (Lock, Review, Satisfies) ✓
├─ 1.6 Bulk Satisfaction Actions ✓
└─ 1.7 Collapsible Groups ✓

Phase 2 (Focus View) - Next
├─ 2.1 Smart Header
├─ 2.2 Editor Fields
├─ 2.3 Field Expand Modal
├─ 2.4 Slideout Infrastructure
└─ 2.5 Keyboard Navigation

Phase 2.x (NIST Grouping) - Can be done in parallel with Phase 2
├─ 2.x.1 Backend: Add NIST fields to serializer
├─ 2.x.2 Frontend: useRequirementsGrouping composable
├─ 2.x.3 UI: Group by dropdown
├─ 2.x.4 UI: Collapsible group headers
└─ 2.x.5 UI: Group progress indicators

Phase 3 (Reference Panel)
├─ 3.1 Reference Panel
├─ 3.2 Reference Tabs
├─ 3.3 Scroll-Spy Sync
├─ 3.4 Copy to Editor
├─ 3.5 More References Slideout
├─ 3.6 Primary References (backend)
├─ 3.7 Smart Satisfaction Suggestions
└─ 3.8 Satisfies Slideout

Phase 3.x (Meta-Categories) - Future
├─ 3.x.1 Database: focus_areas tables
├─ 3.x.2 Seed data
├─ 3.x.3 Backend: FocusArea model & API
├─ 3.x.4 Frontend: Dashboard summary view
└─ 3.x.5 Admin UI (optional)

Phase 4 (Field Locking)
├─ 4.1 Database Migration
├─ 4.2 Backend API
├─ 4.3 Frontend Store
├─ 4.4 Field Lock UI
└─ 4.5 Lock Actions

Phase 5 (Reviews)
├─ 5.1 Reviews Slideout
├─ 5.2 Review Status
├─ 5.3 Review Filters
└─ 5.4 History Slideout

Future: Phase 6 (Automation)
```

---

## Dependencies Diagram

```
Phase 1: Table View (standalone) ✓ COMPLETE
    │
    ├──► Phase 2: Focus View Refactor
    │         │
    │         ├──► Phase 3: Reference Panel
    │         │         │
    │         │         └──► Phase 3.x: Meta-Category Grouping
    │         │
    │         ├──► Phase 4: Field Locking
    │         │         │
    │         │         └──► Phase 5: Review Integration
    │         │
    │         └──► Phase 6: Automation Panel (future)
    │
    └──► Phase 2.x: NIST Family Grouping (parallel)
              │
              └──► Phase 3.x: Meta-Category Grouping
```

**Note**: Phase 2.x (NIST Grouping) can be implemented in parallel with Phase 2 (Focus View) since they don't share dependencies. Phase 3.x builds on 2.x.

---

## Testing Strategy

Each phase MUST include:
1. **Unit tests** for new composables
2. **Component tests** for new Vue components
3. **Integration tests** for API endpoints
4. **Manual QA** before merge

**No phase is complete until tests pass.**

---

## Files to Create

```
app/javascript/
├── components/requirements/
│   ├── TableView/
│   │   ├── SummaryCards.vue
│   │   ├── SummaryCards.spec.ts
│   │   ├── LockProgress.vue
│   │   ├── LockProgress.spec.ts
│   │   ├── SatisfiesIndicator.vue
│   │   ├── SatisfiesIndicator.spec.ts
│   │   ├── ReviewStatus.vue
│   │   ├── ReviewStatus.spec.ts
│   │   ├── BulkActions.vue
│   │   ├── BulkActions.spec.ts
│   │   └── StatusGroup.vue
│   │
│   ├── FocusView/
│   │   ├── FocusHeader.vue
│   │   ├── FocusHeader.spec.ts
│   │   ├── EditorField.vue
│   │   ├── EditorField.spec.ts
│   │   ├── FieldLock.vue
│   │   ├── FieldLock.spec.ts
│   │   ├── FieldExpandModal.vue
│   │   └── FieldExpandModal.spec.ts
│   │
│   ├── ReferencePanel/
│   │   ├── ReferencePanel.vue
│   │   ├── ReferencePanel.spec.ts
│   │   ├── ReferenceTabs.vue
│   │   ├── ReferenceContent.vue
│   │   ├── CopyButton.vue
│   │   └── SatisfactionHints.vue
│   │
│   └── Slideouts/
│       ├── SlideoutPanel.vue
│       ├── RelatedRulesPanel.vue
│       ├── ReviewsPanel.vue
│       ├── HistoryPanel.vue
│       ├── SatisfiesPanel.vue
│       └── SatisfiesPanel.spec.ts
│
├── composables/
│   ├── useScrollSpy.ts
│   ├── useScrollSpy.spec.ts
│   ├── useKeyboardNav.ts
│   ├── useKeyboardNav.spec.ts
│   ├── useSatisfactions.ts
│   ├── useSatisfactions.spec.ts
│   ├── useRequirementsGrouping.ts        # Phase 2.x
│   └── useRequirementsGrouping.spec.ts   # Phase 2.x
│
├── components/dashboard/                  # Phase 3.x
│   ├── FocusAreaDashboard.vue
│   └── FocusAreaCard.vue
```

**Backend Files (Phase 3.x):**
```
app/models/
├── focus_area.rb
└── focus_area_nist_mapping.rb

app/controllers/api/
└── focus_areas_controller.rb

app/blueprints/
└── focus_area_blueprint.rb

db/migrate/
└── xxx_create_focus_areas.rb

spec/models/
├── focus_area_spec.rb
└── focus_area_nist_mapping_spec.rb
```

---

*Last Updated: 2025-12-05*
