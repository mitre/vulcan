# Task 23: Comment counts surfaced on the existing Satisfies panel

**Depends on:** none (small additive enhancement to existing infra)
**Estimate:** 30 min Claude-pace
**File touches:**
- `app/blueprints/satisfaction_blueprint.rb` (add comment count fields)
- `app/blueprints/satisfied_by_blueprint.rb` (inherits, no further change needed)
- `app/javascript/components/rules/RuleSatisfactions.vue` (render counts)
- `spec/blueprints/satisfaction_blueprint_spec.rb` (extend or create)
- `spec/javascript/components/rules/RuleSatisfactions.spec.js` (extend or create)

## Why this task exists

The existing **Satisfies panel** in the rule editor already lists the
related rules (`rule.satisfies` and `rule.satisfied_by`). What it
doesn't show: how many comments live on each related rule. Triagers
have to click each related rule to find out.

Surfacing the per-related-rule count addresses cross-rule
discoverability without inventing a new "Related Rules" component or
auto-inheriting comment data. **Comments stay on the rule they were
posted on.** This task adds **read-only count badges** to the existing
relationship UI.

## Verified facts (read before editing)

- `RuleSatisfactions.vue` (`app/javascript/components/rules/`) already
  renders two sections: "Also Satisfies" (rule.satisfies, lines 4-73)
  and "Satisfied By" (rule.satisfied_by, lines 75+). Each row shows the
  SRG ID + an action button.
- `SatisfactionBlueprint` exposes `id`, `rule_id`, `srg_id`.
  `SatisfiedByBlueprint` extends it with `fixtext`.
- The existing `Review.top_level_comments` scope (from earlier PR-717
  work) is available for counting top-level reviews.
- Container SRG component 8 has 188 rules; some rules have multiple
  satisfies/satisfied_by relationships. Performance must stay bounded.

## Design decisions

- **Count top-level only** (`responding_to_review_id IS NULL`) —
  replies don't represent new pending work; they're part of an existing
  thread. Same rule used by `SectionCommentIcon.pendingCount`.
- **Two counts per related rule**: `total_comment_count` (all
  triage_statuses) and `pending_comment_count` (just pending). UI
  shows the pill primarily as the pending count; total is a hover
  tooltip.
- **Display only when count > 0** — don't add visual noise to rules
  with no comments.
- **No data movement, no inheritance** — counts are computed against
  the related rule's own reviews. The current rule's view is unchanged
  except for the badge in the Satisfies panel.

## Step 1: Failing spec — backend

Create / extend `spec/blueprints/satisfaction_blueprint_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe SatisfactionBlueprint do
  let(:component) { create(:component) }
  let(:user) { create(:user) }
  let(:rule_a) { create(:rule, component: component) }
  let(:rule_b) { create(:rule, component: component) }

  before do
    RuleSatisfaction.create!(rule_id: rule_a.id, satisfied_by_rule_id: rule_b.id)
    Review.create!(rule: rule_b, user: user, action: 'comment',
                   comment: 'pending one', triage_status: 'pending')
    Review.create!(rule: rule_b, user: user, action: 'comment',
                   comment: 'concur one', triage_status: 'concur')
    parent = Review.create!(rule: rule_b, user: user, action: 'comment',
                            comment: 'pending two', triage_status: 'pending')
    Review.create!(rule: rule_b, user: user, action: 'comment',
                   comment: 'a reply', triage_status: 'pending',
                   responding_to_review_id: parent.id)
  end

  it 'includes pending_comment_count and total_comment_count fields' do
    json = JSON.parse(SatisfactionBlueprint.render(rule_b))
    expect(json).to include('pending_comment_count', 'total_comment_count')
  end

  it 'counts top-level comments only (excludes replies)' do
    json = JSON.parse(SatisfactionBlueprint.render(rule_b))
    expect(json['total_comment_count']).to eq(3)  # 2 pending + 1 concur (reply excluded)
    expect(json['pending_comment_count']).to eq(2)
  end

  it 'returns 0 when the rule has no top-level comments' do
    rule_c = create(:rule, component: component)
    json = JSON.parse(SatisfactionBlueprint.render(rule_c))
    expect(json['pending_comment_count']).to eq(0)
    expect(json['total_comment_count']).to eq(0)
  end

  describe 'SatisfiedByBlueprint inherits the count fields' do
    it 'includes pending_comment_count' do
      json = JSON.parse(SatisfiedByBlueprint.render(rule_b))
      expect(json).to include('pending_comment_count', 'total_comment_count')
    end
  end
end
```

## Step 2: Run, FAIL

```bash
bundle exec rspec spec/blueprints/satisfaction_blueprint_spec.rb
```

## Step 3: Implement — backend

`app/blueprints/satisfaction_blueprint.rb`:

```ruby
# frozen_string_literal: true

# Lightweight blueprint for Rule satisfaction relationships (satisfies).
#
# PR #717 — comment counts are surfaced so the RuleSatisfactions panel
# can show triagers / commenters where prior conversation lives across
# related rules. Counts are computed against the *related* rule's own
# reviews — comments are NOT auto-inherited, only their counts are
# surfaced for cross-rule discoverability.
class SatisfactionBlueprint < Blueprinter::Base
  identifier :id
  field :rule_id
  field :srg_id do |rule, _options|
    rule.srg_rule&.version
  end

  field :pending_comment_count do |rule, _options|
    rule.reviews.where(action: 'comment',
                       responding_to_review_id: nil,
                       triage_status: 'pending').count
  end

  field :total_comment_count do |rule, _options|
    rule.reviews.where(action: 'comment', responding_to_review_id: nil).count
  end
end
```

`app/blueprints/satisfied_by_blueprint.rb` already inherits — no change needed.

## Step 4: Run, GREEN

```bash
bundle exec rspec spec/blueprints/satisfaction_blueprint_spec.rb
```

## Step 5: Eager-load to keep query count bounded

In `app/controllers/components_controller.rb`, the `set_component`
method already eager-loads many associations. Verify
`rules: { satisfies: :reviews, satisfied_by: :reviews }` (or equivalent)
is part of the eager-load so we don't N+1 on the Satisfies panel.

If not, add it:

```ruby
@component = Component.eager_load(
  rules: [..., satisfies: :reviews, satisfied_by: :reviews]
).find_by(id: params[:id])
```

Run the existing query-performance spec to confirm:

```bash
bundle exec rspec spec/models/query_performance_spec.rb
```

## Step 6: Failing spec — frontend

Append to `spec/javascript/components/rules/RuleSatisfactions.spec.js`
(create if missing):

```javascript
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleSatisfactions from "@/components/rules/RuleSatisfactions.vue";

describe("RuleSatisfactions — PR #717 comment count badges", () => {
  const baseRule = {
    id: 1,
    status: "Applicable - Configurable",
    satisfies: [],
    satisfied_by: [],
  };

  it("renders a pending-count badge on each satisfies row that has comments", () => {
    const rule = {
      ...baseRule,
      satisfies: [
        { id: 99, rule_id: "000099", srg_id: "SRG-X", pending_comment_count: 3, total_comment_count: 5 },
        { id: 100, rule_id: "000100", srg_id: "SRG-Y", pending_comment_count: 0, total_comment_count: 0 },
      ],
    };
    const w = mount(RuleSatisfactions, {
      localVue,
      propsData: { rule, readOnly: false },
    });
    // Row with comments shows count badge
    expect(w.text()).toMatch(/3 pending/i);
    // Row without comments does NOT show a badge
    const html = w.html();
    expect(html).not.toMatch(/0 pending/);
  });

  it("renders a pending-count badge on each satisfied_by row that has comments", () => {
    const rule = {
      ...baseRule,
      satisfied_by: [
        { id: 200, rule_id: "000200", srg_id: "SRG-Z", pending_comment_count: 2, total_comment_count: 2 },
      ],
    };
    const w = mount(RuleSatisfactions, {
      localVue,
      propsData: { rule, readOnly: true },
    });
    expect(w.text()).toMatch(/2 pending/i);
  });

  it("uses the matching FilterDropdown / icon-pattern visual treatment for the count badge", () => {
    // Specifically: chat-left-text icon (matches lock/info family) +
    // text-primary color (matches active comment icon when pending > 0).
    const rule = {
      ...baseRule,
      satisfies: [
        { id: 99, rule_id: "000099", srg_id: "SRG-X", pending_comment_count: 3, total_comment_count: 5 },
      ],
    };
    const w = mount(RuleSatisfactions, {
      localVue,
      propsData: { rule, readOnly: false },
    });
    // The badge wrapper has a stable data-test selector for spec stability.
    expect(w.find('[data-test="related-rule-comment-count-99"]').exists()).toBe(true);
  });
});
```

## Step 7: Implement — frontend

In `RuleSatisfactions.vue`, add a small badge inline with each row's
SRG ID display. Style consistent with `SectionCommentIcon` (chat icon
+ pill badge):

```vue
<!-- Inside the v-for over satisfies (line 27) and satisfied_by (~line 80) -->
<span
  v-if="related.pending_comment_count > 0"
  v-b-tooltip.hover
  :title="`${related.total_comment_count} total comment${related.total_comment_count === 1 ? '' : 's'} on this rule`"
  :data-test="`related-rule-comment-count-${related.id}`"
  class="ml-2"
>
  <b-icon icon="chat-left-text" class="text-primary" />
  <b-badge variant="primary" pill class="ml-1">{{ related.pending_comment_count }} pending</b-badge>
</span>
```

(`related` here is the loop variable — `satisfies` in the satisfies block, the satisfied_by row in the satisfied_by block. Refactor variable names if needed.)

## Step 8: Run, GREEN, lint

```bash
pnpm vitest run spec/javascript/components/rules/RuleSatisfactions.spec.js
yarn lint app/javascript/components/rules/RuleSatisfactions.vue
```

## Step 9: Vocabulary check

```bash
grep -nE "concur|adjudicat" app/javascript/components/rules/RuleSatisfactions.vue \
  | grep -v -i "triage-status\|adjudicated_at\|adjudicatedAt"
```

Expected: no matches.

## Step 10: Commit

```bash
cat > /tmp/msg-23.md <<'EOF'
Feat: comment counts on the existing Satisfies panel

Cross-rule discoverability without auto-inheritance. The Satisfies
panel in the rule editor already lists related rules (rule.satisfies
and rule.satisfied_by). This adds a small comment-count badge on each
row when that related rule has top-level comments — so triagers can
see at a glance which related rules have prior conversation, without
clicking through.

Comments are NOT merged or inherited. They stay on their original
rule. This task only surfaces COUNTS via the existing
SatisfactionBlueprint and SatisfiedByBlueprint — the relationship
data layer is unchanged.

Top-level comments only (excludes replies); pending count + total
count both available, pending shown as the pill, total in the
hover tooltip.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/blueprints/satisfaction_blueprint.rb \
        app/javascript/components/rules/RuleSatisfactions.vue \
        spec/blueprints/satisfaction_blueprint_spec.rb \
        spec/javascript/components/rules/RuleSatisfactions.spec.js
git commit -F /tmp/msg-23.md
rm /tmp/msg-23.md

git mv docs/plans/PR717-public-comment-review/23-satisfies-panel-comment-counts.md \
       docs/plans/PR717-public-comment-review/23-satisfies-panel-comment-counts-DONE.md
git commit -m "Chore: mark plan task 23 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

## Acceptance criteria

- [ ] `SatisfactionBlueprint` exposes `pending_comment_count` and `total_comment_count`
- [ ] `SatisfiedByBlueprint` inherits the count fields (no direct change)
- [ ] Counts are top-level only (replies excluded)
- [ ] `RuleSatisfactions.vue` renders the badge only when pending > 0
- [ ] Visual treatment matches `SectionCommentIcon` family (chat-left-text + text-primary + pending pill)
- [ ] Tooltip shows total count with proper pluralization
- [ ] Eager loading keeps query count bounded for components with many satisfies (Container SRG ~188 rules)
- [ ] No vocabulary leaks (DISA terms only in storage; friendly English in UI)
- [ ] No regression on existing rule editor / satisfies tests
