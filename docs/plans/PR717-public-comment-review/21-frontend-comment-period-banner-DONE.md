# Task 21: CommentPeriodBanner.vue on Component page

**Depends on:** 05, 13
**Estimate:** 20 min Claude-pace
**File touches:**
- `app/javascript/components/components/CommentPeriodBanner.vue` (new)
- `app/javascript/components/components/ProjectComponent.vue` (mount the banner)
- `spec/javascript/components/components/CommentPeriodBanner.spec.js` (new)

Sticky-for-viewers, dismissable-for-triagers banner at top of Component page during the open phase. Mockup: design §2.7.1.

---

## Step 1: Failing spec (concise)

```javascript
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import CommentPeriodBanner from "@/components/components/CommentPeriodBanner.vue";

describe("CommentPeriodBanner", () => {
  it("renders nothing when phase is draft", () => {
    const w = mount(CommentPeriodBanner, { propsData: { component: { comment_phase: "draft" } } });
    expect(w.html()).toBe("");
  });

  it("renders 'Open for comment' with days remaining", () => {
    const ends = new Date(Date.now() + 16 * 86400000).toISOString();
    const w = mount(CommentPeriodBanner, {
      propsData: { component: { comment_phase: "open", comment_period_ends_at: ends, pending_count: 12 } },
      stubs: ["b-alert"],
    });
    expect(w.text()).toContain("Open for comment");
    expect(w.text()).toMatch(/16 days remaining/);
    expect(w.text()).toMatch(/12 pending/);
  });

  it("renders 'Adjudication' label when phase is adjudication", () => {
    const w = mount(CommentPeriodBanner, {
      propsData: { component: { comment_phase: "adjudication" } },
      stubs: ["b-alert"],
    });
    expect(w.text()).toContain("Adjudication");
  });

  it("uses role=status for screen readers", () => {
    const w = mount(CommentPeriodBanner, {
      propsData: { component: { comment_phase: "open" } },
    });
    expect(w.find('[role="status"]').exists()).toBe(true);
  });
});
```

## Step 2: Run, FAIL

## Step 3: Create `CommentPeriodBanner.vue`

```vue
<template>
  <b-alert
    v-if="component && component.comment_phase !== 'draft'"
    show
    :variant="bannerVariant"
    role="status"
    class="mb-3"
  >
    <strong>{{ phaseLabel }}</strong>
    <template v-if="daysRemaining !== null">
      · {{ daysRemaining }} days remaining
      <span class="text-muted">(closes {{ friendlyDate(component.comment_period_ends_at) }})</span>
    </template>
    <template v-if="component.pending_count != null">
      <br />
      {{ component.pending_count }} pending comments awaiting triage
      <a href="#" @click.prevent="$emit('open-comments-panel')">[Open Comments panel →]</a>
    </template>
  </b-alert>
</template>

<script>
import { COMMENT_PHASE_LABELS } from "../../constants/triageVocabulary";

export default {
  name: "CommentPeriodBanner",
  props: {
    component: { type: Object, required: true },
  },
  computed: {
    phaseLabel() {
      return COMMENT_PHASE_LABELS[this.component.comment_phase] || this.component.comment_phase;
    },
    daysRemaining() {
      if (this.component.comment_phase !== "open" || !this.component.comment_period_ends_at) return null;
      const ms = new Date(this.component.comment_period_ends_at).getTime() - Date.now();
      return Math.ceil(ms / 86400000);
    },
    bannerVariant() {
      if (this.component.comment_phase === "open") return "info";
      if (this.component.comment_phase === "adjudication") return "warning";
      return "secondary";
    },
  },
  methods: {
    friendlyDate(iso) { return iso ? new Date(iso).toLocaleDateString() : ""; },
  },
};
</script>
```

## Step 4: Mount in `ProjectComponent.vue`

At the top of the component page template, before the rule list:

```html
<CommentPeriodBanner :component="component" @open-comments-panel="openCommentsPanel" />
```

`openCommentsPanel` opens the existing comp-reviews slideover.

The `pending_count` field needs to come from the existing `ComponentBlueprint` payload — extend that blueprint to include `pending_count: lambda { |c| c.reviews.top_level_comments.where(triage_status: 'pending').count }` (small additional query — or fold into the existing reviews query if there's a counter cache). Or fetch separately on mount.

## Step 5: Run, lint, commit

```bash
pnpm vitest run spec/javascript/components/components/CommentPeriodBanner.spec.js
yarn lint

cat > /tmp/msg-21.md <<'EOF'
feat: CommentPeriodBanner on Component page

Banner at top of Component page surfacing the comment phase + days
remaining + pending triage count. Variant changes by phase: info for
open, warning for adjudication.

role="status" makes phase changes audible for screen readers (WCAG
4.1.3). Phase labels rendered via COMMENT_PHASE_LABELS from
triageVocabulary.js — "Open for comment", "Adjudication", "Final".

[Open Comments panel →] link emits to ProjectComponent which opens the
existing comp-reviews slideover (now backed by the triage table from
Task 14).

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/components/CommentPeriodBanner.vue \
        app/javascript/components/components/ProjectComponent.vue \
        app/blueprints/component_blueprint.rb \
        spec/javascript/components/components/CommentPeriodBanner.spec.js
git commit -F /tmp/msg-21.md
rm /tmp/msg-21.md
git mv docs/plans/PR717-public-comment-review/21-frontend-comment-period-banner.md \
       docs/plans/PR717-public-comment-review/21-frontend-comment-period-banner-DONE.md
git commit -m "chore: mark plan task 21 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
