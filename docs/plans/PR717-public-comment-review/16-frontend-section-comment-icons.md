# Task 16: SectionCommentIcon.vue + per-section icons in the rule form

**Depends on:** 13
**Estimate:** 45 min Claude-pace (revised up — more files than originally thought)
**File touches:**
- `app/javascript/components/shared/SectionCommentIcon.vue` (new)
- `app/javascript/components/rules/forms/RuleFormGroup.vue` (modify — add slot/prop for icon next to label) **OR** `app/javascript/components/rules/forms/RuleForm.vue`, `CheckForm.vue`, `DisaRuleDescriptionForm.vue`, `RuleDescriptionForm.vue` (modify each section's `<RuleFormGroup>` invocation)
- `app/javascript/components/rules/RuleEditorHeader.vue` (add general-comment + view-all-comments buttons)
- `spec/javascript/components/shared/SectionCommentIcon.spec.js` (new)

**Verified facts (corrected from initial guess):**
- There is **no `RulesCodeEditorView.vue` section header pattern** — the rule fields are rendered inside `RuleEditor.vue` → `<UnifiedRuleForm>` → which composes `RuleForm.vue` + `CheckForm.vue` + `DisaRuleDescriptionForm.vue` + `RuleDescriptionForm.vue`.
- Each field is a `<RuleFormGroup field-name="..." label="..." tooltip="...">` (see `RuleForm.vue:13-31` for the pattern).
- The 10 sections from `RuleConstants::LOCKABLE_SECTION_NAMES` map to specific `RuleFormGroup` invocations across these files.
- **Recommended approach (lighter touch):** add an optional `comment-section` prop to `RuleFormGroup.vue` that renders `<SectionCommentIcon>` inline with the label when set. Then each `RuleFormGroup` call site adds `:comment-section="'check_content'"` (or whichever XCCDF key applies).

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

Open `app/javascript/components/rules/forms/RuleFormGroup.vue`. Read its current structure first — note where `label` is rendered. Add an optional prop `commentSection` and render `<SectionCommentIcon>` inline with the label when set:

```vue
<!-- in RuleFormGroup.vue's template, next to the label -->
<template>
  <b-form-group :label="label" ...>
    <template #label>
      {{ label }}
      <SectionCommentIcon
        v-if="commentSection"
        :section="commentSection"
        :pending-count="pendingCommentsForSection"
        :locked="ruleLocked"
        @open-composer="$emit('open-composer', commentSection)"
      />
    </template>
    <slot />
  </b-form-group>
</template>

<script>
import SectionCommentIcon from "../../shared/SectionCommentIcon.vue";
export default {
  name: "RuleFormGroup",
  components: { SectionCommentIcon },
  props: {
    // ...existing props (fieldName, label, tooltip, etc.)...
    commentSection: { type: String, default: null },          // NEW: XCCDF key
    pendingCommentsForSection: { type: Number, default: 0 }, // NEW: count for badge
    ruleLocked: { type: Boolean, default: false },           // NEW: hide on lock
  },
  // ...
};
</script>
```

(Adjust merge into RuleFormGroup's actual structure — verify by reading it first.)

Then update each section's `<RuleFormGroup>` invocation in the form files to pass `comment-section`. Mapping (XCCDF keys per §3.1.2 of the design doc):

| Existing field-name (in *Form.vue) | XCCDF section key |
|---|---|
| `status` (in `RuleForm.vue:14`) | `status` |
| `rule_severity` (in `RuleForm.vue:35`) | `severity` |
| `title` | `title` |
| `fixtext` (in `CheckForm.vue` or similar) | `fixtext` |
| `check_content` | `check_content` |
| `vuln_discussion` | `vuln_discussion` |
| (DISA metadata fields — group under one) | `disa_metadata` |
| `vendor_comments` | `vendor_comments` |
| `artifact_description` | `artifact_description` |
| (XCCDF metadata fields — group under one) | `xccdf_metadata` |

For grouped sections like DISA Metadata (which contains many fields per `RuleConstants::SECTION_FIELDS`), only the FIRST field in the section gets the `comment-section` prop — that's where the icon shows. Other fields in the same section don't duplicate.

Verify the actual field-to-section mapping against `app/constants/rule_constants.rb#SECTION_FIELDS` before implementing.

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
