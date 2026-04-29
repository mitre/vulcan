# Task 99: Final test sweep + acceptance + post-implementation actions

**Depends on:** all of 01–22
**Estimate:** 30 min Claude-pace + ~15 min for the manual smoke test
**This is NOT a TDD task.** It's the comprehensive verification before declaring the PR ready for merge.

---

## Step 1: Run the full backend test suite

```bash
bundle exec parallel_rspec spec/
```

**Expected:** 0 failures across ~660+ examples (Vulcan's parallel_rspec runs ~60s; serial takes ~5min — ALWAYS use parallel).

If failures appear that aren't from work in this PR — surface to user. Don't paper over pre-existing failures, but also don't try to fix them in this PR.

If failures are from this PR's work, root-cause:
- Test issue (incorrect expectation)?
- Code issue (real bug)?
- Fixture issue (test data problem)?

Fix the actual problem, never test around it.

## Step 2: Run the full frontend test suite

```bash
pnpm vitest run
```

**Expected:** 0 failures across all Vue tests including new ones from Tasks 13-22.

## Step 3: Linting

```bash
bundle exec rubocop --autocorrect-all
yarn lint
```

**Expected:** 0 offenses, 0 warnings. If autocorrect changes anything, re-run the test suite to confirm correctness.

## Step 4: Security scan

```bash
bundle exec brakeman --no-pager
bundle exec bundler-audit
```

**Expected:** no NEW warnings introduced by this PR. Pre-existing findings (if any) are not in scope.

## Step 5: Vocabulary grep verification (final pass)

Run all five checks from `98-vocabulary-grep-verification.md`:

```bash
# (a) DISA in templates
grep -rnE "concur|adjudicat|non.concur" app/javascript/components app/views \
  | grep -v triageVocabulary | grep -v locales/en.yml \
  | grep -v CommentTriageModal | grep -v "triage-status--"

# (b) friendly labels in backend
grep -rnE "\"(accept|decline|closed)\"" app/models app/controllers db/migrate

# (c) en.yml ↔ js parity
ruby -ryaml -e '...'  # see 98 for body

# (d) CSS hooks
grep -rnE 'class="[^"]*triage-status--(accept|decline|closed)' app/javascript app/views

# (e) status coverage
ruby -ryaml -e '...'  # see 98
```

**Expected:** all five clean.

## Step 6: Manual browser smoke test

Run the dev server:

```bash
foreman start -f Procfile.dev
```

In a browser, exercise these flows. Each one MUST work end-to-end — if any fails, surface to user with the specific step.

### 6.1 Triager flow (Aaron's persona)

1. Sign in as a project admin (or Container SRG admin).
2. Open the Container SRG component page.
3. Confirm the **CommentPeriodBanner** is visible at the top with phase + days remaining.
4. Click the "Comments" panel toggle. Confirm it slides in at 700px wide on desktop.
5. Confirm the triage table loads with default `Status: Pending` filter.
6. Click `[Triage]` on a pending comment.
7. Confirm modal opens with comment + section context + decision radios + response textarea.
8. Select "Accept with changes (Concur with comment)". Type a response. Click "Save decision".
9. Confirm row updates to "◐ Accept w/ changes" status.
10. Confirm the response appears in the rule's per-rule thread (`RuleReviews.vue`) under the original comment.
11. Click `[Close]` on the same row. Confirm row updates to "✓ Closed (Accept w/ changes)".

### 6.2 Triager flow — decline path

1. Click `[Triage]` on another pending comment.
2. Select "Decline (Non-concur)". Leave response blank.
3. Confirm "Save decision" button is disabled and red helper text says "Decline requires a response".
4. Type a response. Save decision works.

### 6.3 Commenter flow (viewer persona)

1. Sign out, sign in as a viewer with membership on Container SRG.
2. Open a rule on the component (e.g., CRI-O-000050).
3. Confirm small `💬` icons next to each section header (Title, Severity, Check, Fix, etc.).
4. Click the `💬` next to "Check". Confirm composer opens with section pre-tagged "Check".
5. Confirm the dedup banner shows existing Check comments on this rule (if any).
6. Submit a new comment. Confirm success toast.

### 6.4 Commenter feedback loop (My Comments)

1. Still as the viewer, click your avatar → "My Comments".
2. Confirm `/my/comments` loads with the new comment in the list, status `◯ Pending`.
3. Click the row. Confirm detail modal opens with `[✏ Edit comment]` and `[⊘ Withdraw]` buttons (only while pending).
4. Edit the comment text. Save. Confirm change persists.
5. Withdraw the comment. Confirm status flips to `⊘ Withdrawn` (terminal).
6. Refresh /my/comments — withdrawn row shows correctly, no edit button.

### 6.5 IDOR / privacy spot-check

1. As viewer A, copy the comment id from a comment you posted.
2. Sign in as viewer B (different account).
3. Try `curl -X PATCH http://localhost:3000/reviews/<that_id>/withdraw -H "Cookie: <B's session cookie>"` — expect 403.
4. Try `curl http://localhost:3000/users/<viewer_A_id>/comments` while signed in as B — expect 403.

### 6.6 Rate limit spot-check

1. As a viewer, open browser dev tools → console.
2. Run a loop posting 12 comments rapidly:
   ```javascript
   for (let i = 0; i < 12; i++) {
     await fetch("/rules/<rule_id>/reviews", {
       method: "POST",
       headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name=csrf-token]').content },
       body: JSON.stringify({ review: { action: "comment", comment: `spam ${i}`, component_id: <component_id> }})
     });
   }
   ```
3. Confirm requests 11+ return 429 Too Many Requests.

## Step 7: Document smoke test results

Append a section to the PR description summarizing which flows exercised cleanly. If any didn't, surface them — don't claim done.

## Step 8: Post-implementation — PR comments

The PR comments draft at `/tmp/pr-717-review-comments.md` (created during design phase) needs refreshing with actual commit SHAs.

```bash
# Get the SHAs of the relevant commits
git log --oneline feat/viewer-comments | grep -E "(action-permissions|transaction integrity|interpolate)"
```

Update `/tmp/pr-717-review-comments.md` with the SHAs, then post:

```bash
# Top-level review comment (mentions the design doc + plan + commit SHAs)
gh pr review 717 --repo mitre/vulcan --comment --body-file /tmp/pr-717-toplevel.md

# Replies to each Copilot comment — fetch IDs first
gh api repos/mitre/vulcan/pulls/717/comments --jq '.[] | select(.user.login == "Copilot") | {id, path, line}'

# For each Copilot comment ID, post a reply (the bodies are pre-drafted in /tmp)
gh api repos/mitre/vulcan/pulls/717/comments/<id>/replies \
  -F body="$(cat /tmp/pr-717-reply-N.md)"
```

## Step 9: Update PR description

Edit the PR body to reference:
- The design doc: `docs/plans/PR717-public-comment-review/design.md` (also kept at repo root as `DESIGN-2026-04-29-public-comment-review.md`)
- This plan folder: `docs/plans/PR717-public-comment-review/`
- A summary of the bundle: viewer-comments + role-gate fix + lifecycle + triage workflow + my-comments

```bash
gh pr edit 717 --repo mitre/vulcan --body-file <(cat <<'EOF'
## Summary

Implements the public-comment-review workflow described in
`docs/plans/PR717-public-comment-review/design.md`. Bundle contents:

- **Viewer-can-comment** (the original PR scope) + the role-gate fix
  Copilot flagged (per-action `ACTION_PERMISSIONS` map enforces
  viewer-only-comment, author+ for everything else)
- **Lifecycle on Review**: triage_status (DISA matrix vocab), section
  (XCCDF element keys), responding_to_review_id, audit trail
- **Triage workflow**: PATCH /reviews/:id/triage + /adjudicate +
  /withdraw, ComponentComments table, CommentTriageModal
- **Commenter feedback loop**: per-section `💬` icons in the rule
  editor, CommentComposerModal with dedup banner, "My Comments" page on
  user profile, in-app status visibility (no outbound email — deferred
  to v2)
- **Comment phase enum on Component**: draft / open / adjudication / final

Container SRG–ready. ~25 industry commenters can post; project team
triages via the Comments panel.

## Test plan
- [x] All ~660 backend specs pass via parallel_rspec
- [x] All Vue specs pass via vitest
- [x] Brakeman: no new warnings
- [x] Manual smoke test (see plan task 99 §6) — Container SRG triager
      flow, commenter flow, My Comments, IDOR spot-check, rate limit
      spot-check
- [x] Vocabulary grep checks (`98-vocabulary-grep-verification.md`) all pass

Authored by: Aaron Lippold<lippold@gmail.com>
EOF
)
```

## Step 10: Mark this task done

```bash
git mv docs/plans/PR717-public-comment-review/99-final-test-sweep-and-acceptance.md \
       docs/plans/PR717-public-comment-review/99-final-test-sweep-and-acceptance-DONE.md
git commit -m "chore: mark plan task 99 done — implementation complete

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## Acceptance — definition of "done" for the PR

The PR is ready to merge when:

- [ ] All 22 implementation tasks are committed and marked DONE
- [ ] `bundle exec parallel_rspec spec/` is 0 failures
- [ ] `pnpm vitest run` is 0 failures
- [ ] `bundle exec rubocop` is 0 offenses
- [ ] `yarn lint` is 0 warnings
- [ ] `bundle exec brakeman` produces no new warnings
- [ ] All five vocabulary grep checks (Step 5) pass cleanly
- [ ] Manual smoke test (Step 6) executes cleanly end-to-end
- [ ] Copilot's four findings on PR #717 have been replied to with commit SHA references
- [ ] PR description (Step 9) accurately summarizes the bundle and references the design doc + plan
- [ ] Container SRG team has been notified the workflow is live (out-of-band — plan agent doesn't post on Slack)

## What v2 picks up (out of scope for this PR)

- Outbound email + opt-in UI + bounce handling + List-Unsubscribe headers
- Auto-advance comment phase on date boundaries (cron job)
- DISA comment-resolution-matrix CSV/OSCAL export
- Structured CCI/CVE/NIST control reference fields on comments
- Semantic dedup matching on comment composition
- Bulk triage actions
- "Public comment period" as a first-class entity (vs. an attribute on Component)

These are tracked in design doc §5 (Out of Scope / YAGNI). When v2 starts, create a new plan folder `docs/plans/v2-comment-email-and-export/`.
