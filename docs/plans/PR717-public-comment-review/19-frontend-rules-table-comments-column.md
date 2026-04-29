# Task 19: RuleNavigator — comment-count badge per rule

**Depends on:** 11, 13
**Estimate:** 25 min Claude-pace
**File touches:**
- `app/javascript/components/rules/RuleNavigator.vue` (modify — add badge alongside existing icons)
- `spec/javascript/components/rules/RuleNavigator.spec.js` (extend or create)

**Verified facts (corrected from initial guess):**
- There is **no `RulesTable.vue`**. The "rule list" on the Component page is **`RuleNavigator.vue`**, a left-sidebar tree, not a table.
- It already renders icons next to each rule row (review_requestor_id → file-earmark-search, locked → lock, changes_requested → exclamation-triangle, satisfies/satisfied_by) — see `RuleNavigator.vue:60-94`.
- Rule rows are rendered in two `v-for` blocks: lines 46 (`openRules`) and 120 (`filteredRules`).
- We add ONE more icon: a comment-count badge alongside the existing icons.

The "Show only rules with pending comments" filter belongs in the Filter & Search section (`RuleNavigator.vue:13-27`), or — cleaner — as an external filter passed in via `:external-filters` from `ProjectComponent.vue:23` (the existing pattern for filter coordination).

---

## Step 1: Failing spec

Append to `spec/javascript/components/rules/RuleNavigator.spec.js` (create if absent):

```javascript
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import RuleNavigator from "@/components/rules/RuleNavigator.vue";

describe("RuleNavigator — comment-count badge", () => {
  const ruleWithPending = {
    id: 1, rule_id: "000010", srg_id: "SRG-OS-000050",
    satisfies: [], satisfied_by: [], locked: false, changes_requested: false,
    review_requestor_id: null, comment_summary: { pending: 3, concur: 0, adjudicated: 0 },
  };
  const ruleNoComments = { ...ruleWithPending, id: 2, rule_id: "000020", comment_summary: {} };

  const baseProps = {
    componentId: 42,
    rules: [ruleWithPending, ruleNoComments],
    selectedRuleId: null,
    effectivePermissions: "viewer",
    projectPrefix: "ABC-DE",
    readOnly: true,
    openRuleIds: [],
    externalFilters: { showSRGIdChecked: false, pendingCommentsOnly: false },
  };

  it("renders a comment-count badge when pending > 0", () => {
    const w = mount(RuleNavigator, { propsData: baseProps });
    const ruleRow = w.findAll("[data-rule-id='1']").wrappers[0] || w.find(".rule-row-1");
    // either query — adjust to actual DOM. Source of truth: render contains "💬 3"
    expect(w.text()).toMatch(/💬\s*3/);
  });

  it("does NOT render a comment-count badge when comments empty", () => {
    const w = mount(RuleNavigator, { propsData: baseProps });
    // Rule 2 has no comments — find its row by rule_id text and assert no 💬 nearby
    const html = w.html();
    const rule2Idx = html.indexOf("000020");
    const surrounding = html.slice(Math.max(0, rule2Idx - 200), rule2Idx + 200);
    expect(surrounding).not.toMatch(/💬/);
  });

  it("filters to rules with pending comments when pendingCommentsOnly=true", async () => {
    const w = mount(RuleNavigator, {
      propsData: { ...baseProps, externalFilters: { ...baseProps.externalFilters, pendingCommentsOnly: true } },
    });
    expect(w.text()).toContain("000010");      // has pending — visible
    expect(w.text()).not.toContain("000020");  // no comments — hidden
  });
});
```

## Step 2: Run to verify FAIL

```bash
pnpm vitest run spec/javascript/components/rules/RuleNavigator.spec.js
```

## Step 3: Update `RuleNavigator.vue` — add badge inline with existing icons

In the existing rule-row icon area (lines 60-94 — the `<span>` containing `<i v-if="rule.satisfies.length > 0">` etc.), add a new icon BEFORE the existing icons:

```vue
<span
  v-if="ruleHasPending(rule)"
  v-b-tooltip.hover
  :title="`${ruleCommentSummary(rule).pending} pending comments`"
  class="text-primary mr-1"
  aria-label="Has pending comments"
>
  <span aria-hidden="true">💬</span>
  {{ ruleCommentSummary(rule).pending }}
</span>
```

Add helper methods (in the existing `methods:` block, or `computed:` if preferred):

```javascript
methods: {
  // ...existing methods...
  ruleCommentSummary(rule) {
    return rule.comment_summary || {};
  },
  ruleHasPending(rule) {
    return (this.ruleCommentSummary(rule).pending || 0) > 0;
  },
},
```

Apply to **both** `v-for` blocks (line 46 `openRules` and line 120 `filteredRules`) — the same icon pattern lives in both places.

## Step 4: Add the "Show only rules with pending comments" filter

Two options — pick whichever matches the existing filter pattern best.

### Option A (recommended — follows external-filters pattern)

Extend the `external-filters` prop sent from `ProjectComponent.vue` to include a `pendingCommentsOnly` boolean. RuleNavigator already accepts `externalFilters` per the `:external-filters="filters"` binding at `ProjectComponent.vue:23` (read it to confirm).

In `RuleNavigator.vue`'s computed `filteredRules`, add:

```javascript
filteredRules() {
  let result = this.rules;
  // ...existing filter chain...
  if (this.externalFilters?.pendingCommentsOnly) {
    result = result.filter((r) => (r.comment_summary?.pending || 0) > 0);
  }
  return result;
},
```

In `RuleFilterBar.vue` (the existing filter UI used by `ProjectComponent.vue:30-37`), add a checkbox:

```vue
<b-form-checkbox v-model="filters.pendingCommentsOnly" switch>
  Pending comments only
</b-form-checkbox>
```

### Option B (simpler — local filter)

Add the toggle directly inside `RuleNavigator.vue`'s Filter & Search block (lines 13-27).

```vue
<b-form-checkbox v-model="pendingCommentsOnly" switch class="mt-1">
  Pending comments only
</b-form-checkbox>
```

Add `pendingCommentsOnly: false` to `data()` and use it in `filteredRules`.

**Pick Option A** if the existing filter pattern routes through external-filters consistently; Option B if not. Verify by reading `RuleFilterBar.vue` first.

## Step 5: Wire the comment_summary into the rules payload

The `rule.comment_summary` field needs to be populated. Two options:

### 5a (recommended — server-side)

Extend the `RuleBlueprint` (or wherever rules are serialized for `:initial-component-state`) to include a `comment_summary` field. Aggregate via a single query in `Component#load_rules_with_comment_summary` (or fold into the existing query that returns the rules payload).

```ruby
# In whatever method assembles @component_json, before serialization:
counts = Review.top_level_comments
               .joins(:rule)
               .where(rules: { component_id: @component.id })
               .group(:rule_id, :triage_status, 'reviews.adjudicated_at IS NULL')
               .count
# counts is { [rule_id, status, is_open] => N } — fold into per-rule summary
```

### 5b (simpler — client-side fetch on mount)

In `ProjectComponent.vue`'s mount, fetch `GET /components/:id/comments?triage_status=all&per_page=1000`, group by rule_id, and merge into the rules array. Lower performance per page-load but isolates the change.

**Pick 5a** if the rules payload is assembled in one place; 5b if rules come from multiple sources.

## Step 6: Run specs + lint

```bash
pnpm vitest run spec/javascript/components/rules/RuleNavigator.spec.js
pnpm vitest run    # full suite
yarn lint
```

## Step 7: Commit

```bash
cat > /tmp/msg-19.md <<'EOF'
feat: comment-count badge on RuleNavigator rule rows

Adds a 💬 N indicator next to each rule's existing icon stack (alongside
locked / changes_requested / review_requestor_id) when the rule has
pending top-level comments. Cheap signal for triagers scanning the
sidebar.

Adds "Pending comments only" filter to the existing rule filter UI —
narrows the navigator to rules that need attention this triage session.

comment_summary is populated server-side via a Reviews aggregation in
the rules-payload assembly. Per-rule client cost is one tiny object
({ pending, concur, ..., adjudicated }) — negligible payload bloat.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/rules/RuleNavigator.vue \
        app/javascript/components/rules/RuleFilterBar.vue \
        app/blueprints/rule_blueprint.rb \
        spec/javascript/components/rules/RuleNavigator.spec.js
git commit -F /tmp/msg-19.md
rm /tmp/msg-19.md

git mv docs/plans/PR717-public-comment-review/19-frontend-rules-table-comments-column.md \
       docs/plans/PR717-public-comment-review/19-frontend-rule-navigator-comments-DONE.md
git commit -m "chore: mark plan task 19 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## Why this is different from what I originally wrote

The first draft of this task assumed a Vue `RulesTable.vue` component with sortable columns. That doesn't exist. The rule list is a navigator/tree (`RuleNavigator.vue`). This task now adds a badge to the existing per-row icon stack — a much smaller, more contained change that fits Vulcan's actual UI.
