# PR-717 Final Review Swarm — 2026-05-02

Six independent agent reviews + GitHub Copilot review + sonarqubecloud quality gate + wdower (pre-session) UX review of `feat/viewer-comments` branch on Vulcan PR #717.

Branch state at review time: 28 commits this session (`4db99da..b671593`). Total branch: 193 commits, 237 files changed (+31836 / -928).

---

## Decision summary

### Acted on inline (commit `906941d`)

| # | Finding | Source agent | Action |
|---|---|---|---|
| 1 | **P0 regression** — AlertMixin string branch removed (`b671593`) but ~14 string-toast endpoints missed. Production toasts on those endpoints would silently disappear. | Architecture | Migrated 12 sites to `render_toast` (or inline canonical for multi-key responses). 7 spec assertions updated. |
| 2 | `record_invalid_titles` ancestor walk non-idiomatic — use `class_attribute` | Maintainability | Replaced hand-rolled `superclass.respond_to?(:record_invalid_title_for)` walk with `class_attribute :record_invalid_titles_map` (Devise/Pundit pattern). |
| 3 | Stale doc reference at `app/blueprints/review_blueprint.rb:44` claims `app/blueprints/concerns/imported_attribution_fields.rb` — file is at top level. | Maintainability | Doc updated to match reality + explained Zeitwerk autoload special-paths reasoning. |

### Validated as already-correct (no action)

| # | Finding | Source | Verdict |
|---|---|---|---|
| 4 | Copilot: viewer can POST any review action via `authorize_viewer_project` | Copilot · Security agent | False alarm — `Review::ACTION_PERMISSIONS` validator gates per-action role at the model layer (`app/models/review.rb:107-115, 186, 249-263`). Tested at `spec/models/reviews_spec.rb:367-379` + `spec/requests/reviews_spec.rb:773-775`. |
| 5 | Zip-bomb fix relies on CD `entry.size` — could be lied about | Security | Effective. rubyzip 2.4.x `Zip.validate_entry_sizes = true` enforces actual decompressed size matches CD; lying CD raises `Zip::DecompressionSizeError` caught by `rescue Zip::Error` at line 103. |
| 6 | render_toast XSS surface | Security | Clean. Vue's `createElement(tag, stringChild)` auto-escapes; no `v-html` path in the toast chain. |
| 7 | Audit forensic completeness — scenarios 1-5 (admin destroy, move, user destroy, archive import, lifecycle) | Audit-compliance | PASS. Investigator can reconstruct from audit table 6 months later. |
| 8 | All 8 new migrations production-safe | Migration | PASS. Strong-Migrations canonical patterns; partial index verified used at scale via EXPLAIN on synthetic 100k rows (Index Scan Backward, 0.092 ms total). |

### Follow-up bd cards filed

| Card | Severity | Topic |
|---|---|---|
| (F1, see below) | P2 | Wire `Audited.store[:current_request_uuid]` into rake tasks + JsonArchiveImporter (`.14r` producer side) |
| `vulcan-v3.x-kea` | P2 | Split `validate_foreign_key` out of migration `20260502080000` (Strong Migrations 2-pass) |
| `vulcan-v3.x-a5u` | P2 | Add `'a canonical toast response'` shared example to prevent AlertMixin regression |
| `vulcan-v3.x-bpy` | P2 | Triage Sonar quality gate failure on PR #717 (Reliability rating C) |
| `vulcan-v3.x-g77` | P3 (feature) | CommentTriageModal: 'accept and edit' inline edit box for the targeted element |

### Lower-severity findings — noted in synthesis, not separately filed

- F2 (P3): `triage`/`adjudicate` controllers don't require audit_comment — state diff captured but no operator "why" for routine triage. Policy decision, not bug.
- F4 (P3): `.17` EXPLAIN test is a tautology (`expect(plan).to be_a(String)` always passes). Delete or seed populated table.
- F5 (P3): `.20` blueprint `author_email` gating has no paired request-spec verifying a controller actually opts in.
- F6 (P3): `.14r` request_uuid integration test only verifies callback's local logic, not end-to-end via job/rake.
- F7 (P3): `ImportedAttribution` macro has no direct unit test (covered transitively via Review).
- F8 (P3): `Review#default_triage_status_for_new_top_level_comment` callback has no direct test (every spec sets `triage_status:` explicitly).
- F9 (P3): `render_success(title, message)` shorthand for the 13+ sites repeating `render_toast(... variant: 'success', status: :ok)`.
- F12 (P4): `js_const_keys` regex parser in `triage_keys_spec` is brittle to JS shape changes — add a comment about it.
- F13 (P4): Global `Audited.store.clear` RSpec config hook to prevent leaked-state flake.
- Copilot C1/C2 (P4): `spec/requests/reviews_spec.rb` POST specs missing `component_id` — cosmetic, specs pass without it because SMTP is disabled in test.
- Copilot C3 (P4): `spec/models/reviews_spec.rb` failure message lacks role info — cosmetic improvement.

### Lint / security clean state confirmed

- RuboCop: 424 files, **0 offenses**
- ESLint (--max-warnings 0): clean
- Brakeman: **0 security warnings** (6 ignored, documented)
- bundler-audit: **0 vulnerabilities**

---

## Aaron's pending decision

Of the 4 P2 follow-ups + 1 P3 feature, recommended split:

**DO NOW (~75 min total):**
- F1 — request_uuid producer side. Real audit-compliance gap. Low risk.
- F3 — split `.4` FK validate. Operational safety. Mechanical fix.
- F10 — canonical toast shared example. Cheap regression insurance for the very issue Architecture agent caught today.

**INVESTIGATE FIRST:**
- F11 — sonar quality gate. Fetch issue list via `mcp__sonarqube__search_sonar_issues_in_projects`. Triage time-cost, then decide.

**DEFER:**
- `g77` — triage edit modal feature. Needs design pass + scope conversation, separate PR.

**Status when context window forced compaction (~76% of 1M):** decision pending Aaron's go.

---

## GitHub Copilot — line comments

4 line-level comments + 1 review summary on PR #717.

### 1. `app/controllers/reviews_controller.rb:13`

> Switching create authorization to `authorize_viewer_project` means viewers can now POST *any* review action, not just `comment`. In `Review`, `can_request_review` does not check role, so a viewer can set `review_requestor_id` by sending `action=request_review`. If the intent is "viewers can comment only", gate non-comment actions (e.g., require author+ for `request_review`/`revoke_review_request`) either in the controller or by adding a permission check in the corresponding model validations.

**Status: false alarm** (validated by Security agent). The model-layer `Review::ACTION_PERMISSIONS` map + `validate_project_permissions` validator (registered with `on: %i[create update]`) gate this before any save callback fires. Defense-in-depth holds.

**Suggested doc improvement (low-pri):** add a one-line comment at `reviews_controller.rb:17` explaining that the loosened `authorize_viewer_project` is safe because per-action role tiers are enforced by `Review::ACTION_PERMISSIONS` at the model layer. Saves the next reviewer the same investigation.

### 2. `spec/requests/reviews_spec.rb:51`

> These request specs POST review actions without `component_id`. The frontend helper (`useRuleActions`) includes `component_id`, and SMTP notifications for review actions rely on it (mailer does `Component.find(component_id)`). To keep the spec aligned with real requests (and avoid failures if SMTP is enabled in test), include `component_id: component.id` in the posted `review` params for `approve`/`request_changes`/`request_review` cases.

**Status: cosmetic.** Specs pass without it (SMTP disabled in test). P4 fix-when-touching.

### 3. `spec/requests/reviews_spec.rb` (request_review case)

Same as #2 — Copilot's suggested patch:

```ruby
review: {
  action: 'request_review',
  comment: 'Please review.',
  component_id: component.id
}
```

### 4. `spec/models/reviews_spec.rb` (failure message)

> This failure message says "(membership role)" but doesn't actually include the user's effective role, which makes debugging harder if it ever fails. Consider including `user.effective_permissions(@p1r1.component)` (or similar) in the message so the output matches what it claims to show.

```ruby
expect(review).to be_valid,
                      "expected #{user} (membership role: #{user.effective_permissions(@p1r1.component)}) to be able to comment"
```

**Status: cosmetic.** P4.

---

## sonarqubecloud[bot] — quality gate

> **Quality Gate failed**
> Failed conditions
> - C Reliability Rating on New Code (required ≥ A)

URL: https://sonarcloud.io/dashboard?id=mitre_vulcan&pullRequest=717

`SONARCLOUD_TOKEN` env var is available. Issue list to be fetched via `mcp__sonarqube__search_sonar_issues_in_projects` (filed as `vulcan-v3.x-bpy`).

---

## wdower — pre-session UX review (2026-05-01)

Posted before this session's work. Most points likely addressed by other commits in the branch, but worth reviewing for any still-open items:

- "Review" and "Comment" buttons share speech-bubble icon and are right next to each other; Review should probably be a different icon.
- Comments are disabled until you pick status on a requirement. Why? Status selection is something viewers might comment on before doing.
- "Open/closed for comment" — should Draft status allow comments without an end date set?
- Comment button should be grayed out if component is in Draft mode (currently throws an error on submit).
- (Unrelated to PR) Show name/email of logged-in user when clicking the profile button in top right.
- Comment button becomes available immediately after setting status, even if the status change isn't saved yet — race condition / lost state risk.
- Comments panel should be reachable via a button on the component other than the one in the "Open for Comments" banner.

Per memory `vulcan-disabled-not-hidden`: the disabled-with-tooltip pattern was the resolution for several of these. May still warrant a wdower follow-up review pass after PR-717 lands.

---

## Agent 1 — Architecture / DRY / SOLID

**Verdict:** Solid session. Biggest win: `ImportedAttribution` macro extraction (`dfc81ed`) — clearly the right call. Biggest miss: commit `b671593` materially incomplete — 13 string-toast endpoints still ship while `AlertMixin` had its string-handling branch removed. **In production today, success toasts on those endpoints will silently disappear.** That's a regression introduced by this session.

(This finding became the **P0 acted-on item #1** above. Fixed in `906941d`.)

### Other ranked findings (acted-on or deferred):

- **P1 DRY:** 13+ call sites repeat `render_toast(title:, message:, variant: 'success', status: :ok)`. Worth a `render_success(title, message)` shorthand on ApplicationController. → Filed as F9.
- **P1 DRY:** 3 multi-key inline canonical hashes (rules#create, users#update, projects#create) handwrite the toast object because render_toast can't piggyback extras. → Worth a `render_toast(..., extras: {...})` keyword OR expose `toast_payload(title:, message:, variant:)`. The comments admit the duplication — the helper API is wrong. → Noted, P3.
- **P2 DRY:** 3 nearly-identical attribution display test blocks at `spec/models/reviews_spec.rb:983-1115`. Worth a `shared_examples 'imported attribution'` parameterized table. → Noted, P3.
- **P2 missing test:** `ImportedAttribution` macro has no direct unit test (transitive only through Review). → Filed as F7.
- **P2 missing test:** `Review#default_triage_status_for_new_top_level_comment` has no direct test (every existing spec passes `triage_status: 'pending'` explicitly, hitting the early-return guard). → Filed as F8.
- **P3 coupling:** `User#preserve_review_attribution` (before_destroy with prepend: true) — correct as written; documented well in source. Acceptable.
- **P3 coupling:** `VulcanAudit#ensure_request_uuid` documents `Audited.store[:current_request_uuid]` hook but no producer of that store key exists. SecureRandom branch fires for all non-HTTP paths (correct fail-safe). → Filed as F1.
- **P3 missing test:** `move_to_rule` outbound audit hand-rolls `audited_changes` — `VulcanAudit#format` may not render those keys cleanly. Test only asserts presence + count. → Worth one more assertion. P3.
- **P4:** `default_triage_status_for_new_top_level_comment` callback ordering — runs after `take_review_action`. Safe today. One-line ordering comment ("must run after take_review_action so action is finalized") would prevent footgun.

---

## Agent 2 — Security

**Verdict: SHIP. Copilot concern is a false alarm; defenses validated.**

### Findings

1. **Copilot's "viewer escalates to request_review" — FALSE ALARM** (see decision summary #4 + Copilot section above).

2. **Zip-bomb budget — VALID, with non-obvious belt+suspenders.** `app/services/import/json_archive_importer.rb:72-81` reads `entry.size` from CD, sums, rejects when total > `Settings.import.json_archive_size_budget_mb` (default 500). A malicious archive can lie in the CD, but **rubyzip 2.4.1 has `Zip.validate_entry_sizes = true` by default** — `zip.read` raises `Zip::DecompressionSizeError` on actual decompression mismatch, caught by `rescue Zip::Error` at line 103. Effective protection: budget check stops honest-big archive; rubyzip stops lying-CD archive. Coverage: `spec/services/import/json_archive_importer_spec.rb:729-753`. Minor: budget check happens AFTER the file is fully buffered into memory via `read_file_data` — controller-level upload cap (100 MB) should still apply.

3. **render_toast XSS surface — CLEAN.** `arrayToMessage` uses `this.$createElement('div', messageArray.map(m => this.$createElement('p', message)))`. Vue's `createElement(tag, children: string)` treats string children as text nodes (auto-escaped). No `v-html`, no `domProps.innerHTML` in the toast path. Even injected `<script>` would render as text inside a `<p>`.

4. **Audit trail integrity (request_uuid) — partial improvement, not a forensic anchor.** Set inside Rails callback chain, never read from params → not spoofable via request payload. Cross-request correlation is only as strong as the sweeper's per-request UUID generation (`SecureRandom`). Treat `request_uuid` as a clustering hint, not a tamper-evident anchor.

5. **New endpoints — gates verified.**

| Endpoint | Filter chain | Status |
|---|---|---|
| `move_to_rule` | `set_review` → `set_project_from_review` → `authorize_admin_project` (line 24) → `require_audit_comment` | OK |
| `admin_destroy` | same as above | OK |
| `admin_withdraw` / `admin_restore` | same; intentionally NOT subject to `reject_if_frozen_for_writes` (admin override is the point) | OK by design |
| `withdraw` / `update` | `authorize_viewer_project` (line 17) + `authorize_review_owner` (line 21, requires `@review.user_id == current_user.id`) | OK |

**Removed-user policy enforced:** `withdraw`/`update` runs `authorize_viewer_project` BEFORE `authorize_review_owner`. A user removed from project fails `can_view_project?`, raising `NotAuthorizedError` with HTTP 403. Confirmed by `spec/requests/reviews_spec.rb:639-650` (withdraw) and `:711-720` (update).

6. **Migration safety surface (one-liners):**
   - `20260502080000` — DROP+ADD FK with validate: false then validate_foreign_key; brief ACCESS EXCLUSIVE during DROP/ADD (not concurrent). Acceptable for self-FK on small-medium table. → Filed as F3 for split.
   - `20260502120000` — `change_column_null` requires ACCESS EXCLUSIVE; `update_all` SQL backfill skips audited callbacks (intentional). Safe at v2.x scale; on 100M rows would need chunked-backfill rewrite.
   - `20260502130000` — `change_table bulk: true` for two `string` adds. Single ALTER, fast.
   - `20260502140000` + `_140001` — Strong Migrations 2-pass canonical pattern with `disable_ddl_transaction!` on validate. Safe.
   - `20260502150000` + `_150001` — same pattern, on_delete: :restrict (correct per `vulcan-cascade-rails-owns` memory).
   - `20260502160000` — re-validates 3 existing FKs; idempotent. Safe.
   - `20260502170000` — `algorithm: :concurrently` + `if_not_exists: true`. Production-safe.

### Ranked findings

1. **None blocking.** Defense-in-depth holds.
2. **Doc/clarity nit:** add a one-line comment at `reviews_controller.rb:17` explaining safe-because-of-per-action-validator.
3. **Operational note:** `request_uuid` is reliably populated but remains a clustering hint, not a tamper-proof forensic anchor.
4. **Forward-looking:** when ActiveJob lands, wire `around_perform { Audited.store[:current_request_uuid] = SecureRandom.uuid; ...; Audited.store.delete(:current_request_uuid) }`. Tracked.

---

## Agent 3 — Test coverage / TDD discipline

**Summary table**

| Category | Count | Verdict |
|---|---|---|
| (A) Behavior — would fail on real regression | ~140+ | Strong |
| (B) Implementation — could pass with broken behavior | 5 | See below |
| (C) Defensive guard / regression-only | ~8 | Acceptable |

### (B) Implementation tests — would PASS with broken behavior

#### B-1: `lock!` mock-call check at `spec/requests/reviews_spec.rb:1159-1165` and `:1373-1379`

```ruby
expect_any_instance_of(Review).to receive(:lock!).at_least(:once).and_call_original
```

Tests the *method is called*, not the *locking semantics*. An implementation that calls `lock!` outside a transaction would still pass (no-op on Postgres). The race scenario is documented but not tested. Real test would `Thread.new` two destructively-overlapping requests and assert the second waits. **Severity: medium-low.**

#### B-2: Transaction-rollback via `allow(...).and_raise` at `spec/services/import/json_archive/review_builder_spec.rb:181-202`

Stubs an internal method to raise. Tests the outer-txn-exists fact (fine), but depends on `relink_threaded_refs` being a method (rename → test breaks for non-behavioral reason). A behavior-shaped version would feed in data that *naturally* causes pass-2 to fail. **Severity: low.** Future-proofing.

#### B-3: `.20` `author_email` omit/include at `spec/blueprints/review_membership_blueprints_spec.rb:202-220`

Tests blueprint API surface, not the requirement. Actual requirement: "operator viewing triage page sees emails; public-comment-window endpoints don't expose them." Blueprint test alone passes if every controller forgets to pass `include_email: true`. Needs paired request spec asserting `/components/:id/comments` returns `author_email` for an author and the public endpoint does not. **Severity: medium.** → Filed as F5.

#### B-4: `.14r` `Audited.store[:current_request_uuid]` direct poke at `spec/lib/vulcan_audit_spec.rb:80-91`

Tests the callback's local logic. Does NOT test that any *non-HTTP code path* (Sidekiq, rake task, after-commit hook) actually populates that key before audits are created. The bug shape from the docstring is not reproduced. **Severity: medium.** → Filed as F6.

#### B-5: `.17` EXPLAIN-plan tautology at `spec/models/components_spec.rb:1039-1065`

```ruby
plan = ActiveRecord::Base.connection.execute(sql).map { |r| r['QUERY PLAN'] }.join("\n")
expect(plan).to be_a(String)
expect(plan).not_to be_empty
```

**Does literally nothing** — `execute` always returns a string-rendering result, so `be_a(String)` and `not_to be_empty` always hold. Concrete improvement: delete `'planner uses the partial index...'` outright; the index-existence test at `:1024-1037` is the load-bearing one. **Severity: medium.** → Filed as F4.

### (C) Defensive / regression-only — acceptable

FK metadata specs (existence / to_table / on_delete / validated), `commenter_imported_*` columns existence, FK :restrict guard, `.19` canonical destroy shape, `.18` create toast object shape — all lock in contracts that other behavioral tests transitively exercise.

### The "snapshot" test you asked about

`spec/requests/reviews_spec.rb:1171-1206` (`destroyed_review_snapshots`) is **type-(A) behavior** — asserts content recovery, relationship recovery, attribution recovery, ISO8601 string timestamps. Combined with `spec/models/reviews_spec.rb:733-779` (snapshot_attributes unit tests), the snapshot is well-tested as a recovery contract.

### No tests found that lock in *buggy* behavior (Outlook anti-pattern)

The biggest active hole is **B-3** — the blueprint test passes whether or not any controller actually exposes `author_email`.

---

## Agent 4 — Migration + DB safety

**Verdict: SAFE for production with one caveat.**

EXPLAIN ANALYZE on dev DB at 100k synthetic rows: planner picks `idx_reviews_top_level_triage_recent` via `Index Scan Backward` (DESC satisfied by index, no sort, 0.092 ms total). At 5k rows planner picks broader btree (correct).

### Per-migration assessment

| Migration | Production-safe? | Notes |
|---|---|---|
| `20260502120000` make_review_triage_status_nullable | YES with caveat | Metadata-only DDL; backfill UPDATE — see below |
| `20260502130000` add_commenter_imported_attribution_to_reviews | YES | PG ≥ 11 metadata-only column add; `bulk: true` collapses to one ALTER |
| `20260502140000` add_review_user_id_foreign_key | YES | Canonical 2-pass; validate: false ⇒ NOT VALID |
| `20260502140001` validate_review_user_id_foreign_key | YES | disable_ddl_transaction! + validate (ShareUpdateExclusive only) |
| `20260502150000` add_review_rule_id_foreign_key | YES | Same pattern, on_delete: :restrict (correct) |
| `20260502150001` validate_review_rule_id_foreign_key | YES | Orphan DELETE — see below |
| `20260502160000` validate_lifecycle_review_foreign_keys | YES | Idempotent (PG no-op on already-VALID) |
| `20260502170000` add_top_level_triage_partial_index | YES | concurrently + disable_ddl_transaction! + if_not_exists |

### Backfill safety

- **20260502120000**: unbatched UPDATE. Safe at small/medium scale (~100k rows = single UPDATE in seconds). On millions: PG holds row locks for entire UPDATE → blocks concurrent updaters; long-running UPDATE bloats table; one big WAL spike. **Recommendation: batch in chunks of 10k via `update_all` with `where(id: chunk)` if reviews table is expected to exceed ~500k rows.** Current Vulcan deployments nowhere near; flag for future.
- **20260502140001**: orphan user_id NULLify, NOT EXISTS. Same scaling concern. PG plans as hash anti-join, fast even at scale, but row locks per-orphan. In practice orphan count should be 0–dozens; safe.
- **20260502150001**: orphan reviews DELETE. Should be ~0 because existing destroy chain (Project→Component→Rule→Review) deletes children-first. Defensive. If ever returns >100k rows, batch it.

### Partial index correctness

Verified by EXPLAIN ANALYZE on dev DB at 100k synthetic rows on one rule:

```
Index Scan Backward using idx_reviews_top_level_triage_recent on reviews
  Index Cond: ((triage_status)::text = 'pending'::text)
  → returns 25 rows in 0.042 ms, total query 0.092 ms
```

Backward scan = DESC order satisfied by index, no sort step. Confirmed used.

### In-place edit of `20260429145530` — safe across both environments

- **Fresh deploy**: edited migration runs (FKs added with validate: false), then `20260502160000` validates. Same end state.
- **Deployed dev/test DB**: edited migration recorded as applied; `20260502160000` runs `validate_foreign_key` against already-VALID FKs → PG no-op.

Edit is safe because branch hasn't merged to master yet — no production system has the original shape recorded.

### FK ordering hazards (`reviews.rule_id` → `base_rules` ON DELETE RESTRICT)

All base_rule destroy paths walk children-first (verified):

- `app/controllers/components_controller.rb:146-153` — explicit bulk `Review.where(rule_id:).delete_all` before `Rule.unscoped.where(id:).delete_all`
- `app/models/component.rb:62` `has_many :rules, dependent: :destroy` + `app/models/rule.rb:82` `has_many :reviews, dependent: :destroy` — Rails AR cascade
- `app/models/project.rb:16` `has_many :components, dependent: :destroy` — full chain
- `app/models/component.rb:326, 363` — single Rule destroys + full component destroy
- No code path issues raw `DELETE FROM base_rules`

The :restrict FK is satisfied by every existing deleter. Cascade-ownership lesson holds.

### Schema dump consistency

`db/schema.rb:402-407`: all 6 reviews FKs present with correct `on_delete:` semantics. Schema version `2026_05_02_170000` matches latest migration. PG schema dump does NOT serialize VALID/NOT VALID state of FKs; both fresh-deploy and existing-deploy paths converge.

### One follow-up worth filing

`20260502080000_change_review_responding_to_fk_to_restrict.rb:29` runs `validate_foreign_key` in-transaction without `disable_ddl_transaction!`. Inconsistent with the 2-pass pattern this PR otherwise enforces. → Filed as F3 / `vulcan-v3.x-kea`.

---

## Agent 5 — Audit / forensic compliance

**Verdict: PARTIAL PASS — 5 of 6 scenarios fully reconstructible. 1 scenario incomplete.**

### Per-scenario assessment

#### Scenario 1 — Hard-delete parent + 3 replies — PASS

`reviews_controller.rb:367-410` writes Component-level audit BEFORE `@review.destroy!` with `action='admin_destroy_review'`, `user: current_user`, ISO-8601 `created_at`, and `audited_changes.destroyed_review_snapshots = Review.subtree_with_ancestry(id).map(&:snapshot_attributes)`. `SNAPSHOT_COLUMNS` (review.rb:223-232) captures `comment` text, `commenter_imported_email/name`, imported_* triager/adjudicator columns. **Investigator gets**: who, when, why (audit_comment), original content (snapshots), commenter identity (preserved on snapshot row).

#### Scenario 2 — Move subtree from rule A → rule B — PASS

`reviews_controller.rb:336-356` writes outbound `action='review_moved_out'` audit on **source rule** with `audited_changes={review_id, source_rule_id, destination_rule_id, reply_count}`. The recursive `move_review_subtree!` (605-611) sets `review.audit_comment` per row before `update!(rule_id: target)` → each child Review's audit captures `rule_id: [A, B]` diff. **Investigator gets**: complete picture from rule A's audit feed alone.

#### Scenario 3 — `User.find(N).destroy` from console — PASS

`User#preserve_review_attribution` (user.rb:65-78) is `before_destroy :preserve_review_attribution, prepend: true` → runs BEFORE `dependent: :nullify`. `update_all` copies `email + name` into `commenter_imported_email/name` on all reviews. The User row itself is `vulcan_audited` and emits a destroy audit with `audited_user`/`audited_username` set by `find_and_save_audited_user`. **Investigator gets**: per-review attribution preserved + single User#destroy audit naming who deleted whom.

**Caveat (not a gap):** console destroys have no `current_user` → User-destroy audit row carries `user_id=nil, username=nil`. Destroyed user's identity captured (`audited_user_id`); destroyer is not. Intrinsic to console operations.

#### Scenario 4 — Imported archive with unresolved triager — PASS

`ReviewBuilder#attribution_attrs` (review_builder.rb:151-166) writes `triage_set_by_imported_email/name` when User doesn't resolve. `write_import_audit` (168-191) writes Component-level `action='import_reviews'` with `archive_vulcan_version`, `archive_exported_at`, surviving `review_external_ids`. Display fallback (`triager_display_name` from `ImportedAttribution`). **Investigator gets**: per-review original triager identity + provenance (which archive, when exported).

#### Scenario 5 — Comment → triage 'concur' → admin force-withdraw — PASS WITH CAVEAT

Three audit rows: (a) Review create, (b) update with `triage_status: ['pending','concur']` (no audit_comment because triage controller doesn't require one), (c) admin_withdraw update with `triage_status: ['concur','withdrawn']` plus `audit_comment="Admin force-withdraw: <reason>"`. With `.14r`, all three rows have populated `request_uuid` — distinct UUIDs because three different HTTP requests. **Investigator gets**: full lifecycle by ordering `Rule#audits` by `created_at`. `request_uuid` correlates **within** the admin force-withdraw operation, not across the three operator events — semantically correct.

**Caveat / minor gap:** triage and adjudicate controllers don't require audit_comment (only admin overrides + section). State diff is captured (sufficient for "what happened"), but no human-supplied "why" for routine triage decisions. → Filed as F2.

#### Scenario 6 — `stig_and_srg_puller:pull` 1000 audit rows — FAIL

`.14r` callback reads `Audited.store[:current_request_uuid]` first. Rake task at `lib/tasks/stig_and_srg_puller.rake` **never sets** it → every audit row falls through to `SecureRandom.uuid` → 1000 distinct UUIDs. The 1000 rows cannot be queried as one logical operation.

**Missing piece**: rake task needs to wrap body in `Audited.store[:current_request_uuid] = SecureRandom.uuid` (with `ensure` to clear). Same fix needed for any other long-running batch — `db:seed`, `JsonArchiveImporter`, `admin:bootstrap`. **The .14r infrastructure is correct but inert without callers that opt in.** → Filed as F1.

### Ranked gaps

1. **`stig_and_srg_puller.rake` doesn't set `Audited.store[:current_request_uuid]`** — F1.
2. **`triage` + `adjudicate` controllers don't require audit_comment** — F2 (policy decision).
3. **Console-driven `User#destroy` cannot record the destroyer** — intrinsic limitation, mitigation = organizational policy.

---

## Agent 6 — Maintainability / standards

**Verdict: Ship it, with three minor follow-ups.**

The session's work is mature, idiomatic Rails/Ruby/Vue 2, and substantially more maintainable than what it replaced. Macros (`ImportedAttribution`, `ImportedAttributionFields`, `record_invalid_titles`) are the right call — collapsed six hand-written method bodies + ~10 hand-written rescue blocks into single declarations. Migration set is textbook Strong Migrations. Test coverage is dense and requirement-anchored.

### Ranked findings

#### High-signal — worth addressing soon

**1. `record_invalid_titles` ancestor walk non-idiomatic — use `class_attribute`.** `app/controllers/application_controller.rb:88-100`. The hand-rolled `class << self ... superclass.respond_to?(:record_invalid_title_for) ? superclass... : 'Could not save.'` reimplements what `class_attribute :record_invalid_titles_map, default: {}.freeze` gives for free, with proper STI/inheritance, no `respond_to?` probing, Rails-native thread-safety. → **ACTED ON** in `906941d`.

**2. `app/blueprints/imported_attribution_fields.rb` is at top level, not under `concerns/`.** Doc comment at `app/blueprints/review_blueprint.rb:44-46` references "app/blueprints/concerns/imported_attribution_fields.rb" — a path that doesn't exist. → **ACTED ON** in `906941d` (doc fixed).

**3. `js_const_keys` regex parser in `spec/locales/triage_keys_spec.rb:65-70` brittle long-term.** Breaks if (a) `Object.freeze` removed, (b) `as const` (TS), (c) nested objects with `}`, (d) Prettier reformat. Lower-cost alternative: emit JS constants to a JSON file at build time. → Filed as F12.

#### Medium-signal — fine but worth knowing

**4. `User#preserve_review_attribution` with `prepend: true` correct but subtle.** Comment at lines 55-62 is excellent. Future maintainer will understand. Make sure the comment never gets removed.

**5. `Audited.store[:current_request_uuid] || SecureRandom.uuid` chain idiomatic.** Cannot be simpler without losing the three-tier semantic.

**6. `spec/lib/vulcan_audit_spec.rb` cleanup adequate but vulnerable to leaked state across files.** Recommendation: add `RSpec.configure` hook in `rails_helper.rb` doing `config.after { Audited.store.clear }` globally. → Filed as F13.

**7. `ComponentComments.updateRowInPlace` uses `splice` correctly for Vue 2.** `splice(idx, 1, { ...this.rows[idx], ...updatedReview })` is canonical Vue 2 reactivity-on-array-index. Defensive fallback to `fetch()` correct. Clean.

#### Low-signal — observations only

**8. AlertMixin string-handling removal left no dead state or imports.** Lodash still needed for `_.isPlainObject`/`_.isArray`; `arrayToMessage` still used. Test in `spec/javascript/mixins/AlertMixin.spec.js:50-56` documents removal and explains new contract. Clean.

**9. `attribution-commenter` testid + `b-badge` "imported" pattern matches existing `attribution-triaged` + `attribution-adjudicated` exactly.** DRY would say "extract `<RoleAttributionLine>` component" but differences (commenter has email + posted-time, others have relativeTime only) make extraction lossy. Acceptable as 3 near-identical blocks in one file.

**10. Migration files have detailed inline comments with PR references — keep them.** Migrations are forensic primary sources. Worth every byte.

**11. `Settings.import.json_archive_size_budget_mb` follows existing convention exactly.**

**12. `vulcan_audited` concern + `VulcanAudit#ensure_request_uuid` interaction correct.** Different layers, no conflict.

#### RuboCop check

**13. New code passes RuboCop without leaning on `.rubocop.yml` allowances except for two well-justified `Rails/SkipsModelValidations` inline disables** (`app/models/user.rb:66`, `app/services/import/json_archive/review_builder.rb:94, 240`). Each has inline comment explaining the bypass. The `:command 0ba4bc3` ("silence Rails/Pluck + Rails/SquishedSQLHeredocs in .17 spec") is the only file-level suppression — normal for spec files containing raw SQL.

#### Patterns future code might break

**14. "Every JSON mutation endpoint returns canonical `{toast: {...}}` shape" assumption is now load-bearing for AlertMixin.** Removing string branch means future controller returning `render json: { toast: 'string' }` will silently fail. Consider a request-spec linter or shared example: `it_behaves_like 'a canonical toast response'`. Cheap insurance. → Filed as F10 / `vulcan-v3.x-a5u`.

**15. `belongs_to :user, optional: true` on Review is contract change for any code that previously assumed `review.user` is present.** `app/models/review.rb:19`. Session correctly updated blueprint (`review.user&.name`) and modal (`commenter_display_name` fallback). Worth grepping `review.user.` (no `&.`) outside this PR — search comes up clean in this branch.

---

## Continuity for next session

When restoring context after compact, the load-bearing files are:

- This file (`docs/plans/PR717-public-comment-review/2026-05-02-agent-review-swarm.md`) — full agent reports
- `docs/plans/PR717-public-comment-review/post-merge-remediation-notes.md` — F1-F7 design notes from `.4` work + `.10` import audit + `.9` validator
- `.beads/recovery-context.md` (about to be regenerated) — session strategic state
- `.beads/recovery-prompt.md` (about to be regenerated) — quick-start commands
- bd cards: `vulcan-v3.x-kea`, `vulcan-v3.x-a5u`, `vulcan-v3.x-bpy`, `vulcan-v3.x-g77`, plus the F1 card just filed (whose ID I don't have at the time of writing — `bd ready` will show it)

Pending Aaron decision at compact time: **F1 + F3 + F10 do-now (~75 min total) vs. defer; F11 investigate-first (sonar issue list); g77 defer (feature, separate PR)**.
