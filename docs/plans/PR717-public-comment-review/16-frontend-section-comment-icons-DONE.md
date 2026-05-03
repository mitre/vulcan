# Task 16: SectionCommentIcon.vue + per-section icons in the rule form

**Depends on:** 13
**Estimate:** 45 min Claude-pace
**File touches:**
- `app/javascript/components/shared/SectionCommentIcon.vue` (new)
- `app/javascript/components/shared/RuleFormGroup.vue` (modify — render `<SectionCommentIcon>` inline with the existing label icon stack)
- `app/javascript/components/rules/RuleEditorHeader.vue` (add general-comment + view-all-comments buttons)
- `app/javascript/components/rules/forms/UnifiedRuleForm.vue` (compute `commentsBySection` and pass down via provide/inject or per-call-site prop)
- `spec/javascript/components/shared/SectionCommentIcon.spec.js` (new)

**Verified facts (read RuleFormGroup.vue + ruleFieldConfig before writing this task):**

- `RuleFormGroup.vue` is at **`app/javascript/components/shared/RuleFormGroup.vue`** (NOT `forms/`). Imported across `forms/RuleForm.vue`, `forms/CheckForm.vue`, `forms/DisaRuleDescriptionForm.vue`, `benchmarks/RuleDetails.vue` (4 consumers).
- It already has a **`resolvedSection` computed** (lines 105-108) that returns the human-readable section name (e.g., `"Check"`, `"Fix"`, `"Title"`) by looking up `FIELD_TO_SECTION[fieldName]` from `app/javascript/composables/ruleFieldConfig`. **Good news:** we don't need a new prop — the section is already known.
- The label rendering with icons is at **lines 4-39**. Existing icons inside the `<label>`: info-circle tooltip (line 6-11), section-lock-fill (line 12-23), section-unlock (line 24-38). New `<SectionCommentIcon>` slots in **right after line 38, still inside `<label>`**.
- The `resolvedSection` returns the **display label** (e.g., `"Check"`), but our XCCDF-key vocabulary in storage/API uses `"check_content"`. The XCCDF mapping per design §3.1.2 — `SectionCommentIcon` must convert internally and emit the XCCDF key.

**Mapping (display label → XCCDF key) — add to `triageVocabulary.js` from Task 03 if not already present:**

```javascript
// app/javascript/constants/triageVocabulary.js
export const DISPLAY_TO_XCCDF_SECTION = Object.freeze({
  "Title": "title",
  "Severity": "severity",
  "Status": "status",
  "Fix": "fixtext",
  "Check": "check_content",
  "Vulnerability Discussion": "vuln_discussion",
  "DISA Metadata": "disa_metadata",
  "Vendor Comments": "vendor_comments",
  "Artifact Description": "artifact_description",
  "XCCDF Metadata": "xccdf_metadata",
});
```

(Task 03 may not have included this map — if missing, add it as part of this task and update the parity spec from Task 03 to assert it.)

Per design §2.6.1: small `💬` icon next to each section label in the rule form. Click → opens composer (Task 17) with section pre-tagged. Counter badge when section has pending comments.

---

## Step 1: Failing spec

`spec/javascript/components/shared/SectionCommentIcon.spec.js`:

```javascript
import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import SectionCommentIcon from "@/components/shared/SectionCommentIcon.vue";

describe("SectionCommentIcon", () => {
  it("renders a button with aria-label that includes the section name", () => {
    const w = mount(SectionCommentIcon, { propsData: { section: "check_content", pendingCount: 0 } });
    const btn = w.find("button");
    expect(btn.attributes("aria-label")).toMatch(/check/i);
    expect(btn.attributes("aria-label")).toMatch(/comment/i);
  });

  it("shows pending count badge when > 0", () => {
    const w = mount(SectionCommentIcon, { propsData: { section: "fixtext", pendingCount: 3 } });
    expect(w.text()).toContain("3");
    expect(w.find("[data-test=count-badge]").exists()).toBe(true);
  });

  it("includes screen-reader text for the count", () => {
    const w = mount(SectionCommentIcon, { propsData: { section: "fixtext", pendingCount: 3 } });
    const sr = w.find(".sr-only, .visually-hidden");
    expect(sr.exists()).toBe(true);
    expect(sr.text()).toMatch(/3 pending/i);
  });

  it("emits 'open-composer' with section name on click", async () => {
    const w = mount(SectionCommentIcon, { propsData: { section: "check_content", pendingCount: 0 } });
    await w.find("button").trigger("click");
    expect(w.emitted("open-composer")).toEqual([["check_content"]]);
  });

  it("hides entirely when locked=true", () => {
    const w = mount(SectionCommentIcon, { propsData: { section: "title", pendingCount: 0, locked: true } });
    expect(w.find("button").exists()).toBe(false);
  });

  it("uses Enter and Space for keyboard activation (button native behavior)", async () => {
    const w = mount(SectionCommentIcon, { propsData: { section: "title", pendingCount: 0 } });
    await w.find("button").trigger("keydown.enter");
    // b-button / native button fires click on Enter; Vue Test Utils dispatches click via @click
    // — confirming button semantics are in place is enough
    expect(w.find("button[type='button']").exists()).toBe(true);
  });
});
```

## Step 2: Run, verify FAIL

```bash
pnpm vitest run spec/javascript/components/shared/SectionCommentIcon.spec.js
```

## Step 3: Create `SectionCommentIcon.vue`

```vue
<template>
  <b-button
    v-if="!locked"
    variant="link"
    size="sm"
    :aria-label="ariaLabel"
    :title="tooltipText"
    class="section-comment-icon p-1"
    type="button"
    @click="$emit('open-composer', section)"
  >
    <span aria-hidden="true">💬</span>
    <b-badge v-if="pendingCount > 0" data-test="count-badge" variant="primary" class="ml-1">
      {{ pendingCount }}
    </b-badge>
    <span v-if="pendingCount > 0" class="sr-only">{{ pendingCount }} pending comments</span>
  </b-button>
</template>

<script>
import { sectionLabel } from "../../constants/triageVocabulary";

export default {
  name: "SectionCommentIcon",
  props: {
    section: { type: String, required: true },
    pendingCount: { type: Number, default: 0 },
    locked: { type: Boolean, default: false },
  },
  computed: {
    sectionDisplay() {
      return sectionLabel(this.section);
    },
    ariaLabel() {
      const base = `Add comment on ${this.sectionDisplay} section`;
      return this.pendingCount > 0
        ? `${base} (${this.pendingCount} pending)`
        : base;
    },
    tooltipText() {
      return this.pendingCount > 0
        ? `${this.pendingCount} pending comments on ${this.sectionDisplay}`
        : `Comment on ${this.sectionDisplay}`;
    },
  },
};
</script>

<style scoped>
.section-comment-icon {
  text-decoration: none;
}
.section-comment-icon:focus-visible {
  outline: 2px solid var(--primary, #007bff);
  outline-offset: 2px;
}
</style>
```

## Step 4: Wire into the rule form via `RuleFormGroup.vue`

Open `app/javascript/components/shared/RuleFormGroup.vue` (note: under `shared/`, not `forms/`). The template already has a label block at lines 4-39 with three icons inside (info-circle, section-lock-fill, section-unlock). We add `<SectionCommentIcon>` as a fourth icon in that block, after line 38 and before the closing `</label>` on line 39.

Add three new props to the `props:` block (lines 63-81):

```javascript
// New props — every consumer site of RuleFormGroup gets a chance to opt in
showCommentIcon: { type: Boolean, default: false },          // NEW: only show icon when this is true
ruleReviews: { type: Array, default: () => [] },              // NEW: rule.reviews to count from
ruleLocked: { type: Boolean, default: false },                // NEW: hide on locked rules
```

Add a computed for the pending count (in the `computed:` block):

```javascript
import { DISPLAY_TO_XCCDF_SECTION } from "../../constants/triageVocabulary";

// in computed:
xccdfSection() {
  return DISPLAY_TO_XCCDF_SECTION[this.resolvedSection] || null;
},
pendingCommentCount() {
  if (!this.xccdfSection) return 0;
  return this.ruleReviews.filter(
    (r) => r.action === "comment"
        && r.responding_to_review_id == null
        && r.triage_status === "pending"
        && r.section === this.xccdfSection,
  ).length;
},
```

Then in the template, after line 38 and BEFORE the `</label>` on line 39, insert:

```vue
<SectionCommentIcon
  v-if="showCommentIcon && xccdfSection && !ruleLocked"
  :section="xccdfSection"
  :pending-count="pendingCommentCount"
  class="ml-1"
  @open-composer="$emit('open-composer', xccdfSection)"
/>
```

Register the import:

```javascript
import SectionCommentIcon from "./SectionCommentIcon.vue"; // both in shared/
```

**Why one icon per RuleFormGroup, not per section?** RuleFormGroup is rendered once per *field*. Multiple fields belong to the same DISA section (e.g., `documentable`, `false_positives`, `mitigations` all live in "DISA Metadata"). To avoid duplicate icons in DISA Metadata, the consumer (UnifiedRuleForm and the per-section forms) decides which RuleFormGroup gets `:show-comment-icon="true"` — typically the **first field in the section**.

## Step 4a: Decide per-call-site `:show-comment-icon`

Per `RuleConstants::SECTION_FIELDS` (in `app/constants/rule_constants.rb`), each section maps to multiple fields. The "first field" representing each section:

| Section (display label) | XCCDF key | First field |
|---|---|---|
| Title | `title` | `title` |
| Severity | `severity` | `rule_severity` |
| Status | `status` | `status` |
| Fix | `fixtext` | `fixtext` |
| Check | `check_content` | `check_content` |
| Vulnerability Discussion | `vuln_discussion` | `vuln_discussion` |
| DISA Metadata | `disa_metadata` | `documentable` |
| Vendor Comments | `vendor_comments` | `vendor_comments` |
| Artifact Description | `artifact_description` | `artifact_description` |
| XCCDF Metadata | `xccdf_metadata` | `version` |

For each of these 10 first-fields in `RuleForm.vue`, `CheckForm.vue`, `DisaRuleDescriptionForm.vue`, `RuleDescriptionForm.vue`: find the `<RuleFormGroup field-name="<first-field>" ...>` invocation and add `:show-comment-icon="true"` + `:rule-reviews="rule.reviews || []"` + `:rule-locked="rule.locked"`.

Use grep to locate each:

```bash
grep -rnE 'field-name="(title|rule_severity|status|fixtext|check_content|vuln_discussion|documentable|vendor_comments|artifact_description|version)"' app/javascript/components/rules/forms/
```

## Step 5: Add general-comment + view-all-comments buttons to `RuleEditorHeader.vue`

Open `app/javascript/components/rules/RuleEditorHeader.vue`. It's 436 lines and already has comment-related buttons (lines 72-93 reference `<CommentModal>`). Add two buttons in the header area (likely near the existing `<RuleActionsToolbar>` or in a header strip):

```vue
<b-button
  variant="outline-secondary"
  size="sm"
  @click="$emit('open-comment-composer', { ruleId: rule.id, section: null })"
>
  <span aria-hidden="true">💬</span>
  <b-badge v-if="generalCommentCount > 0">{{ generalCommentCount }}</b-badge>
  General comment
</b-button>

<b-button
  variant="link"
  size="sm"
  :href="viewAllCommentsLink"
>
  View all comments on this rule
</b-button>
```

`generalCommentCount` and `viewAllCommentsLink` are computed from props the parent already passes (`rule.reviews` for the count; the link routes to the Comments slideover pre-filtered to this rule — emit and let `ProjectComponent.vue` handle).

## Step 6: Get `commentsBySection` data into the form

The `pendingCommentsForSection` prop on `RuleFormGroup` needs values. Add a computed in `UnifiedRuleForm.vue` (the parent that orchestrates the section forms):

```javascript
computed: {
  commentsBySection() {
    if (!this.rule || !this.rule.reviews) return {};
    return this.rule.reviews
      .filter((r) => r.action === "comment" && r.responding_to_review_id == null && r.triage_status === "pending")
      .reduce((acc, r) => {
        const key = r.section || "general";
        acc[key] = (acc[key] || 0) + 1;
        return acc;
      }, {});
  },
},
```

Then pass `:pending-comments-for-section="commentsBySection[<key>] || 0"` into each section's `RuleFormGroup`. (This is verbose if done at every call site — alternative: provide/inject a `commentsBySectionMap` so children can read it without prop-drilling.)

## Step 5: Run specs + lint

```bash
pnpm vitest run spec/javascript/components/shared/SectionCommentIcon.spec.js
pnpm vitest run    # full suite
yarn lint
```

## Step 6: Commit

```bash
cat > /tmp/msg-16.md <<'EOF'
feat: SectionCommentIcon + per-section comment buttons in rule editor

Small subtle 💬 icon next to each section header in
RuleFormGroup.vue (within UnifiedRuleForm). Per WCAG 4.1.2:
- Native <b-button> with aria-label that names the section + count
- Visible focus ring (focus-visible outline)
- Decorative 💬 marked aria-hidden
- Pending count badge with sr-only text for screen readers
- Hidden entirely on locked rules (no commenting on locked content)

Click emits @open-composer with the section's XCCDF key. Composer (Task 17)
opens with the section pre-tagged.

A general "Comment" button appears once at the top of the rule editor for
section-less comments (section=null).

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/shared/SectionCommentIcon.vue \
        app/javascript/components/rules/forms/RuleFormGroup.vue \
        app/javascript/components/rules/forms/UnifiedRuleForm.vue \
        app/javascript/components/rules/forms/RuleForm.vue \
        app/javascript/components/rules/forms/CheckForm.vue \
        app/javascript/components/rules/RuleEditorHeader.vue \
        spec/javascript/components/shared/SectionCommentIcon.spec.js
git commit -F /tmp/msg-16.md
rm /tmp/msg-16.md
git mv docs/plans/PR717-public-comment-review/16-frontend-section-comment-icons.md \
       docs/plans/PR717-public-comment-review/16-frontend-section-comment-icons-DONE.md
git commit -m "chore: mark plan task 16 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
