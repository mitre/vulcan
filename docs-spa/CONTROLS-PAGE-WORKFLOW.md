# Controls Page - User Workflow Analysis

## Terminology

| Term | Context | Notes |
|------|---------|-------|
| **Requirement** | UI display | Clearest term for users |
| **Rule** | Code/models | Rails model name, kept for compatibility |
| **Control** | Legacy UI | Old term, avoid in new UI |
| **SRG Requirement** | Source data | From Security Requirements Guides |

## Core Purpose

The Controls Page is the **primary work surface** for STIG authoring. Users spend most of their time here editing requirements one-by-one to put them into correct status with required metadata.

## Requirement Statuses

| Status | Description |
|--------|-------------|
| Not Yet Determined | Initial state, needs triage |
| Applicable - Configurable | Requires check/fix text authoring |
| Applicable - Inherently Meets | System meets requirement by default |
| Applicable - Does Not Meet | System cannot meet requirement |
| Not Applicable | Requirement doesn't apply to this system |

## User Workflow Phases

### Phase 1: Triage
Quick passes through requirements to categorize:

1. **Find all "Not Applicable"** → mark them with justification
2. **Find all "Inherently Meets"** → mark them with justification
3. **Remaining are "Applicable - Configurable"** → need deep work

*Characteristics:* Fast navigation, bulk-like operations, status focus

### Phase 2: Authoring
Deep work on each "Applicable - Configurable" requirement:

1. Write **Vulnerability Discussion** (what's the risk)
2. Write **Check Text** (how to verify compliance)
3. Write **Fix Text** (how to remediate)
4. Reference **SRG base** content as starting point
5. Reference **Related Requirements** from similar STIGs

*Characteristics:* Focused editing, reference panels, longer time per item

### Phase 3: Merge/Split Operations

#### Merging (Nesting) - Common
"Requirement A also satisfies D, E, F"

- Same fix applies to multiple requirements
- Only A stays in final STIG
- Note in Vuln Desc: "D, E, F also satisfied by this"
- Called "Also Satisfies" or "Nested Controls"

#### Splitting (Cloning) - Less Common
"Requirement A needs to become A and A+1"

- One requirement needs multiple separate implementations
- Clone the control, split the guidance
- Example: "Do X in location 1" and "Do Y in location 2"

### Phase 4: Review
PR-style workflow:

1. Author clicks **"Request Review"**
2. Reviewer sees pending reviews
3. Reviewer either:
   - **Approves** → can then Lock
   - **Requests Changes** → back to author
4. Once approved, reviewer can **Lock** the requirement
5. Locked requirements are "done"

## Key UI Needs by Phase

| Phase | Primary Need | Secondary Need |
|-------|--------------|----------------|
| Triage | Fast navigation, filtering | Bulk status updates |
| Authoring | Large edit area, references | SRG/Related panels |
| Merge/Split | Requirement picker, relationship view | Preview merged result |
| Review | Diff view, comment thread | Lock/unlock controls |

## Data Flow

```
Component
├── has many Requirements (rules)
│   ├── has Status, Severity, etc.
│   ├── has Vuln Discussion, Check, Fix
│   ├── has Reviews (comment + action)
│   ├── has History (audits)
│   ├── satisfies → other Requirements (nesting)
│   └── satisfied_by ← other Requirements
└── belongs to Project
    └── has SRG (base requirements)
```

## Current Pain Points

1. **Scattered actions** - Save, Clone, Merge, Review buttons in different places
2. **Nested requirements clutter** - After merging, nested items still visible
3. **No triage mode** - Same UI for quick categorization and deep editing
4. **Reference panels take space** - SRG/Related always visible even when not needed
