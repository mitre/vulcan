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
git log --oneline -3                # → top three commits include 3f1593e, 8e8ae99, 8fdb4cf
git status --short                  # → clean (uncommitted PLAN/DESIGN files at root are expected)
bundle exec parallel_rspec spec/    # → currently green; if not, STOP and surface
pnpm vitest run                     # → currently green; if not, STOP and surface
```

If any of those fail, do **not** start — surface the discrepancy to the user.

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
| 01 | `01-action-permissions-map.md` | Backend (model) | 15 min | — |
| 02 | `02-strong-params-and-rate-limit.md` | Backend (controller + middleware) | 25 min | — |
| 03 | `03-migration-review-lifecycle.md` | DB | 20 min | — |
| 04 | `04-migration-component-phase.md` | DB | 10 min | — |
| 05 | `05-review-model-validations.md` | Backend (model) | 30 min | 01, 03 |
| 06 | `06-i18n-and-vocabulary-files.md` | Both (single source of truth) | 20 min | — |
| 07 | `07-reviews-controller-create-fixes.md` | Backend (controller) | 20 min | 01, 02 |
| 08 | `08-reviews-controller-triage-endpoint.md` | Backend (controller + route) | 30 min | 03, 05, 06, 07 |
| 09 | `09-reviews-controller-adjudicate-endpoint.md` | Backend (controller + route) | 20 min | 08 |
| 10 | `10-reviews-controller-withdraw-and-update.md` | Backend (controller + route) | 30 min | 03, 05 |
| 11 | `11-components-controller-comments-endpoint.md` | Backend (controller + route) | 25 min | 03, 05 |
| 12 | `12-users-controller-my-comments-endpoint.md` | Backend (controller + route) | 20 min | 03, 05 |
| 13 | `13-frontend-vocabulary-module.md` | Frontend (constants) | 15 min | 06 |
| 14 | `14-frontend-component-comments-table.md` | Frontend (Vue) | 60 min | 11, 13 |
| 15 | `15-frontend-comment-triage-modal.md` | Frontend (Vue) | 60 min | 08, 09, 13 |
| 16 | `16-frontend-section-comment-icons.md` | Frontend (Vue) | 30 min | 13 |
| 17 | `17-frontend-comment-composer-modal.md` | Frontend (Vue) | 45 min | 13, 11 |
| 18 | `18-frontend-rule-reviews-thread-badges.md` | Frontend (Vue) | 30 min | 13 |
| 19 | `19-frontend-rules-table-comments-column.md` | Frontend (Vue) | 25 min | 11, 13 |
| 20 | `20-frontend-my-comments-page.md` | Frontend (Vue + route) | 60 min | 12, 13, 10 |
| 21 | `21-frontend-comment-period-banner.md` | Frontend (Vue) | 20 min | 04, 13 |
| 22 | `22-frontend-edit-component-comment-phase.md` | Frontend (Vue + form) | 25 min | 04 |
| 98 | `98-vocabulary-grep-verification.md` | Tooling (run before every commit) | < 1 min | — |
| 99 | `99-final-test-sweep-and-acceptance.md` | Verification | 30 min | all above |

**Total Claude-pace estimate:** ~10–11 hours of focused execution. Leaves margin for review checkpoints, surprises, and the manual smoke test in 99. Comfortably fits the 1–2 day window.

---

## Dependency graph (ASCII)

```
                   ┌── 01 ──┐
                   │        ├── 05 ──┬── 08 ──┬── 09 ─┐
                   │        │        │        │        │
                   │   ┌── 03         ├── 10  │        │
                   ├── │   │          ├── 11 ─┤        │
                   │   │   │          ├── 12 ─┤        │
                   │   └── 04         │        │        │
                   ├── 02 ─┐          │        │        │
                   ├── 06 ─┤          │        │        │
                   │       └── 07 ────┘        │        │
                   │                                    │
                   └── 13 ──┬── 14 (needs 11) ──────────┤
                            ├── 15 (needs 08, 09) ──────┤
                            ├── 16 ────────────────────┤
                            ├── 17 (needs 11) ──────────┤
                            ├── 18 ────────────────────┤
                            ├── 19 (needs 11) ──────────┤
                            ├── 20 (needs 10, 12) ──────┤
                            ├── 21 (needs 04) ──────────┤
                            └── 22 (needs 04) ──────────┘
                                                         │
                                                         └── 99 (final sweep)
```

**Parallelization opportunities** (if multiple agents execute in parallel — single agent should just go in order):
- 01, 02, 03, 04, 06 are independent → can interleave
- 14, 15, 16, 17, 18, 19, 20, 21, 22 are mostly independent once their backend deps land
- 98 is run before every commit (not a parallelizable task)

For a **single agent doing this solo**: just execute 01 → 99 in numeric order. The graph is shown so you understand why.

---

## Bug fixes folded into this plan (Copilot review of PR #717)

The four findings Copilot flagged on PR #717 are addressed in early tasks, before any new feature work:

| Copilot finding | Addressed in |
|---|---|
| #1 — viewer can `request_review` (auth bypass) | Task 01 (ACTION_PERMISSIONS map) + Task 05 (model validations) |
| #2 — spec missing `component_id` | Task 07 (reviews controller create-side fixes) |
| #3 — spec missing `component_id` (different line) | Task 07 |
| #4 — failure message doesn't interpolate role | Task 07 |

After Task 07, Copilot's findings are all resolved. Tasks 08+ are net-new feature work.

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
