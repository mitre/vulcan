# PR-717 post-merge remediation — follow-up notes

Notes on items closed during the post-merge remediation epic
(`vulcan-v3.x-1dj`). Each entry is short — see the linked commit for
full context, and the bd card for ACs and rationale.

## .4 — Cascade ownership + forensic correlation bundle (F1–F7)

The original `.4` was a narrow FK swap. Six expert review agents
expanded it into a 7-piece bundle that closes adjacent gaps surfaced
by the same root question (cascade ownership). Eight commits.

### F1 — Rails owns the cascade; FK is the safety net

Original FK `responding_to_review_id on_delete: :cascade` + Rails
`dependent: :destroy` is the canonical "double-cascade" anti-pattern.
Postgres cascade skips Rails callbacks → audited gem doesn't capture
per-Review destroy events → the audit-trail recoverability work in
`c92fc83` (`associated_with: :rule`) doesn't deliver.

**Fix:** new migration `20260502080000` swaps to `:restrict` via
Strong Migrations 2-pass (`validate: false` + separate
`validate_foreign_key`). Rails `dependent: :destroy` (kept) walks
children-first recursively, so admin_destroy of a parent works
unchanged — the FK constraint is satisfied at parent-delete time
because all descendants are already gone via Ruby-side destroy.

**Down migration is reversible** (re-adds `:cascade`) but carries a
WARNING comment — restoring `:cascade` re-introduces the audit-trail
gap. Only run `down` in dev for round-trip tests.

### F3 — Pre-destroy snapshot is the legal record

Per-Review destroy audit rows (created by audited's after_destroy
callback) capture pre-destroy state for columns in
`vulcan_audited only:` list. That list does NOT include `user_id`,
`created_at`, `responding_to_review_id`, or the imported_attribution
columns. For PII/legal hard-delete, the operator-facing record needs
the full row state.

**Fix:** `admin_destroy` walks the entire reply tree via
`Review.subtree_with_ancestry(root_id)` (Postgres `WITH RECURSIVE`
CTE) and captures `Review#snapshot_attributes` for each into the
Component-level audit row's `audited_changes[:destroyed_review_snapshots]`.

**Snapshot shape** (per-row hash, 19 fields):
- audited columns: `triage_status`, `adjudicated_by_id`,
  `duplicate_of_review_id`, `comment` (FULL text, not truncated),
  `rule_id`, `section`
- lifecycle: `triage_set_by_id`, `triage_set_at`, `adjudicated_at`,
  `action`, `responding_to_review_id`
- imported attribution: `triage_set_by_imported_email/name`,
  `adjudicated_by_imported_email/name`
- forensic: `id`, `user_id`, `created_at`, `updated_at`

**Timestamps as ISO8601 strings** (not `Time` objects) — avoids the
YAML safe-load break documented at `app/models/review.rb:34-37`
where `ActiveSupport::TimeWithZone` trips Rails 7.1+ safe-dump
unless explicitly allowlisted. ISO8601 strings round-trip cleanly
through YAML on `Audit#find`.

### F4 — `request_uuid` correlation primitive

Audited gem auto-populates `request_uuid` on every audit row created
during one Rails HTTP request (via `Audited::Sweeper` Rack
middleware). All audits in the same `admin_destroy` request share
one UUID — the Component-level row + the parent's destroy event +
every cascaded child's destroy event.

**`AuditEventBundle` PORO** (`app/services/audit_event_bundle.rb`)
wraps the indexed `request_uuid` query so forensic reconstruction
of a multi-row admin operation is one ergonomic call.

**Forensic-query example** (find everything destroyed in incident X):

```ruby
# Operator opens a bundle from the Component-level audit ID:
bundle = VulcanAudit.bundled_with(component_audit_id)

bundle.trigger                   # Component-level admin_destroy_review row (the operator action + audit_comment)
bundle.related                   # All audit rows sharing the request_uuid
bundle.destroyed_reviews         # Per-Review destroy events (parent + every cascaded child)
bundle.destroyed_review_count
bundle.to_h                      # Compact JSON-serializable summary

# Pair with the trigger's destroyed_review_snapshots for full pre-
# destroy state of every affected row:
bundle.trigger.audited_changes[:destroyed_review_snapshots]
```

**Boundary (closed by .14r):** `request_uuid` is now guaranteed
present on every audit row created via `audits.create!` (or any
Audited create-lifecycle path). `VulcanAudit#ensure_request_uuid`
runs as a `before_create` callback that:

1. Preserves any value already set by `Audited::Sweeper` (HTTP path).
2. Falls back to `Audited.store[:current_request_uuid]` if set by
   job/rake middleware (the integration hook for non-HTTP contexts
   that want correlation across multiple audit rows in one operation).
3. Falls back to `SecureRandom.uuid` for genuine orphans.

Direct SQL inserts that bypass the audited gem entirely (e.g.
`Review.insert!` in `ReviewBuilder`) do not produce audit rows at
all — the .10 work added a single Component-level audit row per
import that DOES go through `audits.create!` and therefore has a
`request_uuid` from this callback.

`bundled_with` still returns just the trigger row when an audit
predates `.14r` (historical rows, dev DB seeded before the callback
landed). No retroactive migration — `request_uuid` is set at create
time only.

### F5 — Defensive transaction on `ReviewBuilder.build_all`

`JsonArchiveImporter#perform_import` already wraps in an outer
`ActiveRecord::Base.transaction` for the production path; the inner
txn becomes a savepoint there (no-op semantics). For direct/test
callers that the constructor explicitly supports, the inner txn
ensures pass-1 inserts roll back if pass 2 (relink_threaded_refs)
or pass 3 (drop_invalid_reviews + write_import_audit) raises.

### F7 — Row locks on concurrent admin actions

Two admins simultaneously: A moves a review subtree, B hard-deletes
a node. Without an explicit row lock at the start of each admin
action's transaction, B's destroy may race with A's move-update.
After the F1 FK swap to `:restrict`, the failure mode escalated
from silent corruption to a noisy 500.

**Fix:** `@review.lock!` inside the `Review.transaction` block on
both `admin_destroy` and `move_to_rule`. SELECT FOR UPDATE so the
second admin's transaction waits for the first to commit/rollback.
`lock!` MUST be inside a transaction — held only for the executing
statement otherwise. Released cleanly on transaction commit/rollback.

Race-condition specs proper would need true two-thread orchestration
with separate AR connections — flaky in test, deferred. The lock!
call presence is the load-bearing assertion in the request specs;
the SQL semantics are documented Rails.

### Bundle commits

| Step | Commit | Subject |
|---|---|---|
| 1 | `7a7fc2e` | F4 — AuditEventBundle PORO + VulcanAudit.bundled_with |
| 2 | `57e10c0` | F3 prereq — Review.subtree_with_ancestry CTE scope |
| 3 | `33b2bea` | F1+F2 — FK swap + cascade-correlation regression spec |
| 4a | `d3314da` | F3 — Review#snapshot_attributes |
| 4b | `1f782f9` | F3 — destroyed_review_snapshots in admin_destroy audit |
| 5 | `cf30d56` | F7a — admin_destroy row lock |
| 6 | `d2b11fe` | F7b — move_to_rule row lock |
| 7 | `fd0a5ac` | F5 — ReviewBuilder.build_all transaction wrap |

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
