# HANDOFF — PR #717 Public Comment Review

**For Will (and his Claude) picking up where Aaron's session left off.**

Read this file first. It's the shortest path to "useful within 5 minutes of context."

---

## Where we are right now

**Backend layer: COMPLETE. All 12 backend tasks (01–12) shipped + several drive-by quality fixes. Next is frontend (13–22) + verification (98, 99).**

**Last updated:** after commit `6e5ec9c` on `feat/viewer-comments`.

### Done so far

**Plan tasks (`docs/plans/PR717-public-comment-review/NN-...-DONE.md`):**

| # | What |
|---|---|
| 01 ✓ | `ACTION_PERMISSIONS` tier-based role gate (closes Copilot #1–#4 with Will's `71726fa` + Aaron's `9001d0b`) |
| 02 ✓ | Rack::Attack throttle on comment posts (10/min, 100/hr per user) + 4000-char comment cap |
| 03 ✓ | i18n + vocabulary single-source-of-truth files (`en.yml#vulcan.triage` + `triageVocabulary.js`) |
| 04 ✓ | Migration: 8 lifecycle columns + 4 indexes + 4 FKs on `reviews` |
| 05 ✓ | Migration: `comment_phase` enum + helpers on `components` |
| 06 ✓ | Review model validations + scopes + `auto_set_adjudicated` callback + `vulcan_audited` |
| 07 ✓ | `ReviewsController#create` transaction wrap + 422-on-DB-error + strong-params extension |
| 08 ✓ | `GET /components/:id/comments` paginated triage table endpoint |
| 09 ✓ | `GET /users/:id/comments` comments-by-author endpoint (privacy-model corrected — see below) |
| 10 ✓ | `PATCH /reviews/:id/triage` |
| 11 ✓ | `PATCH /reviews/:id/adjudicate` |
| 12 ✓ | `PATCH /reviews/:id/withdraw` + `PUT /reviews/:id` (commenter self-service) |

**Drive-by quality fixes (not in the plan, found while doing controller work — pattern: render-inside-transaction / partial-write / 500-on-notification-failure):**

| Commit | Fix |
|---|---|
| `6a25afa` | `lock_controls` `DoubleRenderError` on save failure |
| `0cf51d4` | `lock_sections` partial-write + 500-on-error → transaction wrap + 422 toast |
| `df3de06` | `components#destroy` render inside transaction → moved outside, no DoubleRender on commit-phase failure |
| `606bdcd` | `rules#destroy` orphan-on-mid-cleanup-failure → transaction wrap |
| `d05aac9` | `safely_notify` shared wrapper on `ApplicationController` + applied across `projects/memberships/project_access_requests/rule_satisfactions` (and `rule_satisfactions` got a transaction wrap fixing a join-table-then-save partial-state bug) |
| `d487f46` | Five more `safely_notify` sites: `users#update`, `reviews#create`, `components#create`, `projects#create`, `projects#update` |

### One git history note

Commit `6e5ec9c` is labeled `chore: mark plan task 12 done` but its diff also contains the Task 12 feature code. The text-width pre-commit hook rejected the long subject of the feat commit; the staged files swept into the next commit. Cosmetic only — code is correct, tests green. Mentioned here so you don't double-take when reading the log.

### Next up

**Task 13: frontend vocabulary module** → `13-frontend-vocabulary-module.md`

Then 14 → 22 → 98 → 99 in numeric order. Discover the next undone task any time via:

```bash
ls docs/plans/PR717-public-comment-review/ | grep -v DONE | grep -E '^[0-9]' | head -1
```

Frontend tasks land in `app/javascript/components/...` and use Bootstrap-Vue 2.13. The vocabulary module from Task 03 (`triageVocabulary.js`) is the single source of truth that 14–22 import from.

---

## Lessons learned from the backend pass — read before starting frontend

### 1. Vocabulary discipline (still applies on the wire)

Backend always emits DISA-native keys: `triage_status` values like `concur_with_comment`, `non_concur`, `pending`, `withdrawn`, etc., and section keys like `check_content`, `fixtext`, `vuln_discussion`. The frontend (you) translates to friendly English ("Accept", "Decline", "Check", "Fix") via `triageVocabulary.js`. The triage modal is the one place radio labels show both ("Accept (Concur)") for pedagogy.

Run the vocabulary greps before every commit (`98-vocabulary-grep-verification.md`). 2 seconds, catches the most common drift.

### 2. Privacy-model correction in Task 09

Earlier draft of Task 09 framed `GET /users/:id/comments` as "absolutely private — current_user only, no admin override." That framing was **wrong** and we corrected it. Comments aren't private data: any project member can already read all comments on rules in projects they have access to via `GET /components/:id/comments` (Task 08). The "My Comments" page is a *personal dashboard view* — a slice of the same project-member-visible data filtered to a specific author — not a separate privacy zone.

Industry pattern (GitHub `/users/:username/issues`, Linear "My issues"): filter rows to what the requester is authorized to see, then within that, scope by author. OWASP A01 by row scope, not endpoint gating on identity equality.

The corrected Task 09 plan doc explains this in detail. **If a future task plan or design draft talks about "absolutely private" comments — push back.** Comments are project-member-visible by design.

### 3. Rule is STI on `base_rules`

If a model query needs to filter by `Rule.where(component_id: X)` after a `joins(:rule)`, AR's `where(rules: { ... })` form fails because the actual table is `base_rules` (with `type='Rule'` discriminator). Use `joins(:rule).merge(Rule.where(component_id: X))` instead — AR resolves the table name correctly via merge. Used in Task 08's `Component#paginated_comments` and Task 09's `UsersController#comments`.

### 4. `safely_notify` for any post-save notification

After a successful state-change (save/update/destroy), wrap downstream notification calls (Slack, SMTP, in-app) in `safely_notify('context_label') { ... }`. The DB state has committed, so the user-facing operation succeeded; a notification failure should log at warn level, not 500. Pattern is on `ApplicationController` and used across 7+ controllers now. Frontend doesn't need to call it directly, but if any new backend code lands in 13–22, follow the pattern.

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
feat/viewer-comments in the mitre/vulcan repo. The entire backend is
done — your work is the frontend tasks (13-22) plus the verification
sweep (98, 99).

START HERE:
  cat docs/plans/PR717-public-comment-review/HANDOFF.md
  cat docs/plans/PR717-public-comment-review/README.md
  cat docs/plans/PR717-public-comment-review/design.md  # focus §3.1.1, §3.1.2

Then execute tasks 13 onwards in numeric order:
  ls docs/plans/PR717-public-comment-review/ | grep -v DONE | grep -E '^[0-9]' | head -1

Each task is ONE TDD cycle ending in ONE git commit:
  Step 1: write the failing spec exactly as written in the task file
  Step 2: run it and CONFIRM RED (the most-skipped step — don't skip)
  Step 3+: implement using the code in the task file
  Verify green, run vocabulary grep checks (98-vocabulary-grep-verification.md),
  RuboCop + ESLint, then commit with the HEREDOC message in the task file.
  Then `git mv NN-foo.md NN-foo-DONE.md` and commit the rename.

Frontend tasks: import friendly labels from
app/javascript/constants/triageVocabulary.js. Never hardcode "Accept"
or "Decline" in a Vue template. Wire to the backend endpoints created
in Tasks 08 (GET /components/:id/comments), 09 (GET /users/:id/comments),
10 (PATCH /reviews/:id/triage), 11 (.../adjudicate),
12 (.../withdraw + PUT /reviews/:id).

Push between tasks so progress is visible.

Container SRG public comment period is LIVE. 1-2 day timeline.
Don't peek ahead to later tasks — trust the dependency graph in
README.md. Don't skip Step 2 (verify red) in any task.

If a step's expected output doesn't match reality: STOP and surface
to Aaron rather than improvising. The privacy-model correction in
Task 09 is exactly the kind of thing that surfacing catches.
```

---

## Sanity check before each task

```bash
git rev-parse --abbrev-ref HEAD                       # → feat/viewer-comments
git log --oneline -3                                  # → top: 6e5ec9c chore: mark plan task 12 done
                                                      #        b2bd2d2 chore: mark plan task 11 done
                                                      #        5f1920b feat: PATCH /reviews/:id/adjudicate endpoint
git fetch origin feat/viewer-comments                 # always before starting
git log HEAD..origin/feat/viewer-comments --oneline   # should be empty if you're up to date
git status --short                                    # → clean working tree (modulo any local untracked work)
bundle exec rspec spec/models/reviews_spec.rb \
                  spec/requests/reviews_spec.rb \
                  spec/requests/components_spec.rb \
                  spec/requests/users_spec.rb         # → impacted-backend slice; should be all green
pnpm vitest run                                       # → frontend; should be all green
```

If any fail → STOP and surface.

(Full backend suite via `bundle exec parallel_rspec spec/` and full frontend via `pnpm vitest run` is also green at `6e5ec9c`. You don't need to run them before every task; the impacted-spec subset above is enough.)

---

## TDD-discipline reminders (the things that fail under time pressure)

1. **Verify red before going green.** Step 2 in every task is "run the spec and confirm it fails." If it passes immediately, **STOP** — either the bug was already fixed or the spec is testing something other than what it claims.

2. **Don't peek ahead.** Each task is scoped to its own file. The dependency graph in README.md tells you what's blocked on what. Trust it.

3. **Run the vocabulary grep checks before every commit** (per `98-vocabulary-grep-verification.md`). 2 seconds, catches the most common drift.

4. **One TDD cycle = one commit.** Don't batch. The atomic commit cadence is part of the PR review surface.

5. **`git mv NN-foo.md NN-foo-DONE.md`** after committing each task. Then `ls | grep -v DONE | head -1` gives the next undone task — works even after `/compact` or new session.

6. **NEVER use `git add -A` or `git add .`.** Add files individually. (Aaron's project rule.)

7. **No AI attribution in commits.** Use `Authored by: Aaron Lippold<lippold@gmail.com>`.

8. **Watch the text-width pre-commit hook.** Subjects ≥73 chars get rejected. If a hook fails, your files stay staged — don't blindly run the next git command, or staged content can leak into a later commit (this happened on `6e5ec9c`; cosmetic but worth avoiding).

---

## When to stop and surface

- Sanity-check command produces unexpected output → STOP
- Step 2 (red) test passes immediately → STOP and investigate
- Step 4+ test fails AFTER you've followed the implementation steps → STOP, don't improvise the fix
- Vocabulary grep finds DISA terms in templates or friendly labels in DB code → STOP and fix BEFORE commit
- An IDE / linter rewrites a file mid-task → STOP and confirm the change is intentional before continuing
- Anything in `git status` shows up that you didn't make → STOP — it's likely a parallel session
- A plan doc says "absolutely private" or otherwise frames a comment-related endpoint as identity-gated rather than row-scoped → STOP and re-read the privacy correction in Task 09

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

If something contradicts between sources: the design doc is authoritative for what to build; the task file is authoritative for how to build it; CLAUDE.md is authoritative for how to commit/git/track. **For comment-related work specifically: the privacy-model lesson in Task 09 supersedes any plan-doc framing of comments as "private" or "identity-gated."**
