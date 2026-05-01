# PR-717 post-merge remediation — follow-up notes

Notes on items closed during the post-merge remediation epic
(`vulcan-v3.x-1dj`). Each entry is short — see the linked commit for
full context, and the bd card for ACs and rationale.

## .10 — Audit-laundering chain (admin_destroy → re-import)

**Problem:** `Review.insert!` in `ReviewBuilder` bypasses the audited
gem entirely. After an `admin_destroy` cascades replies (audited keeps
the destroy event on the originals), a re-import produces resurrected
review rows with no audit history. A malicious admin could destroy +
re-import to launder the lifecycle trail (no triage_set_by audit, no
destroy event tied to the resurrected row).

**Fix:** Per import, ReviewBuilder now writes a single Component-level
audit row with:

- `action: 'import_reviews'`
- `audited_changes`:
  - `archive_vulcan_version` — from manifest
  - `archive_exported_at` — from manifest
  - `review_external_ids` — list of original IDs from the source archive
- `comment` — human-readable summary
- `user_id` — set when the controller passes `imported_by:`

**Reconstruction:** Given a Component, the union of:

1. Per-Review audit rows for resurrected IDs (sparse — only created for
   ones already on this instance via the originating create-time audit)
2. Component `import_reviews` audit rows (carries the external_ids list
   + which archive)

…lets you trace a destroyed-then-restored review back to its origin
archive. The destroy row remains on the original Review's audit history;
the import row tells you the resurrected row's source.

**Constraints:**

- The audit row is written ONLY when ReviewBuilder receives both
  `component:` and `manifest:` kwargs. Direct (test) callers without
  those kwargs skip the audit (no surprise side effects).
- `Review.insert!` still bypasses per-review audited callbacks — no plan
  to change that since the current ReviewBuilder pattern is intentional
  (matches `Component#duplicate_reviews_and_history`). The Component-level
  row is the recovery surface, not per-Review re-creation events.

## .9 — Validate Review records during import

**Problem:** `Review.insert!` skips ALL model validators
(duplicate_status_requires_target, responding_to_must_be_same_rule,
duplicate_of_must_be_same_component, inclusion validators on
triage_status / section). A malicious or legacy archive could carry
records that violate post-snapshot invariants.

**Fix:** Post-insert validation pass via custom validation context
`:import_integrity` (Rails Guides §7.3 canonical pattern).

- User-action validators (project permissions, role gates) are tagged
  `on: %i[create update]` — they run on normal saves but are skipped
  in the import context.
- Data-integrity validators (no `on:` option) run in every context per
  Rails Guides:
  > "When an explicit context is triggered, the model runs both the
  >  validations associated with that specific context and any
  >  validations that have no context defined."

Records failing validation are removed; a warning carrying the
external_id + validator messages is recorded on the import Result.
Children pointing at a removed parent cascade-delete via the existing
FK on_delete: :cascade on `responding_to_review_id`.

## .2 — Split lifecycle migration

**Problem:** `20260429145530_add_lifecycle_columns_to_reviews` created
columns + 5 indexes inside one transaction. ACCESS EXCLUSIVE on
`reviews` for the duration of all index builds.

**Fix:** Columns + FKs stay in `20260429145530` (transactional, fast).
Indexes moved to `20260501171000_add_review_lifecycle_indexes_concurrently`
with `disable_ddl_transaction!` + `algorithm: :concurrently` +
`if_not_exists: true`. Pattern matches
`20260209232046_add_severity_count_indexes_to_base_rules`.

The `if_not_exists: true` makes the new migration a no-op on instances
where the prior pre-split form of the original migration already
created the indexes — verified on the local dev DB and on a fresh test
DB via `RAILS_ENV=test db:drop db:create db:migrate`.
