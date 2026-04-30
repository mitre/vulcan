# Task 27: Cross-rule smoke test scenarios + Task 99 acceptance update

**Depends on:** 23, 24, 25, 26
**Estimate:** 30 min Claude-pace (15 min for the Task 99 doc edit + 15 min for ad-hoc smoke run)
**File touches:**
- `docs/plans/PR717-public-comment-review/99-final-test-sweep-and-acceptance.md` (extend)
- `db/seeds.rb` (extend with cross-rule scenario data — satisfies links + comments to exercise the new flows)

## Why this task exists

The Container SRG window is the first public showing of these features.
Task 99 (final test sweep + acceptance) needs explicit scenarios that
exercise the cross-rule comment flows — not just "everything works for
a single rule" but "everything works across the satisfies graph,
duplicates, admin overrides, and moves."

## Step 1: Extend `db/seeds.rb` with cross-rule scenarios

Add a satisfies relationship between two seeded rules in the Container
Platform component, plus comments on each, so the smoke test can
exercise the cross-rule UI without manual setup:

```ruby
# Inside the Container Platform comment-seed block, after the existing
# Reviews are created:
if container_component.rules.count >= 6
  baseline_rule = container_component.rules.order(:rule_id).first  # rule_a
  implementation_rule = container_component.rules.order(:rule_id).limit(6).last

  unless baseline_rule.satisfied_by.include?(implementation_rule)
    RuleSatisfaction.find_or_create_by!(
      rule_id: baseline_rule.id,
      satisfied_by_rule_id: implementation_rule.id
    )

    # Pre-existing comment on the implementation rule so the baseline
    # rule's Satisfies panel shows a "comments here" badge for cross-rule
    # discoverability testing.
    Review.create!(
      user: viewer_user, rule: implementation_rule, action: 'comment',
      comment: 'Implementation rule has its own concern about cipher list configuration.',
      section: 'check_content', triage_status: 'pending'
    )
  end

  puts '  Seeded baseline ↔ implementation satisfies link with cross-rule comments'
end
```

## Step 2: Extend Task 99 §6 (manual smoke test)

Add a new subsection §6.7 — Cross-rule scenarios:

```markdown
### 6.7 Cross-rule comment flows (PR #717 Tasks 23-26)

These scenarios exercise the comments-as-objects philosophy + the
existing satisfies relationship as discoverability surface.

#### 6.7.1 Satisfies panel shows comment counts (Task 23)

1. Sign in as a project member of Container Platform.
2. Open rule CNTR-01-000001 (the seeded baseline) in the rule editor.
3. Scroll to the "Satisfies" panel on the right.
4. Confirm the implementation rule listed under "Satisfied By" shows a
   `💬 N pending` badge — N matches the seed data on that rule.
5. Hover the badge — tooltip shows "X total comments on this rule".
6. Click the implementation rule name → navigates to that rule's
   editor; verify its own comments are visible there (NOT
   inherited / not shown on the baseline).

#### 6.7.2 Mark-as-duplicate flow (Task 24)

1. Sign in as a triager (author+ on Container Platform).
2. Open the triage queue (Comments panel).
3. Pick a pending comment (the duplicate-target).
4. Click `[Triage]` → modal opens.
5. Select "Mark as duplicate of..." decision option.
6. Picker appears; search for or select a different pending comment as
   the canonical (try one on a related rule via satisfies — the search
   should find it scoped to the same component).
7. Provide an audit comment, save.
8. Verify the row in the triage table now shows
   `Duplicate of #X` badge with link to the canonical.
9. Adjudicate the canonical (e.g. concur) → verify the duplicate row
   shows "Closed via canonical #X" / effective_adjudicated_at derived.

#### 6.7.3 Mark-as-duplicate validation (Task 24)

Try each invalid case and confirm the server rejects:
- Self-reference (canonical = same review): UI should disable + server returns 422
- Cross-component canonical: server returns 422 with a friendly message
- Chained duplicate (canonical itself is a duplicate): server returns 422

#### 6.7.4 Admin force-withdraw (Task 25)

1. Sign in as a project admin of Container Platform.
2. Open a pending comment in the triage modal.
3. Open the "Admin actions" disclosure.
4. Click "Force-withdraw" → audit comment field appears.
5. Enter a reason (try blank first — Confirm should be disabled).
6. Confirm → comment row updates to "Withdrawn", with admin
   attribution shown (adjudicated_by_id = admin).
7. Verify the audit log on the comment shows the admin override with
   the reason text.

#### 6.7.5 Admin force-withdraw permission (Task 25)

1. Sign in as an author (not admin) on Container Platform.
2. Open the triage modal.
3. Confirm the "Admin actions" disclosure is NOT visible.
4. Try the endpoint directly via curl with the author's session →
   server returns 403.

#### 6.7.6 Admin move-to-rule + replies follow parent (Task 26)

1. As admin, find a comment that has a reply (the seeded
   `triage_set_by` triager-response counts).
2. Open the triage modal → Admin actions → "Move to rule".
3. Pick a different rule in the same component (the picker should
   only show same-component rules; cross-component picks are
   prevented).
4. Provide an audit comment, confirm.
5. Refresh both the source rule's reviews thread and the target
   rule's reviews thread:
   - Source no longer shows the comment OR its reply
   - Target shows BOTH the comment + the reply, with the thread
     intact
6. Open the audit log on the moved comment + reply — verify the move
   is recorded on each.

#### 6.7.7 Move-to-rule validation (Task 26)

- Same-rule target: rejected
- Cross-component target: rejected
- Missing target rule (deleted): 404
- Blank audit comment: rejected

#### 6.7.8 Move-to-rule preserves triage state (Task 26)

1. Pick a comment whose triage_status is `concur` and adjudicated_at is set.
2. Move it to a different rule in the same component.
3. Verify on the target rule: triage_status, adjudicated_at, and
   adjudicated_by_id are unchanged. Only rule_id changed.

#### 6.7.9 Mid-review relationship change (regression scenario)

This is the scenario that originally surfaced the cross-rule design
question. Verify our chosen design (comments-as-objects, no auto-
inheritance) behaves predictably:

1. Pick rule X with no satisfies relationships and post a comment.
2. As an author, add X.satisfied_by → Y.
3. Refresh X's editor.
4. Confirm: X's existing comment is STILL on X (didn't move).
5. Confirm: X's "Satisfies" panel now shows Y, with whatever comment
   counts Y has.
6. Confirm: X's pending count badges (section icons) are unchanged
   (Y's comments are NOT auto-inherited).
7. Remove the X.satisfied_by link.
8. Refresh — Satisfies panel updates; X's comments still untouched.
```

## Step 3: Update Task 99 acceptance criteria header

Replace:
- `[ ] All 22 implementation tasks are committed and marked DONE`

With:
- `[ ] All 26 implementation tasks (1-22 + 23-26) are committed and marked DONE`

(Task 27 is itself the smoke test + acceptance update, so it's
self-referential — its DONE state coincides with running the smoke
successfully.)

## Step 4: Move F1/F2 follow-ups firmly to v2

In the existing "Live-test follow-ups" section of Task 99, change the
"deferred, not merge-blocking" framing for F1 (STIG/SRG dropdowns) and
F2 (turbolinks pack-mount race) to "**v2 follow-ups, not part of PR
#717**" — they're cross-cutting infrastructure, not satisfies-comment
core like Tasks 23-26 are.

## Step 5: Commit + DONE rename

```bash
git add db/seeds.rb \
        docs/plans/PR717-public-comment-review/99-final-test-sweep-and-acceptance.md
git commit -m "Docs+seeds: cross-rule smoke test scenarios for PR #717

Extends Task 99 with the cross-rule comment flow scenarios that
exercise Tasks 23-26 (Satisfies panel comment counts,
mark-as-duplicate, admin force-withdraw, admin move-to-rule) plus
the mid-review relationship-change regression scenario.

Seeds a baseline ↔ implementation satisfies link in Container
Platform with comments on the implementation rule so the cross-rule
smoke test runs against realistic data without manual setup.

Authored by: Aaron Lippold<lippold@gmail.com>"

git mv docs/plans/PR717-public-comment-review/27-cross-rule-smoke-test-and-task-99-update.md \
       docs/plans/PR717-public-comment-review/27-cross-rule-smoke-test-and-task-99-update-DONE.md
git commit -m "Chore: mark plan task 27 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

## Acceptance criteria

- [ ] Container Platform seeds include a baseline ↔ implementation
      satisfies link with cross-rule comments
- [ ] Task 99 §6.7 documents 9 cross-rule smoke scenarios
- [ ] All 9 scenarios pass during a manual smoke run
- [ ] F1/F2 framed as v2 follow-ups (not blocking merge)
- [ ] Final acceptance criteria header updated to reference Tasks 1-26
- [ ] Smoke test runs cleanly end-to-end before PR is marked ready to merge
