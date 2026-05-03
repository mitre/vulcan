# PR #717 — Public Comment Review Workflow

**Status (2026-04-30):** in-flight, ~80% complete. Container SRG public comment window is LIVE.
**Branch:** `feat/viewer-comments` against `mitre/vulcan` master.
**This document:** the canonical overview. Read first when picking up this PR cold. Plan task files in this folder are TDD-step-level.

> Looking for the original execution-protocol README? Its content is folded into this document — see [Execution protocol](#execution-protocol) below.

---

## Quick orientation (sanity check before starting)

```bash
git rev-parse --abbrev-ref HEAD     # → feat/viewer-comments
git status --short                  # → clean working tree
git log --oneline -10               # → recent commits should include
                                    #   697c7bb Docs: round-2 plan tightening
                                    #   fdc9b48 Docs: Task 29 — DISA disposition matrix CSV export
                                    #   a1f69d6 Docs: scope adjustment + plan tightening after 3-agent review
                                    #   661c906 Docs: plan tasks 23-27 — comments-as-objects + satisfies cross-rule
ls docs/plans/PR717-public-comment-review/ | grep -E '^[0-9]'
                                    # → 19, 21, 22, 23, 24, 27, 28, 29, 30, 98, 99 still open;
                                    #   25/26 marked DEFERRED; 1-18, 20 DONE
bd memories vulcan-comments-as-objects
                                    # → load the design philosophy
```

If `git status` is dirty, surface to the user before starting. Recent test green-state should be checked too:

```bash
bundle exec parallel_rspec spec/    # → currently green
pnpm vitest run                     # → currently green; 2184+ tests
yarn build                          # → esbuild clean
```

---

## What this PR delivers

A complete **public comment review workflow** for Vulcan-authored STIGs and Components: external commenters post on individual rules / sections during a public review window; project members triage each comment; admins adjudicate and produce a formal disposition record for DISA.

**The three personas:**

| Persona | Role | What they do |
|---|---|---|
| **Commenter** (external industry reviewer) | viewer-tier project membership | Posts comments on rules during the public window. Can reply, edit, withdraw their own comments. Sees their submissions in "My Comments" on their profile. |
| **Triager** (project author/reviewer) | author-tier+ on the project | Reviews incoming comments via the per-component triage queue. Marks each as concur / non-concur / informational / duplicate / etc. Posts triager responses. |
| **Admin** (project admin) | admin-tier on the project | Adjudicates final dispositions. Force-withdraws when needed (console procedure for this phase; UI in a follow-up). Exports the disposition matrix for DISA. |

**The workflow at a glance:**

```
┌─────────────────────────────────────────────────────────────────────┐
│  Commenter posts on rule → Triager triages → Admin adjudicates      │
│       (CommentComposerModal)  (CommentTriageModal)  (terminal status)│
│              │                       │                       │      │
│              ▼                       ▼                       ▼      │
│        review.id stable      triage_status set       adjudicated_at │
│        rule_id stable        triage_set_by, _at      adjudicated_by │
│        section tagged        triager response        (auto for some)│
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                  DISA Disposition Matrix CSV (Task 29)
                  [audit log retained throughout]
```

---

## Locked design decisions

These are the load-bearing choices. **Don't relitigate without explicit user input** — they were debated during the design + 3-agent review sessions and persist as bd memories.

### 1. Comments are objects, not graph-inherited signals

`bd memory: vulcan-comments-as-objects`

Comments live on the rule they were posted on (`rule_id` stable). Triage decisions live with the comment. Counts are local-only. Cross-rule consolidation is **explicit** via author/admin operations, not implicit via graph traversal.

**Rejected:** read-side query union of comments along the satisfies chain. Reasons: ambiguous reply targeting, inflated/non-deterministic counts, surprising mid-review behavior, blurred audit trail, contradicts the existing satisfies pattern (which is about *content* inheritance, not *identity*).

**Accepted operations for cross-rule cases:**
- **Mark-as-duplicate** (Task 24) — links to canonical via `duplicate_of_review_id`; auto-adjudicated as terminal status
- **Move-to-rule** (Task 26, deferred — runbook §2 covers via console) — admin reassigns `rule_id`; replies follow parent (parent-first walk)
- **Force-withdraw** (Task 25, deferred — runbook §1) — admin override on commenter intent
- **Edit comment section** (Task 30) — retroactive section tagging for legacy or misclassified comments

Cross-rule **discoverability** is informational:
- Comment counts surfaced on the existing **Satisfies panel** (Task 23 — small enhancement, NOT a new component)
- Component-scope triage queue already aggregates everything
- Existing Satisfies panel already shows the relationships

### 2. Vocabulary layering — DISA in storage, friendly English in UI

`bd memory: pr717-vocabulary-layering`

- DB columns + API + CSV/OSCAL export use DISA-native vocabulary (`concur`, `non_concur`, `concur_with_comment`, `check_content`, `vuln_discussion`, etc.)
- UI templates + error messages use friendly English (`Accept`, `Decline`, `Closed`, `Check`, `Vulnerability Discussion`)
- Two source-of-truth files: `config/locales/en.yml` + `app/javascript/constants/triageVocabulary.js`
- Pre-commit greps catch drift (Task 98)

### 3. Don't hide features — disable + tooltip

`bd memory: vulcan-disabled-not-hidden`

When a feature is unavailable (rule locked, status NYD, viewer can't admin), render the control **visibly disabled with an explanatory tooltip** — never hide via `v-if`. SectionCommentIcon + CommentTriageModal admin actions both follow this.

### 4. Email out of scope for this phase

`bd memory: pr717-no-email-in-v1`

Outbound email + opt-in UI + bounce + suppression + List-Unsubscribe = 1-2 days alone. Commenter feedback loop is satisfied by the in-app **My Comments page** on the user profile. Email is filed for a future phase.

### 5. Plan files vs beads cards — one tracking system per PR

For PR-scoped follow-ups discovered during build, file in this plan folder. Don't fragment into beads cards. Recovery context (`.beads/recovery-context.md`) tracks session state; this README + plan files track the PR.

---

## Architecture overview

### Data model additions (Tasks 04, 05)

`Review` (table `reviews`):

| Column | Type | Purpose |
|---|---|---|
| `triage_status` | string enum | DISA-vocab: `pending`, `concur`, `non_concur`, `concur_with_comment`, `informational`, `withdrawn`, `duplicate` |
| `section` | string | XCCDF key the comment targets (`check_content`, `fixtext`, etc.); null = general |
| `responding_to_review_id` | FK | Reply threading |
| `duplicate_of_review_id` | FK | Cross-rule canonical pointer |
| `triage_set_by_id`, `triage_set_at` | FK + ts | Who triaged + when |
| `adjudicated_by_id`, `adjudicated_at` | FK + ts | Who adjudicated + when |

`Component` (table `components`):

| Column | Type | Purpose |
|---|---|---|
| `comment_phase` | string enum | `draft`, `open`, `adjudication`, `final` — comment-window lifecycle |

### Authorization model

Three tiers, enforced via existing `authorize_*_project` / `authorize_*_component` patterns:

- **Viewer** (project membership, role: viewer)
  - Can post comments on rules they can see
  - Can reply, edit, withdraw their OWN comments
  - Can see all comments in components they're members of
  - Cannot triage or adjudicate
  - Cannot export the disposition matrix (PII concern)

- **Author / Reviewer** (project membership, role: author or reviewer)
  - All viewer abilities
  - Can triage comments (post triager response, set triage_status)
  - Can mark as duplicate (Task 24)
  - Can edit a comment's section (Task 30 — retroactive tagging)
  - Can export the disposition matrix WITHOUT email column

- **Admin** (project membership, role: admin)
  - All author abilities
  - Can adjudicate (set adjudicated_at)
  - Can edit `comment_phase` on the Component (Task 22)
  - Can export disposition matrix WITH email column (`?include_email=true`)
  - Can run runbook console procedures (force-withdraw, move-to-rule, hard-delete)

Each level is enforced **server-side** — UI hides the controls but the controller is the source of truth.

### Per-action permissions map

Beyond role tiers, individual actions have specific gates (`Review::ACTION_PERMISSIONS` map from Task 01). E.g., commenter equality for withdraw, project author+ for triage, etc.

### Frontend component tree (rule editor)

```
ProjectComponent.vue / RulesCodeEditorView.vue
├── ControlsCommandBar (top bar)
├── RuleNavigator (left sidebar — rule list with comment-count badge in Task 19)
└── RuleEditor (main editor)
    ├── RuleActionsToolbar
    ├── UnifiedRuleForm
    │   ├── RuleForm (Status, Severity, Title, Fix, etc.)
    │   ├── CheckForm (Check Text)
    │   └── DisaRuleDescriptionForm (Vuln Discussion, DISA Metadata)
    │       └── RuleFormGroup (each section)
    │           ├── SectionLabel
    │           ├── (lock icons)
    │           └── SectionCommentIcon (💬 — Task 16)
    └── RuleSatisfactions (Satisfies panel — comment counts in Task 23)

CommentComposerModal (opens via SectionCommentIcon click)
└── CommentDedupBanner (rule-level prior comments)

CommentTriageModal (opens from triage queue)
├── TriageStatusBadge
├── (decision picker — concur, non_concur, etc.)
├── (Mark-as-duplicate picker — Task 24)
├── (Edit Section picker — Task 30)
└── (Admin actions — deferred to follow-up phase)
```

### API endpoints

| Verb | Path | Action | Auth |
|---|---|---|---|
| POST | `/rules/:id/reviews` | Post a new comment / reply | viewer+ |
| PATCH | `/reviews/:id/triage` | Triage decision | author+ |
| PATCH | `/reviews/:id/adjudicate` | Adjudicate (set adjudicated_at) | author+ |
| PATCH | `/reviews/:id/withdraw` | Withdraw (commenter only) | original commenter |
| PATCH | `/reviews/:id/section` | Edit section metadata (Task 30) | author+ |
| GET | `/components/:id/comments` | Component-scope triage queue | viewer+ |
| GET | `/users/:id/comments` | My Comments page | self only |
| GET | `/components/:id/triage` | Full-page triage view | viewer+ |
| GET | `/components/:id/export?type=disposition_csv` | Disposition matrix CSV (Task 29) | author+ (admin for `?include_email=true`) |

---

## Execution protocol

When you pick up this PR cold, the execution rules are:

1. **Read this README + the next task file.** That's all the context you need.
2. **Each task is one TDD loop and ends with one git commit.** Don't chain commits.
3. **The Step numbers inside each task are mandatory and ordered.** Step 1 (write failing spec) is not optional — it's the discipline that catches "the test is testing the bug, not the requirement."
4. **Verify red before going green.** Step 2 in every task is "run and confirm the test fails." Skipping this is the single most common way TDD becomes theater.
5. **Run the vocabulary grep checks before every commit** (`98-vocabulary-grep-verification.md`). They take 2 seconds and catch the most common drift between layers (DISA term in a Vue template, friendly label in a migration).
6. **Mark progress by renaming.** After committing task `NN-foo.md`, rename it to `NN-foo-DONE.md` (`git mv`). This makes resume-after-compaction trivial — agent does `ls` and the next undone file is obvious.
7. **Do NOT edit a task file mid-execution.** If a step's expected output doesn't match reality, STOP and surface to the user. Don't quietly adjust the plan.
8. **Do NOT batch commits.** The atomic commit cadence is part of the review surface for the PR.
9. **Don't peek ahead.** Each task is scoped to itself. If a later task depends on something you're about to do, the dependency is called out explicitly in the task's "Depends on:" header.
10. **If you find a factual error in a plan file** (line numbers off, validators that already exist, etc.) — STOP, surface to the user. Don't quietly route around it. The plan files have been agent-reviewed for accuracy; if reality has drifted, the user needs to know.

---

## Status — what's complete

### Tasks 1-22 (original plan) — 19 of 22 done

**Backend (1-12, all DONE):**
- 01: `Review::ACTION_PERMISSIONS` map (per-action role gates)
- 02: Strong params + rate-limit on `Reviews#create`
- 03: i18n + vocabulary files (DISA ↔ friendly English mapping)
- 04: Migration — Review lifecycle columns
- 05: Migration — Component `comment_phase` enum
- 06: Review model validations (cross-scope, same-rule reply, etc.)
- 07: ReviewsController#create fixes
- 08: ComponentsController#comments endpoint (paginated triage queue)
- 09: UsersController#comments endpoint (My Comments)
- 10: ReviewsController#triage endpoint
- 11: ReviewsController#adjudicate endpoint
- 12: ReviewsController#withdraw + update endpoints

**Frontend (13-20):**
- 13: Vocabulary module (`triageVocabulary.js`)
- 14: ComponentComments triage table (with viewport-aware FilterDropdown)
- 15: CommentTriageModal scaffold
- 16: SectionCommentIcon + per-section icons in the rule form
- 17: CommentComposerModal (with CommentDedupBanner + reply mode)
- 18: RuleReviews thread — section/status badges + nested replies
- 20: My Comments page on user profile

**Still open from the original 22:** 19, 21, 22

### Foundation hardening (5 sweeps from code-review agents)

After Tasks 1-22 landed, two parallel `superpowers:code-reviewer` agents identified ~25 findings batched into 5 sweeps:

1. Security/correctness (PII leak, cross-scope validators, URL hardening)
2. Slideover removal cleanup (retired comp-reviews panel; role-gated triage actions)
3. Backend hardening (cache, format, pending re-triage)
4. Performance + missing test coverage
5. Polish (DRY, naming, doc comments)

### UI follow-ups during live test

While Aaron live-tested the Container SRG window, we shipped:
- ComponentCard cleanup (drop "Not Configured", relocate pending callout)
- UserProfile redesign (Option B — single-scroll stacked cards)
- FilterDropdown shared component (replaces native `<b-form-select>` for filter chrome)
- SectionCommentIcon refactor (matches lock/info icon pattern: raw `<b-icon>` + `v-b-tooltip.hover` + text-* color classes; never-hide-features per `vulcan-disabled-not-hidden`)
- Per-section comment composer end-to-end (chain from icon → modal mount → reply targeting)
- `data-turbolinks="false"` workaround on triage table rule links (turbolinks pack-mount race)

### Testing surface improvements

- **Dev seeds + factory traits** (commit `9ca407e`) — `viewer@example.com` / `author@example.com` / `reviewer@example.com` users (mirroring `admin@example.com`, password `12qwaszx!@QWASZX`) with project-tier memberships. Container Platform component seeded with PoC fields + `comment_phase: 'open'` + active comment-period dates; Photon OS 4 seeded with PoC + `comment_phase: 'draft'`. Idempotent (verified via two back-to-back `db:seed` runs). Factory traits (`:admin`, `:viewer`, `:author`, `:reviewer`, `:with_membership`) added to `spec/factories/users.rb` so test factories compose the same shape. Goal: 30-second login/logout role-switching loop for manual + Playwright testing.

---

## Status — what's tomorrow

Execution order (from `.beads/recovery-context.md`, ~5.75 hrs Claude-pace):

| # | Task | File | Est | Risk | Cuttable? |
|---|---|---|---|---|---|
| 21 | Comment period banner | `21-frontend-comment-period-banner.md` | 20m | Low | No — most visible to commenters |
| 28 | Filter dropdown sweep (STIG/SRG/diff/history) | `28-filter-dropdown-migration-stig-srg-and-sweep.md` | 30m | Low | No — visual consistency for DISA |
| 23 | Satisfies panel comment counts | `23-satisfies-panel-comment-counts.md` | 30m | Low | No — cross-rule discoverability |
| 19 | Rules-table comments column | `19-frontend-rules-table-comments-column.md` | 25m | Low | Yes (3rd cut) |
| 22 | Edit comment phase admin form | `22-frontend-edit-component-comment-phase.md` | 25m | Low | Yes (1st cut — admins can hit `/components/:id/edit` directly) |
| 24 | Mark-as-duplicate UI + canonical picker + chained-dup validator | `24-mark-as-duplicate-action.md` | 45m | Med | Yes (2nd cut — duplicates handled at adjudicate time anyway) |
| 30 | Edit comment section (retroactive) | `30-edit-comment-section.md` | 30m | Low | Yes (4th cut) |
| 31 | Inherited-requirements as first-class workflow | `31-inherited-requirements-workflow.md` | ~4-5h | Med | TBD — Aaron's call (may ship in PR-717 or fast-follow) |
| 32 | DISA-compliant rule editor streamlining | `32-disa-rule-editor-streamlining.md` | ~5h | Med | Likely follow-up phase (depends on 31's status-driven contract) |
| 29 | DISA disposition matrix CSV export | `29-disposition-matrix-csv-export.md` | 45m | Low | **NEVER cut** — federal deliverable |
| 98 | Vocabulary grep verification | `98-vocabulary-grep-verification.md` | 15m | Trivial | No |
| 27 + 99 | Cross-rule smoke + final sweep | `27-...md` + `99-...md` | 1h | Trivial | No |

**If time runs short, cut in this order:** 22 → 24 → 19 → 30. NEVER cut 29, 28, or 21.

---

## Status — what's deferred

Files in this folder marked `-DEFERRED.md` are not in this PR's scope but have plan structure ready for promotion in a follow-up phase.

### Tasks 25 + 26 — Admin force-withdraw + move-to-rule UI

`25-admin-force-withdraw-DEFERRED.md`, `26-admin-move-to-rule-DEFERRED.md`

**Reason:** events that warrant these are rare during a 1-2 day window with vetted commenters. Console procedures are auditable via `VulcanAuditable` + `audit_comment` setter. Documented in **`docs/runbook-public-comment-admin-actions.md`**.

**Prerequisites for promotion:**
- Add `:rule_id` to `Review`'s `vulcan_audited only:` list — currently NOT audited (review.rb:38). Move-to-rule that only changes `rule_id` would otherwise produce no audit record.
- Resolve the concurrent-reply race in move-to-rule via `SELECT FOR UPDATE` on parent + descendants, OR a DB-level CHECK constraint enforcing `reply.rule_id == parent.rule_id`.
- Decide cascade-vs-preserve semantics for force-withdraw of a thread (replies stay or follow).

### Other follow-ups (Task 99 §"What a follow-up phase picks up")

- Outbound email + opt-in UI + bounce handling + List-Unsubscribe headers
- Auto-advance `comment_phase` on date boundaries (cron job)
- DISA disposition-matrix **OSCAL** output — Task 29 covers CSV; OSCAL deferred because no canonical model exists. SAR-mapping is a documented dead-end (see Task 29 "Out of scope" section).
- Structured CCI/CVE/NIST control reference fields on comments
- Semantic dedup matching on comment composition
- Bulk triage actions
- Hard-delete with retention policy (rare cases — runbook §3 covers via console)
- Vue 3 / Bootstrap 5 migration

---

## Glossary — DISA vocab vs UI vocab

| DISA vocab (storage / API / CSV) | Friendly UI vocab |
|---|---|
| `pending` | Pending / Open |
| `concur` | Accept |
| `non_concur` | Decline |
| `concur_with_comment` | Accept with changes |
| `informational` | FYI / Informational |
| `withdrawn` | Withdrawn |
| `duplicate` | Duplicate of #X |
| `check_content` | Check |
| `fixtext` | Fix |
| `vuln_discussion` | Vulnerability Discussion |
| `disa_metadata` | DISA Metadata |
| `artifact_description` | Artifact Description |
| `xccdf_metadata` | XCCDF Metadata |

Sources of truth: `config/locales/en.yml` + `app/javascript/constants/triageVocabulary.js`. Pre-commit grep checks (Task 98) catch drift.

---

## Where to find things

### Plans + design docs
- This README — overview
- Individual task files — TDD-step-level, numbered roughly by add-order
- `docs/runbook-public-comment-admin-actions.md` — console procedures for the deferred admin operations

### Backend code
- `app/models/review.rb` — Review model with lifecycle validators + audited config (line 38)
- `app/models/component.rb` — `paginated_comments` (line 599+) for the triage queue + dedup
- `app/controllers/reviews_controller.rb` — triage, adjudicate, withdraw endpoints
- `app/controllers/components_controller.rb` — comments + triage views + export action
- `app/blueprints/rule_blueprint.rb` — :editor view feeds the rule editor; :navigator feeds the rule list
- `app/blueprints/satisfaction_blueprint.rb` + `satisfied_by_blueprint.rb` — feed the Satisfies panel (Task 23 enhances)

### Frontend code
- `app/javascript/components/components/CommentComposerModal.vue` — post / reply modal
- `app/javascript/components/components/CommentTriageModal.vue` — triage decision modal
- `app/javascript/components/components/CommentDedupBanner.vue` — rule-level prior-comment banner
- `app/javascript/components/components/ComponentComments.vue` — component-scope triage queue table
- `app/javascript/components/users/UserComments.vue` — My Comments page
- `app/javascript/components/shared/SectionCommentIcon.vue` — the 💬 icon next to each section
- `app/javascript/components/shared/FilterDropdown.vue` — viewport-aware filter dropdown (replaces `<b-form-select>` for filter chrome)
- `app/javascript/components/shared/TriageStatusBadge.vue` — status badge with DISA-key class hooks
- `app/javascript/components/shared/SectionLabel.vue` — section badge (DISA→friendly)
- `app/javascript/components/rules/RuleReviews.vue` — per-rule comment thread
- `app/javascript/components/rules/RuleSatisfactions.vue` — Satisfies panel (Task 23 enhances)
- `app/javascript/mixins/CommentIconHostMixin.vue` — DRY shim for sub-forms hosting SectionCommentIcons
- `app/javascript/constants/triageVocabulary.js` — DISA ↔ friendly mapping

### Specs
- `spec/javascript/components/components/Comment*.spec.js` — modal + dedup + composer
- `spec/javascript/components/components/ComponentComments.spec.js` — triage table
- `spec/javascript/components/users/UserComments.spec.js` — My Comments
- `spec/javascript/components/shared/SectionCommentIcon.spec.js` — icon component
- `spec/javascript/components/shared/FilterDropdown.spec.js` — shared dropdown
- `spec/requests/reviews_controller_spec.rb` — backend endpoint tests
- `spec/models/review_spec.rb` — model validations + auditing
- `spec/models/component_spec.rb` — paginated_comments query
- `spec/models/paginated_comments_pii_spec.rb` — PII scrubbing assertion

### Recovery + memory
- `.beads/recovery-context.md` — current session state (overnight pause checkpoint)
- `.beads/recovery-prompt.md` — quick-start commands
- `bd memories vulcan-comments-as-objects` — design philosophy
- `bd memories vulcan-disabled-not-hidden` — UX rule
- `bd memories pr717-vocabulary-layering` — vocabulary rule
- `bd memories pr717-no-email-in-v1` — email out of scope
- `bd memories pr717-viewer-role-expansion` — viewers can comment
- `bd memories bv-form-select-native` — why FilterDropdown exists

---

## Quality gates before merge (Task 99)

1. `bundle exec parallel_rspec spec/` — 0 failures
2. `pnpm vitest run` — 0 failures
3. `bundle exec rubocop` — 0 offenses
4. `yarn lint` — 0 warnings
5. `bundle exec brakeman` — no new warnings
6. Vocabulary grep checks (Task 98) — all 5 clean
7. Manual smoke test (Task 99 §6 — 6 scenarios + cross-rule §6.7)
8. Smoke includes the runbook console procedures (§6.7.4 / §6.7.6)

## Key smoke scenarios (Task 99 §6 + §6.7)

- Triager flow (concur, decline, close)
- Commenter flow (post, edit, withdraw, see in My Comments)
- IDOR / privacy spot-check
- Rate limit spot-check
- Cross-rule: Satisfies panel comment counts, mark-as-duplicate, runbook force-withdraw, runbook move-to-rule, mid-review relationship change

## After-merge actions

- Update PR description with summary + design doc + plan folder reference
- Reply to Copilot review comments with commit SHAs (Task 99 §8)
- Notify the Container SRG team out-of-band that the workflow is live
- File any live-window discoveries that didn't fit in this PR as follow-up plan tasks (separate folder for the next phase)

---

## Mental model TL;DR

If you read nothing else: **comments are first-class objects with stable rule_id ownership; cross-rule cases are handled by explicit admin/triager operations (mark-as-duplicate, move-to-rule, force-withdraw, edit-section); the satisfies relationship is informational for comment discoverability, not computational for inheritance.** Federal compliance + audit clarity are the load-bearing reasons.

Read the bd memory `vulcan-comments-as-objects` for the full philosophy.
