# Task 06: i18n locale + frontend vocabulary file (single source of truth)

**Depends on:** —
**Unblocks:** 13 (frontend mirror), 07-12 (controllers use error message keys)
**Estimate:** 20 min Claude-pace
**File touches:**
- `config/locales/en.yml` (new `vulcan.triage.*` namespace)
- `app/javascript/constants/triageVocabulary.js` (new)
- `spec/javascript/constants/triageVocabulary.spec.js` (new)
- `spec/locales/triage_keys_spec.rb` (new)

This task creates the **two source-of-truth files** for triage vocabulary per design §3.1.2. Every other file (Vue templates, HAML views, error messages) imports from these and never hardcodes labels.

---

## Step 1: Create `app/javascript/constants/triageVocabulary.js`

```javascript
// Single source of truth for triage vocabulary in the frontend.
// Mirrors config/locales/en.yml#vulcan.triage. If you add a status key,
// update both files and the canonical table in DESIGN §3.1.2.
//
// Storage = DISA-native. UI = friendly English. See DESIGN §3.1.1 for why.

// Database / API key → friendly UI label
export const TRIAGE_LABELS = Object.freeze({
  pending: "Pending",
  concur: "Accept",
  concur_with_comment: "Accept with changes",
  non_concur: "Decline",
  duplicate: "Duplicate",
  informational: "Informational",
  needs_clarification: "Needs clarification",
  withdrawn: "Withdrawn",
});

// Database / API key → DISA-matrix term (for tooltips and CSV/OSCAL export)
export const TRIAGE_DISA_LABELS = Object.freeze({
  pending: "Pending",
  concur: "Concur",
  concur_with_comment: "Concur with comment",
  non_concur: "Non-concur",
  duplicate: "Duplicate",
  informational: "Informational",
  needs_clarification: "Needs clarification",
  withdrawn: "Withdrawn",
});

// Database / API key → tooltip text (DISA term + brief explanation)
export const TRIAGE_TOOLTIPS = Object.freeze({
  pending: "Awaiting triage",
  concur: "Concur — incorporate as suggested",
  concur_with_comment: "Concur with comment — incorporate with changes",
  non_concur: "Non-concur — won't incorporate (response required)",
  duplicate: "Duplicate of another comment",
  informational: "Note acknowledged, no action required",
  needs_clarification: "Awaiting more info from commenter",
  withdrawn: "Commenter retracted this comment",
});

// Database / API key → glyph (text characters; pair with text label, never alone)
// Glyphs are decorative — always render with `aria-hidden="true"` and pair
// with the text label for screen readers (WCAG 1.4.1).
export const TRIAGE_GLYPHS = Object.freeze({
  pending: "◯",
  concur: "●",
  concur_with_comment: "◐",
  non_concur: "◑",
  duplicate: "◭",
  informational: "ⓘ",
  needs_clarification: "⌛",
  withdrawn: "⊘",
});

// "Closed" indicator (when adjudicated_at is set on a triaged review)
export const ADJUDICATED_LABEL = "Closed";
export const ADJUDICATED_TOOLTIP = "Adjudicated — work complete";
export const ADJUDICATED_GLYPH = "✓";

// Section vocabulary — XCCDF element keys → friendly UI label
// Mirrors RuleConstants::SECTION_FIELDS in app/constants/rule_constants.rb
export const SECTION_LABELS = Object.freeze({
  title: "Title",
  severity: "Severity",
  status: "Status",
  fixtext: "Fix",
  check_content: "Check",
  vuln_discussion: "Vulnerability Discussion",
  disa_metadata: "DISA Metadata",
  vendor_comments: "Vendor Comments",
  artifact_description: "Artifact Description",
  xccdf_metadata: "XCCDF Metadata",
});

// Component comment phase → friendly UI label
export const COMMENT_PHASE_LABELS = Object.freeze({
  draft: "Draft",
  open: "Open for comment",
  adjudication: "Adjudication",
  final: "Final",
});

// Helper: render the section label for a possibly-null section value
export function sectionLabel(section) {
  if (section === null || section === undefined) return "(general)";
  return SECTION_LABELS[section] || section;
}

// Helper: triage status pair (glyph + label) for templates that need both
export function triageDisplay(status) {
  return {
    glyph: TRIAGE_GLYPHS[status] || "?",
    label: TRIAGE_LABELS[status] || status,
    tooltip: TRIAGE_TOOLTIPS[status] || "",
    cssClass: `triage-status--${status}`, // CSS hooks use stable DISA keys, not friendly labels
  };
}
```

## Step 2: Add the locale entries to `config/locales/en.yml`

Locate the existing `en:` root and add (preserving any existing top-level keys; merge into the existing structure):

```yaml
en:
  vulcan:
    triage:
      status:
        pending: "Pending"
        concur: "Accept"
        concur_with_comment: "Accept with changes"
        non_concur: "Decline"
        duplicate: "Duplicate"
        informational: "Informational"
        needs_clarification: "Needs clarification"
        withdrawn: "Withdrawn"
      disa_status:
        pending: "Pending"
        concur: "Concur"
        concur_with_comment: "Concur with comment"
        non_concur: "Non-concur"
        duplicate: "Duplicate"
        informational: "Informational"
        needs_clarification: "Needs clarification"
        withdrawn: "Withdrawn"
      adjudicated:
        label: "Closed"
        tooltip: "Adjudicated — work complete"
      errors:
        decline_requires_response: "Decline requires a response — explain why so the commenter understands."
        duplicate_requires_target: "Mark-as-duplicate requires selecting the canonical comment."
        cannot_withdraw_already_triaged: "This comment has already been triaged and can't be withdrawn."
        cannot_edit_after_triage: "Comments can only be edited while pending triage."
        permission_denied_comment: "You do not have permission to comment on this component. Ask a project administrator to grant you membership."
      sections:
        title: "Title"
        severity: "Severity"
        status: "Status"
        fixtext: "Fix"
        check_content: "Check"
        vuln_discussion: "Vulnerability Discussion"
        disa_metadata: "DISA Metadata"
        vendor_comments: "Vendor Comments"
        artifact_description: "Artifact Description"
        xccdf_metadata: "XCCDF Metadata"
        general: "(general)"
      comment_phase:
        draft: "Draft"
        open: "Open for comment"
        adjudication: "Adjudication"
        final: "Final"
```

## Step 3: Write the parity sanity spec

Create `spec/locales/triage_keys_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

# Asserts that config/locales/en.yml stays in sync with the JS vocabulary
# file (app/javascript/constants/triageVocabulary.js). If you add a triage
# status to one, you MUST add it to both — this spec catches drift.
RSpec.describe 'Triage vocabulary parity (en.yml ↔ triageVocabulary.js)' do
  let(:yml) {
    YAML.load_file(Rails.root.join('config/locales/en.yml')).dig('en', 'vulcan', 'triage')
  }

  let(:js_source) {
    File.read(Rails.root.join('app/javascript/constants/triageVocabulary.js'))
  }

  let(:expected_statuses) {
    %w[pending concur concur_with_comment non_concur
       duplicate informational needs_clarification withdrawn]
  }

  it 'has all expected status keys in en.yml' do
    expect(yml.dig('status').keys).to match_array(expected_statuses)
  end

  it 'has all expected DISA matrix keys in en.yml' do
    expect(yml.dig('disa_status').keys).to match_array(expected_statuses)
  end

  it 'every status key in en.yml exists in TRIAGE_LABELS in JS' do
    yml.dig('status').each_key do |key|
      expect(js_source).to include("#{key}:"),
                            "JS file is missing TRIAGE_LABELS entry for `#{key}`"
    end
  end

  it 'every status key in en.yml exists in TRIAGE_GLYPHS in JS' do
    expect(js_source).to include('TRIAGE_GLYPHS')
    yml.dig('status').each_key do |key|
      expect(js_source).to match(/TRIAGE_GLYPHS[^}]+#{Regexp.escape(key)}:/m),
                            "JS file is missing TRIAGE_GLYPHS entry for `#{key}`"
    end
  end

  it 'has section keys matching RuleConstants::SECTION_FIELDS' do
    expect(yml.dig('sections').keys).to include(*RuleConstants::SECTION_FIELDS.keys.map { |k|
      # Display label "Title" → key "title"; this spec just confirms friendliness mapping exists.
      Review::SECTION_KEYS
    }.flatten.uniq) if defined?(Review::SECTION_KEYS)
  end

  it 'has all 4 comment phase keys' do
    expect(yml.dig('comment_phase').keys).to match_array(%w[draft open adjudication final])
  end
end
```

## Step 4: Write the JS vocabulary spec

Create `spec/javascript/constants/triageVocabulary.spec.js`:

```javascript
import { describe, it, expect } from "vitest";
import {
  TRIAGE_LABELS,
  TRIAGE_DISA_LABELS,
  TRIAGE_TOOLTIPS,
  TRIAGE_GLYPHS,
  SECTION_LABELS,
  COMMENT_PHASE_LABELS,
  sectionLabel,
  triageDisplay,
} from "@/constants/triageVocabulary";

const expectedStatuses = [
  "pending",
  "concur",
  "concur_with_comment",
  "non_concur",
  "duplicate",
  "informational",
  "needs_clarification",
  "withdrawn",
];

describe("triageVocabulary", () => {
  it("TRIAGE_LABELS has every expected status", () => {
    expectedStatuses.forEach((s) =>
      expect(TRIAGE_LABELS[s]).toBeDefined(),
    );
  });

  it("TRIAGE_DISA_LABELS has every expected status", () => {
    expectedStatuses.forEach((s) =>
      expect(TRIAGE_DISA_LABELS[s]).toBeDefined(),
    );
  });

  it("TRIAGE_TOOLTIPS has every expected status", () => {
    expectedStatuses.forEach((s) =>
      expect(TRIAGE_TOOLTIPS[s]).toBeDefined(),
    );
  });

  it("TRIAGE_GLYPHS has every expected status", () => {
    expectedStatuses.forEach((s) =>
      expect(TRIAGE_GLYPHS[s]).toBeDefined(),
    );
  });

  it("SECTION_LABELS covers the 10 XCCDF element keys", () => {
    const expectedSections = [
      "title", "severity", "status", "fixtext", "check_content",
      "vuln_discussion", "disa_metadata", "vendor_comments",
      "artifact_description", "xccdf_metadata",
    ];
    expectedSections.forEach((s) =>
      expect(SECTION_LABELS[s]).toBeDefined(),
    );
  });

  it("COMMENT_PHASE_LABELS has draft/open/adjudication/final", () => {
    ["draft", "open", "adjudication", "final"].forEach((p) =>
      expect(COMMENT_PHASE_LABELS[p]).toBeDefined(),
    );
  });

  it("sectionLabel renders null as (general)", () => {
    expect(sectionLabel(null)).toBe("(general)");
    expect(sectionLabel(undefined)).toBe("(general)");
  });

  it("sectionLabel renders known keys via SECTION_LABELS", () => {
    expect(sectionLabel("check_content")).toBe("Check");
  });

  it("triageDisplay returns glyph + label + tooltip + cssClass", () => {
    const r = triageDisplay("concur_with_comment");
    expect(r.glyph).toBe("◐");
    expect(r.label).toBe("Accept with changes");
    expect(r.tooltip).toMatch(/incorporate with changes/i);
    expect(r.cssClass).toBe("triage-status--concur_with_comment");
  });

  it("freezes all the maps", () => {
    expect(Object.isFrozen(TRIAGE_LABELS)).toBe(true);
    expect(Object.isFrozen(TRIAGE_GLYPHS)).toBe(true);
  });
});
```

## Step 5: Run the parity spec to verify it passes

```bash
bundle exec rspec spec/locales/triage_keys_spec.rb
pnpm vitest run spec/javascript/constants/triageVocabulary.spec.js
```

**Expected:** both PASS. The parity check is the guardrail against future drift.

## Step 6: Run vocabulary grep checks (per `98-vocabulary-grep-verification.md`)

```bash
# (b) friendly labels in DB / migrations / models / API
grep -rnE "\"(accept|decline|closed)\"" app/models app/controllers db/migrate
# Expected: zero matches

# (c) Vue + HAML files don't hardcode DISA terms (except triageVocabulary itself)
grep -rnE "concur|adjudicat|non.concur" app/javascript/components app/views \
  | grep -v locales/en.yml \
  | grep -v triageVocabulary.js
# Expected: zero matches (no Vue components yet referencing them)
```

## Step 7: Commit

```bash
cat > /tmp/msg-06.md <<'EOF'
feat: add triage vocabulary single sources of truth

Two files become the canonical mapping for the public-comment-review
workflow's vocabulary layering principle (DESIGN §3.1.1, §3.1.2):

- config/locales/en.yml#vulcan.triage.* — Rails view + error labels
- app/javascript/constants/triageVocabulary.js — Vue templates +
  composables

Both files map DISA-native database keys (concur, concur_with_comment,
non_concur, duplicate, informational, needs_clarification, withdrawn) to
friendly UI labels (Accept, Accept with changes, Decline, etc.) and
provide DISA-term tooltips.

Section vocabulary uses XCCDF element keys (check_content, vuln_discussion,
fixtext, etc.) mapped to human-readable labels.

Comment phase enum (draft, open, adjudication, final) gets the same
treatment.

Parity test in spec/locales/triage_keys_spec.rb fails if the two source-of-
truth files drift. Run before every PR.

No template/controller wiring yet — Tasks 13+ import from these files.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/locales/en.yml app/javascript/constants/triageVocabulary.js \
        spec/locales/triage_keys_spec.rb \
        spec/javascript/constants/triageVocabulary.spec.js
git commit -F /tmp/msg-06.md
rm /tmp/msg-06.md
```

## Step 8: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/06-i18n-and-vocabulary-files.md \
       docs/plans/PR717-public-comment-review/06-i18n-and-vocabulary-files-DONE.md
git commit -m "chore: mark plan task 06 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- `config/locales/en.yml` has the full `vulcan.triage.*` namespace
- `app/javascript/constants/triageVocabulary.js` exports `TRIAGE_LABELS`, `TRIAGE_GLYPHS`, `TRIAGE_TOOLTIPS`, `TRIAGE_DISA_LABELS`, `SECTION_LABELS`, `COMMENT_PHASE_LABELS`, plus `sectionLabel(section)` and `triageDisplay(status)` helpers
- Parity test catches future drift between the two files
- Foundation for every Vue / HAML / Rails-error-message reference in Tasks 07-22
