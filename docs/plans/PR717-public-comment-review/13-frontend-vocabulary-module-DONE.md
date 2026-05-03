# Task 13: TriageStatusBadge.vue + SectionLabel.vue (reusable display components)

**Depends on:** 03
**Unblocks:** 14, 15, 16, 17, 18, 19, 20
**Estimate:** 15 min Claude-pace
**File touches:**
- `app/javascript/components/shared/TriageStatusBadge.vue` (new)
- `app/javascript/components/shared/SectionLabel.vue` (new)
- `spec/javascript/components/shared/TriageStatusBadge.spec.js` (new)
- `spec/javascript/components/shared/SectionLabel.spec.js` (new)

DRY pattern: every Vue component that displays a triage status uses the same `<TriageStatusBadge>` — never imports `triageVocabulary` directly. Same for sections via `<SectionLabel>`. This way a future label change is one component edit, not 8.

---

## Step 1: Write failing component specs

`spec/javascript/components/shared/TriageStatusBadge.spec.js`:

```javascript
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import TriageStatusBadge from "@/components/shared/TriageStatusBadge.vue";

describe("TriageStatusBadge", () => {
  it("renders glyph + friendly label for concur", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "concur" } });
    expect(w.text()).toContain("Accept");
    expect(w.text()).toContain("●");
  });

  it("renders 'Closed (Accept)' when adjudicatedAt is present and status is concur", () => {
    const w = mount(TriageStatusBadge, {
      propsData: { status: "concur", adjudicatedAt: "2026-04-29T10:00:00Z" },
    });
    expect(w.text()).toContain("Closed");
    expect(w.text()).toContain("Accept");
  });

  it("marks the glyph aria-hidden so screen readers don't announce it", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "concur" } });
    const glyphEl = w.find("[data-test=glyph]");
    expect(glyphEl.attributes("aria-hidden")).toBe("true");
  });

  it("provides DISA tooltip on hover", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "non_concur" } });
    const root = w.find("[data-test=badge]");
    expect(root.attributes("title")).toMatch(/non.concur/i);
  });

  it("uses stable DISA key as CSS class hook", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "concur_with_comment" } });
    expect(w.find(".triage-status--concur_with_comment").exists()).toBe(true);
  });

  it("renders 'Duplicate of #N' when status=duplicate and duplicateOfId given", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "duplicate", duplicateOfId: 142 } });
    expect(w.text()).toContain("Duplicate of #142");
  });
});
```

`spec/javascript/components/shared/SectionLabel.spec.js`:

```javascript
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import SectionLabel from "@/components/shared/SectionLabel.vue";

describe("SectionLabel", () => {
  it("renders friendly label for an XCCDF key", () => {
    const w = mount(SectionLabel, { propsData: { section: "check_content" } });
    expect(w.text()).toBe("Check");
  });

  it("renders (general) for null", () => {
    const w = mount(SectionLabel, { propsData: { section: null } });
    expect(w.text()).toBe("(general)");
  });

  it("renders em-dash placeholder for null when 'placeholder' prop is set", () => {
    const w = mount(SectionLabel, { propsData: { section: null, placeholder: true } });
    expect(w.text()).toBe("—");
  });
});
```

## Step 2: Run to verify failure

```bash
pnpm vitest run spec/javascript/components/shared/TriageStatusBadge.spec.js \
                spec/javascript/components/shared/SectionLabel.spec.js
```

**Expected:** FAIL — components don't exist.

## Step 3: Create `app/javascript/components/shared/TriageStatusBadge.vue`

```vue
<template>
  <span
    data-test="badge"
    :class="['triage-status', cssClass]"
    :title="tooltip"
  >
    <span data-test="glyph" aria-hidden="true">{{ glyph }}</span>
    <span data-test="label">{{ displayLabel }}</span>
  </span>
</template>

<script>
import {
  triageDisplay,
  TRIAGE_LABELS,
  TRIAGE_DISA_LABELS,
  ADJUDICATED_LABEL,
  ADJUDICATED_GLYPH,
} from "../../constants/triageVocabulary";

export default {
  name: "TriageStatusBadge",
  props: {
    status: { type: String, required: true },
    adjudicatedAt: { type: [String, Date], default: null },
    duplicateOfId: { type: [Number, String], default: null },
  },
  computed: {
    isAdjudicated() {
      return Boolean(this.adjudicatedAt);
    },
    glyph() {
      if (this.isAdjudicated) return ADJUDICATED_GLYPH;
      return triageDisplay(this.status).glyph;
    },
    displayLabel() {
      if (this.status === "duplicate" && this.duplicateOfId) {
        return `Duplicate of #${this.duplicateOfId}`;
      }
      if (this.isAdjudicated) {
        return `${ADJUDICATED_LABEL} (${TRIAGE_LABELS[this.status] || this.status})`;
      }
      return TRIAGE_LABELS[this.status] || this.status;
    },
    tooltip() {
      const disa = TRIAGE_DISA_LABELS[this.status];
      return this.isAdjudicated ? `Adjudicated — ${disa}` : disa;
    },
    cssClass() {
      // Stable DISA-key class hook — never use friendly label as a CSS selector
      return `triage-status--${this.status}${this.isAdjudicated ? " triage-status--adjudicated" : ""}`;
    },
  },
};
</script>

<style scoped>
.triage-status {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.875rem;
  white-space: nowrap;
}
.triage-status > [data-test="glyph"] {
  font-size: 1em;
  line-height: 1;
}
</style>
```

## Step 4: Create `app/javascript/components/shared/SectionLabel.vue`

```vue
<template>
  <span class="section-label">{{ display }}</span>
</template>

<script>
import { sectionLabel } from "../../constants/triageVocabulary";

export default {
  name: "SectionLabel",
  props: {
    section: { type: String, default: null },
    placeholder: { type: Boolean, default: false },
  },
  computed: {
    display() {
      if (this.section === null || this.section === undefined || this.section === "") {
        return this.placeholder ? "—" : "(general)";
      }
      return sectionLabel(this.section);
    },
  },
};
</script>
```

## Step 5: Run specs to verify pass

```bash
pnpm vitest run spec/javascript/components/shared/TriageStatusBadge.spec.js \
                spec/javascript/components/shared/SectionLabel.spec.js
```

**Expected:** all PASS.

## Step 6: Lint

```bash
yarn lint
```

**Expected:** 0 warnings.

## Step 7: Vocabulary grep — ensure nothing leaked

```bash
grep -rnE "concur|adjudicat" app/javascript/components/shared/TriageStatusBadge.vue \
                              app/javascript/components/shared/SectionLabel.vue
# (Some hits expected — the words appear in CSS class hooks. Just sanity-check
# that no DISA labels are hardcoded for display.)

grep -nE "\"(Accept|Decline|Concur)\"" app/javascript/components/shared/*.vue
# Expected: zero matches — friendly labels come from triageVocabulary.js, never hardcoded.
```

## Step 8: Commit

```bash
cat > /tmp/msg-13.md <<'EOF'
feat: TriageStatusBadge + SectionLabel reusable Vue components

DRY pattern for the public-comment-review UI: every other component that
displays a triage status uses <TriageStatusBadge :status="..."
:adjudicated-at="..." /> instead of importing triageVocabulary directly.

The badge:
- Pairs glyph (aria-hidden) + visible text label per WCAG 1.4.1
- Renders "Closed (Accept)" when adjudicated, "Accept" otherwise
- Renders "Duplicate of #N" when status=duplicate
- Stable DISA-key CSS class hook (triage-status--concur, etc.) so a UI
  label change never breaks selectors or styling
- Tooltip surfaces the DISA-matrix term

SectionLabel renders friendly section names from XCCDF keys, with
configurable null rendering ("(general)" or "—").

Used by Tasks 14, 15, 18, 19, 20 — keeps display logic in one place.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/shared/TriageStatusBadge.vue \
        app/javascript/components/shared/SectionLabel.vue \
        spec/javascript/components/shared/TriageStatusBadge.spec.js \
        spec/javascript/components/shared/SectionLabel.spec.js
git commit -F /tmp/msg-13.md
rm /tmp/msg-13.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/13-frontend-vocabulary-module.md \
       docs/plans/PR717-public-comment-review/13-frontend-vocabulary-module-DONE.md
git commit -m "chore: mark plan task 13 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
