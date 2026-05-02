# PR-717 Session B handoff (2026-05-02 evening)

**For Will (and his Claude) reviewing the post-agent-review follow-ups before merge.**

Pair-doc with `2026-05-02-agent-review-swarm.md` (the morning's review-swarm output that surfaced these). Read that one first if you want the *why*; this doc is *what landed*.

---

## TL;DR

Four P2 follow-up cards from the morning's 6-agent review swarm landed in this session. PR `feat/viewer-comments` is now merge-ready pending Sonar's auto re-scan on the new commits.

| Card | Commit | One-line what |
|---|---|---|
| `vulcan-v3.x-vb4` | [`8767214`](../../../commit/8767214) | request_uuid producer side — wraps rake puller + JsonArchiveImporter, fixes bulk-insert audit gap |
| `vulcan-v3.x-kea` | [`eef28a7`](../../../commit/eef28a7) | split validate_foreign_key out of .4 migration into a paired 2-pass migration |
| `vulcan-v3.x-a5u` | [`cf3656a`](../../../commit/cf3656a) | shared example `'a canonical toast response'` + opt-in for 3 controllers |
| `vulcan-v3.x-bpy` | [`8417160`](../../../commit/8417160) | clear Sonar reliability gate — 5 a11y/route fixes |

One card deferred (not landed): `vulcan-v3.x-g77` — CommentTriageModal "accept and edit" inline editor. Aaron's idea, scoped as a separate post-merge PR. Don't review against this branch.

---

## Test counts at branch tip (`8417160`)

- `bundle exec rake spec:parallel` → **2298 / 2298** (was 2278 at start of session; +20 specs)
- `yarn vitest run` → **2288 / 2288**
- `bundle exec rubocop` → 0 offenses
- `yarn lint:ci` → 0 warnings
- `bundle exec brakeman` → 0 (6 documented ignored)
- `bundle exec bundler-audit` → 0

Run all five before signing off your review pass.

---

## What to look at per commit

### `8767214` — request_uuid producer side (`vb4`)

**Closes Scenario 6 of the audit-compliance review** — the "rake invocation produces 1000 distinct request_uuids" gap.

Files:
- `app/lib/vulcan_audit.rb` — added two class methods:
  - `VulcanAudit.with_correlation_scope(uuid: SecureRandom.uuid) { |u| ... }` — snapshot+restore `Audited.store[:current_request_uuid]` so it nests under HTTP requests too.
  - `VulcanAudit.current_request_uuid` — single source of truth, used by both the `.14r` consumer hook and bulk-build paths that bypass callbacks.
  - Updated `create_initial_rule_audit_from_mapping` to populate `request_uuid` at build time (fixes the bulk-insert gap below).
- `app/services/import/json_archive_importer.rb` — `#call` body wrapped in `with_correlation_scope`.
- `lib/tasks/stig_and_srg_puller.rake` — `save_data` task body wrapped in `with_correlation_scope`. Preemptive: `Stig`/`SRG`/`StigRule`/`SrgRule` aren't `vulcan_audited` today, but any audited descendant added later picks up the scope automatically.

**Bulk-insert subtlety to flag in your review:** `activerecord-import` (Component#import_srg_rules → Rule.import recursive: true) BYPASSES ActiveRecord callbacks, so the `.14r` `before_create :ensure_request_uuid` never fires. Pre-fix the BaseRule audits had `request_uuid = NULL` even inside a scope. The fix is the `request_uuid:` key in `create_initial_rule_audit_from_mapping`'s hash — gets carried through the bulk INSERT verbatim. Regression spec: `spec/services/import/json_archive_importer_spec.rb` "covers the bulk-insert path too (BaseRule audits via activerecord-import)".

Tests added: 7 unit (`spec/lib/vulcan_audit_spec.rb` `.with_correlation_scope` describe) + 3 integration (`spec/services/import/json_archive_importer_spec.rb` `.vb4` context) + 2 unit (`spec/lib/tasks/stig_and_srg_puller_spec.rb`).

### `eef28a7` — split validate_foreign_key (`kea`)

Mechanical 2-pass split. The .4 migration ran `add_foreign_key validate: false` AND `validate_foreign_key` in the same DDL transaction → write-blocking ACCESS EXCLUSIVE on `reviews` for the validate scan duration on production-sized tables.

Files:
- `db/migrate/20260502080000_change_review_responding_to_fk_to_restrict.rb` — removed inline `validate_foreign_key`, doc-comment now points at the paired migration.
- `db/migrate/20260502080001_validate_review_responding_to_fk.rb` (new) — `disable_ddl_transaction!` + validate. Idempotent on dev DBs that ran the eager-validate shape.
- `spec/migrations/responding_to_fk_two_pass_spec.rb` (new) — 4 specs that encode the END STATE invariant (FK exists + on_delete: :restrict + `pg_constraint.convalidated = true`). Either 1-pass or 2-pass shape passes the spec, so the regression guard survived the rollover.

Schema unchanged (Strong Migrations doesn't track validate state in `db/schema.rb`).

### `cf3656a` — canonical toast shared example (`a5u`)

Regression insurance after the morning swarm caught a 14-site regression on the canonical toast contract. Pre-fix, `b671593` removed AlertMixin's string-toast handling but missed those 14 endpoints — caught and fixed in `906941d`.

Files:
- `spec/support/shared_examples/canonical_toast_response.rb` (new) — asserts `toast` is a Hash with `title` (present String) + `message` (Array) + `variant` (in `{success, warning, danger, info}`). Failure messages cite PR-717 .19d / .a5u so future regression authors find the historical context inline.
- 3 controllers opted in this landing: `reviews` (POST `/rules/:id/reviews` success), `stigs` (POST `/stigs` success), `memberships` (DELETE `/memberships/:id` success).

The remaining 5 toast-emitting controllers (`rule_satisfactions`, `rules`, `security_requirements_guides`, `components`, `users`) can opt in with a one-line `it_behaves_like 'a canonical toast response'` as their next toast-related spec gets touched. Incremental adoption — not a sweep PR.

### `8417160` — Sonar reliability gate fixes (`bpy`)

5 reliability issues, all real, all fixable inline (no false-positive suppressions). Should drop new_reliability_rating from C → A on next Sonar scan.

| Issue | Fix |
|---|---|
| Web:S6853 (a11y) `CommentTriageModal.vue:35` "Move to section" `<label>` | Renamed to `<div>` — FilterDropdown below already has `aria-label`, so the heading is presentational |
| Web:S6853 (a11y) `CommentTriageModal.vue:248` "Type comment ID to confirm" `<label>` | Explicit `for=`/`id=` pairing on the b-form-input below |
| Web:S6842 (a11y) `RulePicker.vue` `<li role="button">` | Adopted listbox/option ARIA pattern: `<ul role="listbox">` + `<li role="option" :aria-selected>` |
| Web:S6842 (a11y) `CanonicalCommentPicker.vue` `<li role="button">` | Same fix as RulePicker |
| rubydre:S7875 `routes.rb:39` `get :comments` | Explicit: `get :comments, to: 'users#comments'`. Helper unchanged. |

---

## Open follow-ups (NOT in this PR)

- `vulcan-v3.x-g77` — CommentTriageModal "accept and edit" feature. Aaron's idea from the morning review. Phased: text-only sections first, then structured fields. Defer to a separate post-merge PR.

---

## Open questions for Aaron / Will to confirm before merge

- Sonar quality gate re-scan should auto-trigger on the push to `feat/viewer-comments` (commits up through `8417160`). Confirm `new_reliability_rating` lands at A before pulling the merge trigger.
- The 3 toast-shared-example opt-ins (reviews/stigs/memberships) cover 3 of 8 toast-emitting controllers. Will may want to opt in additional ones during his review pass; 1-line addition each.

---

## Recovery context

The morning session's recovery context (`.beads/recovery-context.md`) and agent-review output (`2026-05-02-agent-review-swarm.md`) capture:
- Why each follow-up was filed (the 6-agent review swarm findings)
- Locked design decisions (cards 1–35 carried forward)
- Behavioral failures + lessons (no band-aid menus, no DRY-violation accumulation past instance #3, etc.)

Worth a skim before reviewing if the morning's swarm context isn't already loaded.
