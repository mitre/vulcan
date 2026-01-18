# Requirements Editor Work Plan

## Session: Started 2025-11-28
## Status: IN PROGRESS

---

## Business Context

### What is a "Requirement"?
- In UI: "Requirement" (user-friendly term)
- In code: "Rule" (model name)
- Source: SRG (Security Requirements Guide) requirements that must be adjudicated

### The Core Workflow
Every SRG requirement starts as "Not Yet Determined" and must be **bucketed** into one of four final states. This is the primary authoring workflow in Vulcan.

---

## Status Types & Field Requirements

### 1. Not Yet Determined (Triage State)
**Purpose:** Must adjudicate if/how requirement can be met
**Note:** ALL SRG requirements must be bucketed to complete the work

**Fields (inherited from SRG, mostly readonly):**
- Status (editable - this is how you bucket)
- Title (readonly)
- Vulnerability Discussion (readonly)

---

### 2. Applicable - Configurable (Primary Output)
**Purpose:** Can be configured to meet requirement in the application
**Note:** These become the actual STIG rules exposed to end users
**Risk Level:** LOW - actively reviewed and monitored

**Fields:**
- Status
- Title
- Vulnerability Discussion
- Check Text (the test/validation script)
- Fix Text (remediation instructions)
- Severity / Category (CAT I/II/III)
- Comments (vendor comments - not published)

---

### 3. Applicable - Inherently Meets
**Purpose:** Hardcoded to meet requirement - user doesn't need to do anything
**Note:** Does NOT appear in final STIG document
**Risk Level:** HIGH - "forgotten about" after initial adjudication

**Fields:**
- Status
- Status Justification (explain WHY it inherently meets)
- Artifact Description (evidence - code files, docs, screenshots)
- Comments

---

### 4. Applicable - Does Not Meet
**Purpose:** No way to make the app meet the requirement
**Note:** Always a FAIL in the STIG until app owner codes a solution
**Risk Level:** MEDIUM - tracked via mitigations or POA&M

**Fields:**
- Status
- Status Justification (explain WHY it cannot meet)
- Mitigation Available (toggle) - XOR with POA&M
  - Mitigations list (if toggle on)
- POA&M Available (toggle) - XOR with Mitigation
  - POA&M details (if toggle on)
- Comments

**Important:** Mitigations and POA&M are mutually exclusive (XOR logic)

---

### 5. Not Applicable
**Purpose:** Requirement addresses capability the product doesn't support
**Risk Level:** MEDIUM - should be periodically reviewed

**Fields:**
- Status
- Status Justification (explain WHY not applicable)
- Artifact Description (evidence)
- Comments

---

## Special Cases

### Merged Rules (satisfied_by relationship)
- Behaves like "Applicable - Configurable"
- Some fields inherited from parent rule (disabled)
- Title and Fix Text come from the satisfying rule

### Locked Rules
- All fields readonly
- Happens after approval workflow

### Review In Progress
- All fields readonly while review is pending

---

## Right Sidebar (Consistent Across All Statuses)

1. **Also Satisfies / Merged List** - Rules this requirement satisfies
2. **Comments / Reviews** - Discussion and approval workflow
3. **Changelog / History** - Audit trail
4. **Related Rules** - Link to similar rules in other STIGs

---

## UI/UX Design Decisions

### Progress Tracking
- Show "X / Y Requirements" count prominently
- Verb TBD (bucketed? completed? adjudicated?)

### SRG Context Reference
- Original SRG text should be available but not cluttering the view
- Modal or slide-out panel (not inline)
- Only show when user needs reference

### Risk Indicators
- Consider warning badges on "Inherently Meets" items
- "Review periodically" reminder
- Iterate and experiment to find what works

### Table vs Focus Mode
- TBD - need to work out optimal UX flow
- Hypothesis: Table for triage, Focus for authoring
- Will experiment and refine

---

## Implementation Phases

### Phase 1: Field Logic Foundation (CURRENT)
- [ ] Create status-based field configuration
- [ ] Update RequirementEditor to show correct fields per status
- [ ] Implement XOR logic for Mitigations vs POA&M
- [ ] Add field tooltips and help text
- [ ] Test with real data

### Phase 2: API & Data Shape
- [ ] Verify API returns all needed data
- [ ] Add any missing fields to JSON response
- [ ] Ensure proper nested attributes (checks, disa_descriptions)
- [ ] Handle the `_attributes` suffix pattern Rails expects

### Phase 3: Editor Sections
- [ ] Status selection with visual indication
- [ ] Dynamic field groups based on status
- [ ] SRG reference modal/panel
- [ ] Right sidebar components (merges, comments, history)

### Phase 4: Table Mode Refinement
- [ ] Quick status change in table
- [ ] Bulk operations
- [ ] Filtering by status
- [ ] Progress indicator

### Phase 5: Polish & UX
- [ ] Keyboard shortcuts
- [ ] Auto-save
- [ ] Validation feedback
- [ ] Risk indicators experiment
- [ ] Optimal table vs focus workflow

---

## Key Files

### New (Vue 3 SPA)
- `app/javascript/stores/rules.store.ts` - Pinia store (Setup syntax)
- `app/javascript/apis/rules.api.ts` - API calls
- `app/javascript/composables/useRules.ts` - Composable wrapper
- `app/javascript/components/requirements/` - All UI components
- `app/javascript/pages/components/ControlsPage.vue` - Main page

### Old (Vue 2 Reference)
- `app/javascript/components/rules/forms/BasicRuleForm.vue` - Field logic reference
- `app/javascript/components/rules/forms/RuleForm.vue` - All fields
- `app/javascript/components/rules/forms/DisaRuleDescriptionForm.vue` - DISA fields
- `app/javascript/components/rules/forms/CheckForm.vue` - Check fields

### Rails Backend
- `app/controllers/rules_controller.rb` - API endpoints
- `app/models/rule.rb` - Model with validations

---

## Commands

```bash
pnpm build                    # Build frontend
foreman start -f Procfile.dev # Dev server (port 5000)
pnpm lint                     # Lint check

# Test routes
/components/:id/controls      # New requirements editor
```

---

## Notes for Future Sessions

1. Field logic is status-dependent - changing status changes available fields
2. Mitigations vs POA&M is XOR (mutually exclusive)
3. "Inherently Meets" and "Not Applicable" are high-risk (forgotten)
4. Progress = how many requirements have been bucketed from "Not Yet Determined"
5. SRG reference text should be accessible but not cluttering the view
