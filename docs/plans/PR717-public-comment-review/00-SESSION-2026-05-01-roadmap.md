# PR-717 Session Roadmap — 2026-05-01

> **Audience:** any agent (or human) picking up this branch mid-stream.
> **Purpose:** survive compaction + give a clean handoff. The locked decisions and step ordering below are the authoritative plan as of 2026-05-01.

## Branch context

- **Branch:** `feat/viewer-comments`
- **Base:** master
- **PR-717 scope:** Public Comment Review workflow — federal-compliance deliverable; Container SRG window LIVE; DISA stakeholders watching.

## Locked design decisions

These are **not open for re-litigation** without explicit authorization. Re-questioning them wastes time and erodes trust.

1. **No UTF-8 BOM in the disposition CSV.** RFC 4180 doesn't mention BOM. UK Government tabular data standard explicitly recommends removing BOM before publishing. Microsoft's recommended Excel-on-Windows path is Power Query (Data → Get Data → From Text/CSV) which handles UTF-8 reliably without BOM. CRLF row separators per RFC 4180 §2.1. Sources: RFC 4180, GOV.UK tabular standard, Microsoft Support docs.
2. **CRLF row separators.** Per RFC 4180 §2.1.
3. **Disposition data piggybacks the existing Working Copy CSV (zip of CSVs) and Excel (multi-sheet workbook) outputs.** No separate zip endpoint, no new Format radio in the modal, no Vue tab system in the modal. Always-on if the component has reviews.
4. **`/components/:id/export/disposition_csv` standalone endpoint stays** as the triage-page quick-access shortcut. Already shipped (`ff64c69` + `a267a6c`).
5. **Admin actions go in the UI, not in a runbook.** Force-withdraw, restore, move-to-rule, and hard-delete are UI features in this PR (Tasks 25, 25b, 26). The previous runbook (`docs/runbook-public-comment-admin-actions.md`) was a stopgap and gets deleted. No migration of its content — UI is self-documenting; bulk policy is self-documenting via absence of bulk UI.
6. **Tasks 31 + 32 dropped from this PR.** Task 31 (DISA inheritance pattern) deferred — easy to revisit if DISA flags a real export rejection. Task 32 (rule-editor streamlining) dropped entirely — the original plan contained a fabricated-gap claim about `RuleEditor.vue` that was never re-verified; speculative work doesn't belong in a federal-deliverable PR.
7. **FormMixin pack audit is in scope.** Recurring class of bug (esbuild bundle isolation; per `vulcan-esbuild-pack-axios-isolation` memory). Sweep all packs+modals for `axios.patch/post/put/delete` calls, ensure FormMixin reaches each one.
8. **Disabled-not-hidden** for interactive controls (locked rule). Status indicators (badges, count icons) hide when not applicable. Already applied to ProjectsTable in `4552d77`.

## Commits shipped this session (chronological, current branch)

```
e9cc8f1 refactor: add DispositionMatrixExport.generate_file Result wrapper
250115f refactor: expose DispositionMatrixExport.rows_and_headers helper
4552d77 fix: author/viewer/reviewer see disabled admin actions, not empty cell
a267a6c fix: drop UTF-8 BOM from disposition CSV — align with RFC 4180 + GOV.UK
272bc9c fix: separate disposition CSV content-format and transport encoding  ← squash candidate
30a6cc0 fix: missing FormMixin on CommentTriageModal broke triage CSRF
8b6a4df docs: add Task 31 (inherited reqs) + Task 32 (rule-editor streamlining)  ← Tasks dropped; consider deleting these plan files
a0810c7 feat: mark-as-duplicate picker UI + chained validator (Task 24)
af1f6f4 fix: preserve PR-717 lifecycle through json_archive backup/restore
ff64c69 feat: DISA disposition matrix CSV export (Task 29)  ← squash candidate
1f9b426 feat: confirm modal when regressing comment_phase out of final
e81dc8e fix: complete PoC coverage on every seeded component
9ca407e feat: dev seeds + factory traits
```

**Squash plan (Step 12):** Squash `ff64c69` + `272bc9c` + `a267a6c` into one clean disposition CSV commit. The cycle-1 BOM commit (`272bc9c`) contains a fabricated NIST 800-53 claim that should not survive into PR history.

## 13-step roadmap (current status)

| # | Step | Status |
|---|---|---|
| 1 | Working tree cleanup — salvage `generate_file`, drop `generate_zip` | ✅ `e9cc8f1` |
| 2 | Extract `rows_and_headers` helper for Excel reuse | ✅ `250115f` |
| 3 | Piggyback disposition into Working Copy CSV path (TDD) | ⏳ in progress |
| 4 | Piggyback disposition into Working Copy Excel path (TDD) | pending |
| 5 | Download button on `ProjectComponent.vue` (per-component editor gap) | pending |
| 6 | Live verify Download surfaces × CSV/Excel × admin/author tier | pending |
| 7 | Task 25 — Admin force-withdraw + Restore UI (TDD) | pending |
| 7b | Task 25b — Admin hard-delete UI (TDD, typed-confirmation safeguards) | pending |
| 8 | Task 26 — Admin move-to-rule UI (TDD; includes `:rule_id` audit prereq + RulePicker) | pending |
| 9 | Task 30 — Edit comment section retroactive (pop `stash@{0}`, continue TDD) | pending |
| 10 | FormMixin pack audit + per-component fixes | pending |
| 11 | Delete runbook file (`docs/runbook-public-comment-admin-actions.md`) | pending |
| 12 | Pre-merge cleanup: squash BOM cycle, rename `-DONE.md` plan files, update Task 29 plan with piggyback note, remove unused `LIFECYCLE_USER_FIELDS`, error logging on `CanonicalCommentPicker` empty catch | pending |
| 13 | Task 27 + 99 — final test sweep (`parallel_rspec` + `vitest run`) + manual smoke pass as admin/author/viewer/commenter | pending |

## Stash content (preserve)

`stash@{0}: On feat/viewer-comments: Task 30 WIP — section auditing model + spec (paused for verification)`

- `app/models/review.rb` — adds `:section` to `vulcan_audited only:` list (1 line)
- `spec/models/reviews_spec.rb` — adds `describe 'section auditing'` block with 3 specs
- Verified safe to pop (zero conflict against current HEAD per agent review)
- Matches Step 1 of the plan in `30-edit-comment-section.md`
- After pop: continue with Step 3 (request spec for `PATCH /reviews/:id/section`)

## Architectural notes (so the next agent reads code correctly)

- **CSV piggyback injection point:** `Export::Base#call` `else` branch (base.rb:40-43). Today: `components.map { |c| export_component(c) }`. Tomorrow: `components.flat_map { |c| [export_component(c), disposition_result_for(c)].compact }`. Single-component case still works because `Packager.package` passes through a single Result.
- **Excel piggyback injection point:** `Export::Base#export_as_workbook` (base.rb:106-125). After building the per-component rule sheet, append a disposition sheet via `DispositionMatrixExport.rows_and_headers(component:)` if the component has any disposition records.
- **Disposition gating:** include only when the component has at least one top-level review. Implementation: a method on `Component` like `disposition_records_exist?` that runs the existence check matching `DispositionMatrixExport.top_level_reviews` semantics.
- **Audit logging on the piggyback path:** per-component audit entry on `@component.audits.create!`, mirroring the existing single-component `perform_disposition_csv_export` pattern. Project-level audit logging is NOT today's pattern for rule-data exports either; staying consistent.

## Process discipline (calibrated to this session's pain points)

- **Don't run `rubocop -A`.** Aggressive autocorrect can break behavior. Read each offense, decide, hand-edit. Lefthook's pre-commit hook may run safe autocorrects automatically; that's separate.
- **Don't fabricate.** Standards claims (RFC 4180, NIST 800-53, GOV.UK, etc.) need a real source citation, not "I think this is what it says." When unsure: say "I don't know — let me check."
- **Don't grab license.** Partial answers ("yes that part is fine") aren't blanket approval. Wait for explicit go on each step's destructive action.
- **Don't `git checkout <ref> -- <file>`** without explicit approval — it overwrites uncommitted work.
- **Read before reasoning.** Don't propose injection points without reading the actual code first.
- **Disabled-not-hidden** for interactive controls. The `vulcan-disabled-not-hidden` and `-scope` bd memories are authoritative.

## When in doubt

Ask. The cost of a clarifying question is seconds; the cost of acting on a wrong assumption is hours.
