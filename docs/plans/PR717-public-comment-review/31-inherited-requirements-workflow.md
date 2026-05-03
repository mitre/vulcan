# Task 31: Inherited-requirements as a first-class authoring workflow

**Status:** placed at end of task list — Aaron's call whether this ships in PR-717 or
becomes a follow-up phase. Design captured here so it can be executed when chosen.

**Applies universally** — not ASD-specific. Inheritance is a workflow that exists for
*any* STIG type (OS, application, container, web server, database, network device, etc.).
The pattern is the same: a requirement on the current product is fully mitigated by an
upstream/parent STIG, and DISA prescribes a specific encoding for that. Examples in the
doc include both Apache (`AS24-W1-000280`) and Windows (`WN16-SO-000430`) — different
STIG types, identical encoding.

**Depends on:** none (touches Rule model, export pipeline, rule editor UI, optionally
PR-717's commenter view + Task 29 disposition CSV)

**Estimate:** ~4-5 hr Claude-pace if all in this PR; splittable into backend-only
(~2 hr) + UI (~2 hr) + PR-717 integration (~30 min)

**Related:** Task 32 — broader DISA-compliant rule editor streamlining (status-driven
field contract, Public/CUI badge, CCI candidate suggestions, etc.). Task 31 only pulls
in the streamlining items DIRECTLY tied to the inheritance flow; the rest lives in 32.

**File touches:**
- `db/migrate/<timestamp>_add_inheritance_fields_to_base_rules.rb` (new — empty stub
  exists at `db/migrate/20260430202813_add_inheritance_fields_to_base_rules.rb`,
  decide to keep / regenerate)
- `app/models/base_rule.rb` (validators, helpers)
- `app/models/rule.rb` (drop status auto-override at line 140; new `mitigation_export_text`)
- `app/services/export/serializers/backup_serializer.rb` (new fields)
- `app/services/import/json_archive/component_builder.rb` + `rule_builder.rb`
- `app/services/export/formatters/csv_formatter.rb` or wherever Mitigation column is built
- `app/lib/xccdf/` writer — verify Mitigation field placement in DISA XCCDF
- `app/javascript/components/rules/RuleEditor.vue` (or wherever the toolbar is) — new "Mark as Inherited" button
- `app/javascript/components/rules/InheritanceMarkerModal.vue` (new)
- `app/javascript/components/rules/InheritanceParentRulePicker.vue` (new — cross-project)
- `app/lib/disposition_matrix_export.rb` — extend with Status + Mitigation columns
- `spec/models/rule_spec.rb` + `spec/models/base_rule_spec.rb`
- `spec/services/export/...` + `spec/services/import/...`
- `spec/javascript/components/rules/InheritanceMarkerModal.spec.js`
- `spec/javascript/components/rules/InheritanceParentRulePicker.spec.js`

## Why this task exists

DISA's Vendor STIG Process Guide v4r1 §4.1.15 prescribes the inheritance pattern for
"this requirement is fully mitigated by another STIG":

- **Status** = `Applicable – Does Not Meet`
- **Mitigation** field = `"This requirement is fully mitigated by [parent STIG-RuleID]"`
- **Status Justification** = human-readable explanation
- Severity stays as the pre-mitigation severity (§4.1.14: "must reflect the severity
  BEFORE any mitigation steps")

Two cited examples from the doc (§4.1.15):
- `"This requirement is fully mitigated by the Apache Server 2.4 Windows Server STIG. ... (AS24-W1-000280)"`
- `"This requirement is fully mitigated by the underlying operating system. (WN16-SO-000430)"`

**Vulcan today does NOT match this prescription:**

| Concern | DISA prescribes | Vulcan does |
|---|---|---|
| Field carrying citation | `Mitigation` | `vendor_comments` (rule.rb:320 `export_vendor_comments`) |
| Status when inherited | `Applicable – Does Not Meet` | Auto-overrides to `Applicable – Configurable` (rule.rb:140) |
| Citation format | `STIG-ID-RuleID` (e.g., `WN16-SO-000430`) | Internal SV-id / database id |
| Justification field | `Status Justification` (separate, mandated) | Folded into vendor_comments |

Authors using Vulcan today produce STIGs that don't match DISA's prescribed XML/spreadsheet
shape for inherited requirements. The fix is structural — schema + model + export +
UI — not just docs.

## Design decisions

### 1. Two new columns on `base_rules`

| Column | Type | Purpose |
|---|---|---|
| `inherited_external_citation` | string | For citing a parent STIG NOT in Vulcan — `"RHEL-09-211015"` form |
| `inheritance_justification` | text | DISA's §4.1.17 Status Justification text |

In-Vulcan parent rules continue to use the existing `rule_satisfactions` HABTM. The
new columns add (a) the external-citation case + (b) the dedicated justification
text that DISA mandates.

### 2. Status auto-override at rule.rb:140 is removed

```ruby
# rule.rb:140 — REMOVE this:
satisfied_by.size.positive? ? 'Applicable - Configurable' : self[:status]

# Replace with: self[:status] (no override)
```

Inheritance status is `Applicable – Does Not Meet` per DISA. Validator below enforces.

### 3. Validators on the inherited contract

```ruby
def inherited?
  satisfied_by.any? || inherited_external_citation.present?
end

validate :inherited_must_be_dnm
validate :inherited_must_have_justification

private

def inherited_must_be_dnm
  return unless inherited?
  return if status == 'Applicable - Does Not Meet'

  errors.add(:status, 'must be "Applicable - Does Not Meet" for inherited requirements')
end

def inherited_must_have_justification
  return unless inherited?
  return if inheritance_justification.present?

  errors.add(:inheritance_justification, 'is required for inherited requirements')
end
```

### 4. Mitigation export helper

```ruby
def mitigation_export_text
  return nil unless inherited?

  parent_id = if satisfied_by.any?
                parent = satisfied_by.first
                "#{parent.component.prefix}-#{parent.rule_id}"
              else
                inherited_external_citation
              end
  "This requirement is fully mitigated by #{parent_id}."
end
```

`vendor_comments` no longer carries inheritance text. Spreadsheet/CSV exporters write
this string into the `Mitigation` column when present; Status Justification column
gets `inheritance_justification`.

### 5. Cross-project parent rule picker (Aaron approved option 1)

The "Mark as Inherited / from a Vulcan rule" picker queries across projects. Backend
endpoint: `GET /rules/search?q=...` (admin-callable). UI surfaces project + component
in each result row so authors can disambiguate when the same rule_id exists in
multiple projects.

### 6. Existing `satisfied_by` data is left untouched on migration

Don't auto-migrate. Existing rules retain old behavior (status auto-override removal
DOES affect them — this is the only behavior change on existing data). Authors can
re-save through the new "Mark as Inherited" flow to upgrade existing rules to the
DISA-canonical pattern.

### 7. PR-717 integration

- **Task 24 (mark-as-duplicate)** — when triager opens the picker on a comment for an
  inherited rule, surface a hint pointing at the parent canonical rule
- **Task 29 (disposition CSV)** — add `Rule Status` + `Mitigation` columns so DISA
  adjudicators see which comments are on inherited rules
- **Commenter view** — inherited badge with "This requirement is inherited from
  {parent}; consider commenting on the canonical rule" hint

### 8. Streamlining items pulled INTO Task 31 (directly tied to the inheritance flow)

Per DISA Vendor STIG Process v4r1, four streamlining opportunities are tightly
coupled to the inheritance-marking workflow and belong in this task. The broader
status-driven field contract + universal streamlining items live in Task 32.

**8a. Per-status Justification placeholder (§4.1.17)**

Status Justification text changes its placeholder/help text based on the rule's
status, mirroring DISA's prescriptions:
- **NA**: `"Explain why the requirement is not applicable. Most common: capability not present, or operational environment mismatch."`
- **DNM** (the inheritance case): `"What function or feature is not present. If some part of the requirement is achievable, explain what part is unmet and what is met. Describe residual risk after mitigation."`
- **IM**: `"List the specific feature of the product that supports this requirement and that cannot be changed. Note evidence type (test report / vendor docs / attestation)."`

**8b. Mitigation summary statement template (§4.1.15)**

After the canonical "fully mitigated by [parent]" sentence, DISA suggests three
summary phrasings:
- `"With the implementation of this mitigation, the overall risk can be decreased to a CAT [II or III]."`
- `"With the implementation of this mitigation, the overall risk is fully mitigated."`
- `"Although the listed mitigation is supporting the security function, it is not sufficient to reduce the residual risk of this requirement."`

The "Mark as Inherited" modal offers these as a dropdown that appends to the
Mitigation field text. Author can also write free-form.

**8c. Severity-on-DNM tooltip (§4.1.14)**

> "The severity selection for requirements deemed Applicable – Does Not Meet must
> reflect the severity BEFORE any mitigation steps are taken by an organization."

The Severity field on a DNM rule shows a tooltip surfacing this rule. (Full hide-when-
NA logic lives in Task 32.)

**8d. SRG Check / SRG Fix prepopulated reference panel (§4.1.10, §4.1.12)**

Per the doc, SRG Check and SRG Fix are starting-point references for writing the
product-specific Check and Fix. When marking a requirement as inherited (status →
DNM), the SRG reference text becomes irrelevant for the published STIG (Check and
Fix go blank per §4.1.11 + §4.1.13). The form should visually de-emphasize SRG
Check/Fix and emphasize Mitigation + Justification.

### 9. Streamlining items DEFERRED to Task 32

To keep Task 31 focused on the inheritance workflow itself, these items live in
Task 32 (`32-disa-rule-editor-streamlining.md`):
- Full status-driven required-field contract for all 4 statuses, applied to every
  rule edit (not just the inheritance flow)
- Public-publish vs CUI badge on every rule based on status (§6)
- "Add Best-Practice Rule" button with CCI-000366 prefilled (§4.2.1)
- CCI-driven inheritance candidate suggestions (§4.1.2)
- Requirement / Check / Fix text linters per §4.1.6, §4.1.11.1, §4.1.13.1
- Stage-1 readiness widget (§3.2)
- Letter-of-Attestation prompt (§5.4.3)

## TDD order

| # | Step | Est | Why this order |
|---|---|---|---|
| 1 | Migration + base_rule schema spec (`spec/models/base_rule_spec.rb`) | 15m | Foundation |
| 2 | Validators (DNM-when-inherited, justification-required) + `inherited?` | 20m | Model contract |
| 3 | Drop status auto-override + add `mitigation_export_text` | 25m | Core export-correctness fix |
| 4 | Spreadsheet/CSV export field placement + tests | 20m | DISA-compliant output |
| 5 | XCCDF Mitigation field mapping (verify against DISA writer) | 30m | DISA XCCDF compliance — flag if writer needs deeper change |
| 6 | json_archive backup/restore round-trip (extend Task 31's predecessors) | 20m | Don't lose new fields on backup |
| 7 | "Mark as Inherited" modal + InheritanceParentRulePicker | 60m | Reuses CanonicalCommentPicker pattern from Task 24 |
| 8 | Inherited badge on rule list + rule editor + commenter view | 25m | Visual surfacing |
| 9 | Task 29 disposition CSV: add Status + Mitigation columns | 15m | Adjudicator context |
| 10 | Live verify + commit | 15m | |

## Acceptance criteria

- [ ] Migration adds the two columns
- [ ] Inherited rule with status != DNM is invalid
- [ ] Inherited rule with blank justification is invalid
- [ ] `Rule#mitigation_export_text` returns canonical sentence with `STIG-ID-RuleID`
- [ ] Spreadsheet export emits canonical Mitigation sentence in the Mitigation column
- [ ] Spreadsheet export puts justification in the Status Justification column
- [ ] XCCDF export places Mitigation correctly (verify against DISA writer)
- [ ] Cross-project parent rule picker works
- [ ] Existing `satisfied_by` data not auto-migrated (no surprise changes to live Container SRG)
- [ ] json_archive backup/restore preserves new fields
- [ ] Disposition CSV (Task 29) gets `Rule Status` + `Mitigation` columns
- [ ] PR-717 commenter UI shows Inherited badge + parent hint
- [ ] All specs green
- [ ] Live-verified by authoring a small inherited rule end-to-end

## Open questions to confirm before starting

1. **Scope decision** — does this go in PR-717, or split as a fast-follow PR? If
   PR-717: ~4 hr more. If fast-follow: PR-717 ships sooner; this becomes Task 31 in
   the next phase.
2. **Stub migration cleanup** — `db/migrate/20260430202813_add_inheritance_fields_to_base_rules.rb`
   exists empty from a premature `rails g`. Keep + fill in, or remove and regenerate
   when ready?
3. **bd card** — `vulcan-v3.x-334` was filed with the design. Plan files are the
   canonical PR-717 tracking; close the bd card?

## Reference

- DISA Vendor STIG Process Guide v4r1 (`downloads/U_Vendor_STIG_Process_Guide_V4R1_20220815.pdf`)
  - §4.1.15 Mitigation (the canonical "fully mitigated by" pattern + examples)
  - §4.1.17 Status Justification (mandated for DNM/IM/NA)
  - §4.1.9 Statuses (Table 4-1: 4 statuses, no "Inherited")
  - §6 Review and Approval (only Configurable rules go public; rest is CUI)
- Existing Vulcan code: `app/models/rule.rb:140` (status override to remove),
  `app/models/rule.rb:320` (vendor_comments injection to retire), `app/lib/xccdf/`
  (XCCDF writer for Step 5 verification)
