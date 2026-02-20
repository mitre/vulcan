# Per-Section Rule Locking — Developer Guide

## Data Model

### Database

`base_rules.locked_fields` — `jsonb`, default `{}`

Format: `{ "Title": true, "Check": true }`. Keys must be valid `LOCKABLE_SECTION_NAMES`.

### Constants

**Backend** (`app/constants/rule_constants.rb`):
```ruby
LOCKABLE_SECTION_NAMES = %w[
  Title Severity Status Fix Check
  Vulnerability\ Discussion DISA\ Metadata
  Vendor\ Comments Artifact\ Description XCCDF\ Metadata
].freeze
```

**Frontend** (`app/javascript/composables/ruleFieldConfig.js`):
```javascript
export const LOCKABLE_SECTIONS = {
  Title: ["title"],
  Severity: ["rule_severity", "severity_override_guidance"],
  Status: ["status", "status_justification"],
  Fix: ["fixtext", "fix_id", "fixtext_fixref"],
  Check: ["content", "system", "content_ref_name", "content_ref_href"],
  "Vulnerability Discussion": ["vuln_discussion"],
  "DISA Metadata": ["documentable", "false_positives", ...],
  "Vendor Comments": ["vendor_comments"],
  "Artifact Description": ["artifact_description"],
  "XCCDF Metadata": ["version", "rule_weight", "ident", "ident_system"],
};

// Reverse lookup — auto-resolves field → section (no manual wiring)
export const FIELD_TO_SECTION = Object.fromEntries(
  Object.entries(LOCKABLE_SECTIONS).flatMap(([section, fields]) =>
    fields.map((field) => [field, section]),
  ),
);
```

`RuleFormGroup` imports `FIELD_TO_SECTION` and auto-resolves the lock section for every field. No manual `lock-section` props needed anywhere.

## API Endpoints

### Per-Rule Section Lock

```
PATCH /rules/:id/section_locks
```

**Params**: `section` (string), `locked` (boolean), `comment` (optional string)

**Authorization**: `can_review_component?` (admin or reviewer)

**Response**: `{ rule: <rule_json>, toast: "Title locked" }`

### Per-Rule Bulk Section Lock

```
PATCH /rules/:id/bulk_section_locks
```

**Params**: `sections` (array of strings), `locked` (boolean), `comment` (optional string)

### Component-Level Bulk Section Lock

```
PATCH /components/:component_id/lock_sections
```

**Params**: `sections` (array), `locked` (boolean), `comment` (optional string)

**Authorization**: `can_review_component?`

Applies section locks to all unlocked rules in the component.

## Frontend Architecture

### Composable: `useRuleFormFields.js`

- `isFieldLocked(fieldName)` — checks if a field's section is locked (returns false when whole-rule locked)
- `isFieldEditable(fieldName)` — combines form disabled + section lock checks
- `injectLockedFields(result)` — called in `ruleFormFields`, `disaDescriptionFields`, `checkFormFields` computeds to add locked fields to `disabled` arrays

### Component Props Flow

```
RulesCodeEditorView
  @toggle-section-lock → toggleSectionLock() → PATCH API → refresh:rule
  ↓
RuleEditor
  @toggle-section-lock → relay up
  ↓
UnifiedRuleForm (computes lockedSections, canManageSectionLocks)
  :locked-sections, :can-manage-section-locks, @toggle-section-lock
  ↓
RuleForm / DisaRuleDescriptionForm / CheckForm
  Lock icons in labels, isSectionLocked(), toggleSectionLock()
```

### `canManageSectionLocks` Logic

```javascript
if (readOnly || rule.locked || rule.review_requestor_id) return false;
return ["admin", "reviewer"].includes(effectivePermissions);
```

## Validation

- `Rule#locked_fields_must_be_valid_sections` — rejects keys not in `LOCKABLE_SECTION_NAMES`
- `Rule` amoeba customize block resets `locked_fields` to `{}` on clone

## Audit Trail

Manual `Audited::Audit` records created via `rule.audits.create!()` (not via `audited` gem's auto-tracking, which excludes `locked_fields`).

The `History.vue` component has a dedicated `computeLockedFieldsText()` method that shows "section locks updated (locked: Title, Status)" instead of raw JSON diffs.

## Export/Import

- **JSON Archive**: `locked_fields` included automatically via `rule.attributes` in `BackupSerializer`. Imported via `DIRECT_COLUMNS` in `RuleBuilder`.
- **XCCDF**: Not included (Vulcan-specific feature, not part of STIG schema).
- **CSV/XLSX**: Not included (workflow metadata, not content). May be added based on user feedback.

## Testing

- `spec/models/rule_section_locks_spec.rb` — 9 model tests
- `spec/requests/rule_section_locks_spec.rb` — 15 request tests
- `spec/javascript/composables/useRuleFormFields.spec.js` — 13 section lock tests (within 117 total)
