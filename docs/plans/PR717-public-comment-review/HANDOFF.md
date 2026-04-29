# HANDOFF — PR #717 Public Comment Review

**For Will (and his Claude) picking up where Aaron's session left off.**

Read this file first. It's the shortest path to "useful within 5 minutes of context."

---

## Where we are right now

**Last updated:** after commit `39d03e6` (chore: mark plan task 02 done) on `feat/viewer-comments`.

### Done so far (5 commits this PR cycle)

| # | Commit | What |
|---|---|---|
| 01 ✓ | `71726fa` (Will) + `9001d0b` (Aaron's ses) | Closes Copilot #1/#2/#3/#4 + adds `ACTION_PERMISSIONS` tier-based role gate |
| design | `2061072` | The full design doc (`DESIGN-2026-04-29-public-comment-review.md` at repo root, plus a copy at `docs/plans/PR717-public-comment-review/design.md`) |
| plan | `dc99d8e` + `6103453` + `8160fac` | The 25-file plan folder with optimal task ordering and verified file paths |
| 02 ✓ | `cd12e5b` + `39d03e6` | Rack::Attack throttle on comment posts (10/min, 100/hour per user) + 4000-char cap on comment-action reviews |

### Next up

**Task 03: i18n + vocabulary files** → `03-i18n-and-vocabulary-files.md`

Then 04 → 22 → 98 → 99 in numeric order. Discover the next undone task any time via:

```bash
ls docs/plans/PR717-public-comment-review/ | grep -v DONE | grep -E '^[0-9]' | head -1
```

---

## Project context (load this into your head before reading task files)

- **Container SRG public comment period is live RIGHT NOW.** ~25 industry commenters from Red Hat, Microsoft, IBM. **1-2 day timeline** is real, not aspirational.
- Branch: `feat/viewer-comments` on `mitre/vulcan` (PR #717)
- This is Vulcan v2.x — Rails 8.0.2.1 + Vue 2.7 + Bootstrap-Vue 2.13 + Turbolinks 5
- Outbound email is **deferred to v2** — do NOT add ActionMailer work in this PR
- "My Comments" page on user profile is the v1 commenter feedback loop (substitutes for email)
- DISA-native vocabulary in storage/API/CSV export, **friendly English in UI templates** (the vocabulary-layering principle — see `design.md` §3.1.1)
- The triage modal is the **one allowed exception** — radio labels show both ("Accept (Concur)") for pedagogy

---

## How to start

Drop this into your Claude session as the opening prompt:

```text
You are picking up the PR #717 implementation on branch
feat/viewer-comments in the mitre/vulcan repo.

START HERE:
  cat docs/plans/PR717-public-comment-review/HANDOFF.md
  cat docs/plans/PR717-public-comment-review/README.md
  cat docs/plans/PR717-public-comment-review/design.md  # focus §3.1.1, §3.1.2

Then execute tasks 03 onwards in numeric order:
  ls docs/plans/PR717-public-comment-review/ | grep -v DONE | grep -E '^[0-9]' | head -1

Each task is ONE TDD cycle ending in ONE git commit:
  Step 1: write the failing spec exactly as written in the task file
  Step 2: run it and CONFIRM RED (the most-skipped step — don't skip)
  Step 3+: implement using the code in the task file
  Verify green, run vocabulary grep checks (98-vocabulary-grep-verification.md),
  RuboCop, then commit with the HEREDOC message in the task file.
  Then `git mv NN-foo.md NN-foo-DONE.md` and commit the rename.

Then push between tasks so progress is visible.

Container SRG public comment period is LIVE. 1-2 day timeline.
Don't peek ahead to later tasks — trust the dependency graph in
README.md. Don't skip Step 2 (verify red) in any task.

If a step's expected output doesn't match reality: STOP and surface
to Aaron rather than improvising.
```

---

## Sanity check before each task

```bash
git rev-parse --abbrev-ref HEAD                  # → feat/viewer-comments
git log --oneline -3                             # → top: 39d03e6 chore: mark plan task 02 done
                                                 #        cd12e5b feat: rate-limit comment posts ...
                                                 #        8160fac docs(plan): refresh stale task content ...
git status --short                               # → clean working tree
bundle exec rspec spec/models/reviews_spec.rb \
                  spec/requests/reviews_spec.rb \
                  spec/requests/rack_attack_spec.rb # → 73/73 green right now
```

If any fail → STOP and surface.

(Full backend suite via `bundle exec parallel_rspec spec/` and full frontend via `pnpm vitest run` is also green at this commit. You don't need to run those before every task; the impacted-spec subset above is enough.)

---

## TDD-discipline reminders (the things that fail under time pressure)

1. **Verify red before going green.** Step 2 in every task is "run the spec and confirm it fails." If it passes immediately, **STOP** — either the bug was already fixed or the spec is testing something other than what it claims.

2. **Don't peek ahead.** Each task is scoped to its own file. The dependency graph in README.md tells you what's blocked on what. Trust it.

3. **Run the vocabulary grep checks before every commit** (per `98-vocabulary-grep-verification.md`). 2 seconds, catches the most common drift.

4. **One TDD cycle = one commit.** Don't batch. The atomic commit cadence is part of the PR review surface.

5. **`git mv NN-foo.md NN-foo-DONE.md`** after committing each task. Then `ls | grep -v DONE | head -1` gives the next undone task — works even after `/compact` or new session.

6. **NEVER use `git add -A` or `git add .`.** Add files individually. (Aaron's project rule.)

7. **No AI attribution in commits.** Use `Authored by: Aaron Lippold<lippold@gmail.com>`.

---

## When to stop and surface

- Sanity-check command produces unexpected output → STOP
- Step 2 (red) test passes immediately → STOP and investigate
- Step 4+ test fails AFTER you've followed the implementation steps → STOP, don't improvise the fix
- Vocabulary grep finds DISA terms in templates or friendly labels in DB code → STOP and fix BEFORE commit
- An IDE / linter rewrites a file mid-task → STOP and confirm the change is intentional before continuing
- Anything in `git status` shows up that you didn't make → STOP — it's likely a parallel session

---

## Things deliberately NOT in scope for this PR (deferred to v2)

- Outbound email (ActionMailer additions, CAN-SPAM scaffolding, bounce handling, List-Unsubscribe headers, digest mode)
- Auto-advance of `comment_phase` based on dates (cron-style)
- DISA comment-resolution-matrix CSV/OSCAL export
- Structured CCI/CVE/NIST control reference fields
- Semantic dedup matching (just the simple "N existing comments on this rule" banner in v1)
- Bulk triage actions
- "Public comment period" as first-class entity (vs an attribute on Component)

If you find yourself adding any of the above — STOP. They're explicitly out of scope per `design.md` §5.

---

## What success looks like

After Task 99:

- `bundle exec parallel_rspec spec/` → 0 failures
- `pnpm vitest run` → 0 failures
- `bundle exec rubocop` → 0 offenses
- `yarn lint` → 0 warnings
- `bundle exec brakeman` → no new warnings vs baseline
- All 5 vocabulary grep checks (Task 98) clean
- Manual smoke test (per Task 99 §6) executes end-to-end:
  - Triager flow: Container SRG admin opens Comments panel → triage table loads → triage decision → Adjudicate
  - Commenter flow: viewer adds a section-tagged comment from the rule editor
  - My Comments: commenter sees the new comment with status badge; can edit (while pending) or withdraw
  - IDOR spot-check: cross-project triage attempt returns 403, not 404
  - Rate limit spot-check: 11th comment in a minute returns 429
- Copilot's 4 PR comments replied to with task commit SHAs (Task 99 Step 8)
- PR description updated to reference `design.md` and the plan folder

---

## When in doubt

- **Aaron's CLAUDE.md** at `~/.claude/CLAUDE.md` and the project `CLAUDE.md` files have the broader rules (git policy, beads workflow, beads command safety, vocabulary discipline).
- **`design.md`** §3.1.1 + §3.1.2 are the most-load-bearing sections — the vocabulary layering principle.
- **`README.md`** has the dependency graph + execution protocol.
- **Each task file** has its own "Verified facts" block with concrete file paths.

If something contradicts between sources: the design doc is authoritative for what to build; the task file is authoritative for how to build it; CLAUDE.md is authoritative for how to commit/git/track.
