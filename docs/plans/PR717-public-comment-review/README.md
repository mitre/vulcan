# Implementation Plan — PR #717 Public Comment Review

This folder is the **executable plan** for shipping the public-comment-review workflow on branch `feat/viewer-comments` (PR #717 against `mitre/vulcan`).

**Design source of truth:** [`design.md`](./design.md) in this folder (a copy of `DESIGN-2026-04-29-public-comment-review.md` at the repo root — kept in-folder so the plan is self-contained for handoff). Read at minimum **§3.1.1** (vocabulary layering principle), **§3.1.2** (canonical label table), and the section relevant to the task you're executing.

**If the root and folder copies drift:** the root copy is authoritative — re-copy it into this folder via `cp ../../../DESIGN-2026-04-29-public-comment-review.md ./design.md`. The plan and the design doc should be reviewed together; if you change one, change the other.

---

## Read this first (agent orientation)

You are picking up a TDD-driven implementation that ships in **one PR over 1–2 days**, intended for the Container SRG public comment period that is **live right now**.

**Sanity-check your starting state:**

```bash
git rev-parse --abbrev-ref HEAD     # → feat/viewer-comments
git log --oneline -6                # → top six commits should include:
                                    #     6103453 chore(plan): renumber plan tasks ...
                                    #     dc99d8e docs: TDD-driven implementation plan ...
                                    #     2061072 docs: design for public-comment-review ...
                                    #     9001d0b fix: per-action role gate via ACTION_PERMISSIONS map ...
                                    #     71726fa fix: gate request_review by role + spec polish
                                    #     3f1593e fix: include admin-contact hint ...
git status --short                  # → clean working tree (modulo any local untracked work)
bundle exec parallel_rspec spec/    # → currently green; if not, STOP and surface
pnpm vitest run                     # → currently green; if not, STOP and surface
```

If any of those fail, do **not** start — surface the discrepancy to the user.

**SHA note:** the SHAs above are the state at the time this README was written (after `chore(plan): renumber`). New commits will of course shift the top of `git log`. As long as `9001d0b` (ACTION_PERMISSIONS map) and `71726fa` (Will's role gate fix) are present in `git log feat/viewer-comments`, you're on the right branch.

---

## Execution protocol

1. **Read the README + the next task file.** That's all the context you need.
2. **Each task is one TDD loop and ends with one git commit.** Don't chain commits.
3. **The Step numbers inside each task are mandatory and ordered.** Step 1 (write failing spec) is not optional — it's the discipline that catches "the test is testing the bug, not the requirement."
4. **Verify red before going green.** Step 2 in every task is "run and confirm the test fails." Skipping this is the single most common way TDD becomes theater.
5. **Run the vocabulary grep checks before every commit** (`98-vocabulary-grep-verification.md`). They take 2 seconds and catch the most common drift between layers (DISA term in a Vue template, friendly label in a migration).
6. **Mark progress by renaming.** After committing task `NN-foo.md`, rename it to `NN-foo-DONE.md` (`git mv`). This makes resume-after-compaction trivial — agent does `ls` and the next undone file is obvious.
7. **Do NOT edit a task file mid-execution.** If a step's expected output doesn't match reality, STOP and surface to the user. Don't quietly adjust the plan.
8. **Do NOT batch commits.** The atomic commit cadence is part of the review surface for the PR.
9. **Don't peek ahead.** Each task is scoped to itself. If a later task depends on something you're about to do, the dependency graph below shows it explicitly — trust the graph.

---

## Files in this plan

| #  | File | Layer | Effort | Depends on |
|----|------|-------|--------|------------|
| 01 | `01-action-permissions-map-DONE.md` | Backend (model) | — | — (DONE — landed via Will's `71726fa` + `9001d0b`) |
| 02 | `02-strong-params-and-rate-limit.md` | Backend (controller + middleware) | 25 min | — |
| 03 | `03-i18n-and-vocabulary-files.md` | Both (single source of truth) | 20 min | — |
| 04 | `04-migration-review-lifecycle.md` | DB | 20 min | — |
| 05 | `05-migration-component-phase.md` | DB | 10 min | — |
| 06 | `06-review-model-validations.md` | Backend (model) | 30 min | 01, 04 |
| 07 | `07-reviews-controller-create-fixes.md` | Backend (controller) | 15 min | 02, 04 (trimmed: most content addressed by Will's `71726fa`) |
| 08 | `08-components-controller-comments-endpoint.md` | Backend (controller + route) | 25 min | 04, 06 |
| 09 | `09-users-controller-my-comments-endpoint.md` | Backend (controller + route) | 20 min | 04, 06 |
| 10 | `10-reviews-controller-triage-endpoint.md` | Backend (controller + route) | 30 min | 03, 04, 06, 07 |
| 11 | `11-reviews-controller-adjudicate-endpoint.md` | Backend (controller + route) | 20 min | 10 |
| 12 | `12-reviews-controller-withdraw-and-update.md` | Backend (controller + route) | 30 min | 04, 06 |
| 13 | `13-frontend-vocabulary-module.md` | Frontend (constants) | 15 min | 03 |
| 14 | `14-frontend-component-comments-table.md` | Frontend (Vue) | 60 min | 08, 13 |
| 15 | `15-frontend-comment-triage-modal.md` | Frontend (Vue) | 60 min | 10, 11, 13 |
| 16 | `16-frontend-section-comment-icons.md` | Frontend (Vue) | 45 min | 13 |
| 17 | `17-frontend-comment-composer-modal.md` | Frontend (Vue) | 45 min | 08, 13 |
| 18 | `18-frontend-rule-reviews-thread-badges.md` | Frontend (Vue) | 30 min | 13 |
| 19 | `19-frontend-rules-table-comments-column.md` | Frontend (Vue) | 25 min | 08, 13 |
| 20 | `20-frontend-my-comments-page.md` | Frontend (Vue + route) | 60 min | 09, 12, 13 |
| 21 | `21-frontend-comment-period-banner.md` | Frontend (Vue) | 20 min | 05, 13 |
| 22 | `22-frontend-edit-component-comment-phase.md` | Frontend (Vue + form) | 25 min | 05 |
| 98 | `98-vocabulary-grep-verification.md` | Tooling (run before every commit) | < 1 min | — |
| 99 | `99-final-test-sweep-and-acceptance.md` | Verification | 30 min | all above |

**Total Claude-pace estimate (remaining after 01):** ~9–10 hours of focused execution. Leaves margin for review checkpoints, surprises, and the manual smoke test in 99. Comfortably fits the 1–2 day window.

**Order rationale (revised after Will's 71726fa landed):**
- 01 closed itself via Will's commit + the ACTION_PERMISSIONS map infrastructure
- 03 (i18n) moved up — pure new files, no DB cost; provides error message keys for tasks 07-12 to reference
- 04, 05, 06 are migrations + model validations — sequential because 06 reads 04's columns
- 07 has shrunk in scope (Will did the spec polish + role-on-request_review check); only the transaction wrap + strong-params extension remain
- **08, 09 (read endpoints) before 10, 11, 12 (mutations)** — read endpoints unblock 4 frontend tasks (14, 17, 19, 20); mutations unblock 2 (15, 20). Read-first is safer and accelerates parallel frontend work.

---

## Dependency graph (ASCII)

```
01 ✓ DONE (Will's 71726fa + ACTION_PERMISSIONS map in 9001d0b)

  Foundation (independent — can interleave):
   02 (rate limit) ─┐
   03 (i18n)        ├─→ unblocks 07–12 + 13
   04 (mig: review) ┤
   05 (mig: phase)  ┤
                    │
                    ▼
   06 (validations, needs 04) ──────┐
                                    │
   07 (controller wrap) ────────────┤
                                    │
                                    ▼
   Read endpoints (parallel):       Mutation endpoints (sequential):
   08 (components#comments)         10 (triage)
   09 (users#comments)              11 (adjudicate, needs 10's pattern)
                                    12 (withdraw + edit-own)
                    │
                    ▼
   13 (TriageStatusBadge + SectionLabel, needs 03)
                    │
                    ▼
   Frontend (mostly independent once their deps land):
   14 ComponentComments table  ── needs 08, 13
   15 CommentTriageModal       ── needs 10, 11, 13
   16 Section icons + form     ── needs 13
   17 Composer + dedup banner  ── needs 08, 13
   18 RuleReviews thread       ── needs 13
   19 RuleNavigator badge      ── needs 08, 13
   20 My Comments page         ── needs 09, 12, 13
   21 CommentPeriodBanner      ── needs 05, 13
   22 UpdateComponentDetailsModal phase fieldset ── needs 05
                    │
                    ▼
   99 (final sweep)
```

**Parallelization opportunities** (if multiple agents execute in parallel — single agent should just go in order):
- 02, 03, 04, 05 are fully independent foundation work
- 08 and 09 can run in parallel (different controllers)
- 14-22 are mostly independent once their backend deps land
- 98 is run before every commit (not a parallelizable task)

For a **single agent doing this solo**: just execute 02 → 99 in numeric order. The graph is shown so you understand why.

---

## Bug fixes already landed (Copilot review of PR #717)

All four Copilot findings on PR #717 are **already resolved on the branch**:

| Copilot finding | Resolved by |
|---|---|
| #1 — viewer can `request_review` (auth bypass) | Will's `71726fa` (in-place role check in `can_request_review`) + `9001d0b` (`ACTION_PERMISSIONS` map for tier-based gating across all actions) |
| #2 — spec missing `component_id` | Will's `71726fa` |
| #3 — spec missing `component_id` (different line) | Will's `71726fa` |
| #4 — failure message doesn't interpolate role | Will's `71726fa` |

Tasks 02+ are net-new feature work (the public-comment-review lifecycle). Task 07 is now a small follow-up (transaction wrap + strong-params extension for the new `:section` and `:responding_to_review_id` keys once Task 05's columns exist).

---

## After the plan: PR comments

When Tasks 99 is complete and the implementation is green, run the post-implementation tasks:

1. Reply to each Copilot comment on PR #717 with a link to the relevant task commit (the `gh api ...` commands and exact reply bodies are in `/tmp/pr-717-review-comments.md` — refresh the file with task numbers/commit SHAs before posting).
2. Update the PR description to reference this plan folder.
3. Request review.

---

## If you get stuck

- Each task lists `Depends on:` — if a referenced state isn't there, stop, re-read the dependency, surface to user if still confused.
- The design doc has a "What each persona sees" table (§2.5) and a state diagram (§2.1) — those are the quickest mental-model rebuilders after compaction.
- `bd ready` for any active beads cards related to this work.
- DO NOT improvise. If a Step says "run X, expect Y" and you get Z, stop.
