# Task 27: Cross-rule smoke test scenarios + Task 99 acceptance update

**Depends on:** 23, 24 (NOT 25, 26 — those deferred to a follow-up phase per the 2026-04-29 plan review)
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
# Reviews are created. Use the same HABTM push pattern the surrounding
# seed code uses (see db/seeds.rb:262 for reference):
if container_component.rules.count >= 6
  baseline_rule = container_component.rules.order(:rule_id).first  # rule_a
  implementation_rule = container_component.rules.order(:rule_id).limit(6).last

  if implementation_rule && baseline_rule.satisfied_by.exclude?(implementation_rule)
    baseline_rule.satisfied_by << implementation_rule

    # Pre-existing comment on the implementation rule so the baseline
    # rule's Satisfies panel shows a "comments here" badge for cross-rule
    # discoverability testing.
    Review.create!(
      user: viewer_user, rule: implementation_rule, action: 'comment',
      comment: 'Implementation rule has its own concern about cipher list configuration.',
      section: 'check_content', triage_status: 'pending'
    )

    puts '  Seeded baseline ↔ implementation satisfies link with cross-rule comments'
  end
end
```

## Step 2: Extend Task 99 §6 (manual smoke test)

Add a new subsection §6.7 — Cross-rule scenarios:

```markdown
### 6.7 Cross-rule comment flows (PR #717 Tasks 23, 24)

These scenarios exercise the comments-as-objects philosophy + the
existing satisfies relationship as discoverability surface. Tasks 25
and 26 (admin force-withdraw, admin move-to-rule) are deferred to a
follow-up phase; for those, see
`docs/runbook-public-comment-admin-actions.md` console operations and
the smoke scenarios at §6.7.4 / §6.7.6 below covering the runbook
actions instead of UI buttons.

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

#### 6.7.4 Admin force-withdraw via runbook console (deferred Task 25)

UI is deferred. Verify the console procedure in
`docs/runbook-public-comment-admin-actions.md §1` works against the
seed data:

1. Open `bundle exec rails console` as a user with admin role.
2. Run the runbook §1 snippet against a seeded pending comment.
3. Verify the comment row in the triage queue now shows "Withdrawn"
   status with admin attribution.
4. Run `Review.find(<id>).audits.last.comment` — confirm the audit
   log captures the reason text.

#### 6.7.5 Admin force-withdraw — non-admin protection

The runbook authorization check (`admin.can_admin_project?(...)`)
must stop a non-admin from running the same procedure:

1. As an `author`-role user, open the rails console and attempt the
   runbook §1 commands.
2. Confirm the `unless admin.can_admin_project?(...)` guard raises
   "Not authorized" before any update happens.

#### 6.7.6 Admin move-to-rule via runbook console (deferred Task 26)

UI is deferred. Verify the console procedure in runbook §2:

1. Pick a seeded comment that has at least one reply.
2. Run runbook §2's `move_subtree` snippet (children-first walk
   inside a transaction) to move the parent + replies to a different
   rule in the same component.
3. Refresh both the source rule's reviews thread and the target
   rule's reviews thread:
   - Source no longer shows the comment OR its reply
   - Target shows BOTH the comment + the reply, with the thread
     intact
4. Confirm the `responding_to_must_be_same_rule` validator did NOT
   reject during the move (children-first ordering satisfied it).
5. Note: per runbook §2, `rule_id` is NOT in `vulcan_audited only:`
   today — when Task 26 ships in a follow-up phase, the audit list
   is extended.

#### 6.7.7 Move-to-rule preserves triage state (deferred Task 26)

1. Pick a comment whose triage_status is `concur` and adjudicated_at is set.
2. Use runbook §2 to move it to a different rule in the same component.
3. Verify on the target rule: triage_status, adjudicated_at, and
   adjudicated_by_id are unchanged. Only rule_id changed.

#### 6.7.8 Mid-review relationship change (regression scenario)

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

(Already updated to reference 25 tasks — 1-22 + 23, 24, 27 — when the
plan files were tightened on 2026-04-30. Tasks 25 + 26 deferred to a
follow-up phase per the agent-review pass; the runbook covers their
console procedures.)

## Step 4: Confirm F1/F2/F3 follow-up framing

Verify the Task 99 "Live-test follow-ups" section has all three
deferrals documented:
- **F1**: STIG/SRG dropdowns to FilterDropdown (cross-cutting, deferred)
- **F2**: Turbolinks Vue pack-mount race proper fix (workaround in place)
- **F3**: Admin comment-object UI (Tasks 25 + 26 — runbook covers v1)

These are NOT merge-blocking for PR #717. They're explicit follow-ups
for a future phase.

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
- [ ] Task 99 §6.7 documents 8 cross-rule smoke scenarios (6.7.1–6.7.8)
- [ ] All 8 scenarios pass during a manual smoke run
- [ ] F1/F2/F3 documented as follow-up-phase items (not blocking merge);
      F3 cross-references the admin runbook for console procedures
- [ ] Final acceptance criteria header references 25 tasks (1-22 + 23, 24, 27)
- [ ] Smoke test runs cleanly end-to-end before PR is marked ready to merge
