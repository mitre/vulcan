# Component Sync & Merge — Design Document

**Date:** 2026-05-24
**Author:** Aaron Lippold
**Branch:** feat/comment-triage-context-panel
**Epic:** vulcan-v3.x-05f (PR #731 follow-up)
**Status:** Draft — pending review

---

## 1. Problem Statement

Vulcan instances are standalone PostgreSQL databases, but the DISA Vendor STIG
Process (V4R1) requires bidirectional data exchange between vendor and reviewer
instances. Today, Vulcan exports complete snapshots (JSON archive zips) and
imports them as new records. There is no reconciliation when both sides have
edited the same component independently.

**The gap:** When a vendor exports a component to DISA, DISA reviews it (adding
comments, triage decisions, change requests), and the vendor simultaneously
fixes issues found in QA, there is no way to merge the two divergent copies
back together. Every record in the merge represents human labor — lost data
means lost work.

### Use Cases

1. **Vendor ↔ DISA round-trip:** Vendor authors component, exports to DISA.
   DISA reviews on their instance. Both sides need to reconcile.
2. **Cross-instance migration:** Moving components between Vulcan deployments
   (dev → staging → production) with selective data carry-forward.
3. **Offline editing:** Take a component offline, fix data, merge corrections
   back into the live instance (Container SRG scenario).
4. **Multi-team collaboration:** Multiple organizations contribute to the same
   STIG across separate Vulcan instances.

---

## 2. Prior Art & Validation

Every design choice below is validated against a real-world implementation.
No novel algorithms are introduced.

### Validated Patterns

| Pattern | Source | Validation | Reference |
|---|---|---|---|
| 3-way merge for structured records | CouchDB + Neighbourhoodie | CouchDB stores revision trees; Neighbourhoodie uses JSON Patch against common ancestor for automatic resolution | [Neighbourhoodie blog](https://neighbourhood.ie/blog/2024/12/11/automatic-conflict-resolution/) |
| SRG baseline as immutable merge base | Original (stronger than CouchDB) | CouchDB's merge base is fragile (compaction deletes old revisions). SRG baseline is immutable and always available — structurally superior | CouchDB docs: replication/conflicts |
| G-Set + LWW-Register composition | Riak Map type, CRDT Survey | Textbook CRDT composition: G-Set for collection membership, LWW-Register for mutable fields per element | [Weidner CRDT Survey Part 2](https://mattweidner.com/2023/09/26/crdt-survey-2.html) |
| Natural key upsert | Salesforce Data Loader | Match on External ID, per-row status report (inserted/updated/errored) | Salesforce upsert documentation |
| Staged analysis before commit | GitLab Bulk Import, Rails dry-run | ETL pipeline with import_failures tracking; analyze outside transaction, apply inside | [GitLab Import/Export docs](https://docs.gitlab.com/ee/development/import_export.html) |
| ID remapping dictionaries | Discourse Instance Merger | `old_id → new_id` maps maintained per entity type; all FKs translated during import | [discourse_merger.rb](https://github.com/discourse/discourse/blob/main/script/bulk_import/discourse_merger.rb) |
| Config-driven per-model control | GitLab import_export.yml | YAML defines exportable columns, included/excluded attributes per model | GitLab source |
| ActiveRecord Dirty tracking for field-level diffing | Rails built-in `changes_to_save` | Captures before/after per field; no external dependency | Rails ActiveRecord::Dirty |
| Sync anchors (UUID per export) | SyncML/OMA DS protocol | Paired anchors (Last + Next) detect desynchronization; UUID sufficient for full-snapshot transfer | [SyncML spec](https://www.openmobilealliance.org/tech/affiliates/syncml/syncml_sync_protocol_v11_20020215.pdf) |
| OSCAL property-matcher for arrays | NIST oscal-deep-diff | Match array elements by property (id field), then diff matched pairs | [oscal-deep-diff](https://github.com/usnistgov/oscal-deep-diff) |

### Rejected Alternatives

| Alternative | Why Rejected |
|---|---|
| RFC 6902 (JSON Patch) | Overkill for flat-ish record structures; AR Dirty + SQL EXCEPT is more natural for Rails |
| RFC 7396 (JSON Merge Patch) | Cannot distinguish "set to null" from "delete"; arrays replaced wholesale |
| Full CRDT replication | Requires continuous connection; file-based transfer is batch by nature |
| Vector clocks | Unnecessary for full-snapshot exchange; adds complexity without benefit |
| activerecord-import gem | Rails 7+ native `upsert_all` covers the same use case without a dependency |

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Frontends (Layer 3)                                                │
│  ┌────────────────────┐  ┌────────────────────────────────────────┐│
│  │ rake sync:diff      │  │ RestoreBackupModal + MergePreview.vue ││
│  │ rake sync:apply     │  │ (per-entity diff tables, resolution   ││
│  │ rake sync:preview   │  │  controls, confirmation step)         ││
│  └─────────┬──────────┘  └───────────────────┬────────────────────┘│
│            │                                  │                     │
├────────────┴──────────────────────────────────┴─────────────────────┤
│  Orchestrator (Layer 2)                                             │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ Import::MergeOrchestrator                                       ││
│  │  - Wraps parse → analyze → present → apply pipeline             ││
│  │  - Accepts MergeStrategy config (per-entity + per-field)        ││
│  │  - Manages VulcanAudit correlation scope                        ││
│  │  - Records sync_id on component after successful merge          ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  Analysis Engine (Layer 1 — pure computation, no side effects)      │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ Import::MergeAnalyzer                                           ││
│  │  Input: archive_data (parsed zip) + existing_component          ││
│  │  Output: MergePlan (per-entity classified diff)                 ││
│  │                                                                  ││
│  │  For each entity type:                                           ││
│  │  1. Parse archive JSON (Ruby — user resolution, normalization)  ││
│  │  2. Load into PG temp staging table (bulk COPY — fast I/O)      ││
│  │  3. Diff via SQL EXCEPT + JOIN against live tables (PG set ops) ││
│  │  4. Classify conflicts in Ruby (locked fields, strategy logic)  ││
│  │  5. Return MergePlan with per-record resolution slots           ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  Application Engine (writes to DB, extends existing builders)       │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │ Import::MergeApplier                                            ││
│  │  Input: MergePlan (with resolutions filled in)                  ││
│  │  Process:                                                        ││
│  │  1. Create pre-merge snapshot (auto-export + SHA-256 checksum)  ││
│  │  2. Acquire advisory lock (with_advisory_lock gem)              ││
│  │  3. Wrap in single transaction (all-or-nothing + quarantine)    ││
│  │  4. Apply rules via INSERT ON CONFLICT (PG bulk upsert)         ││
│  │  5. Apply new reviews via ReviewBuilder (existing 2-pass)       ││
│  │  6. Apply review field updates via bulk CASE UPDATE (PG)        ││
│  │  7. Apply satisfactions via INSERT ON CONFLICT DO NOTHING (PG)  ││
│  │  8. Write operation log to merge_operations table (undo log)    ││
│  │  9. Write audit records + sync metadata on component            ││
│  │  10. Quarantine invalid records (merge_quarantine table)        ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### Why Three Layers

- **Layer 1 (MergeAnalyzer)** is pure computation. It takes data in, produces
  a diff report. No database access, no side effects. This makes it trivially
  testable, safe to re-run, and usable from both CLI and UI.

- **Layer 2 (MergeOrchestrator)** coordinates the pipeline. It owns the
  transaction boundary, the audit scope, and the sync_id lifecycle. It calls
  Layer 1 for analysis and Layer 3's applier for writes.

- **Layer 3 (MergeApplier + Frontends)** handles I/O. The applier writes to
  the database using existing builder patterns. The frontends (rake task, Vue
  modal) present the MergePlan and collect resolution decisions.

---

## 4. Entity-Level Design

### 4.1 Rules

| Aspect | Design |
|---|---|
| **Match key** | `rule_id` string (SRG requirement ID, e.g., `SV-230221`) |
| **Merge strategy** | 3-way against SRG baseline when available; 2-way with LWW fallback |
| **Diffable fields** | `DIRECT_COLUMNS` from `RuleBuilder` (status, severity, check content, fix text, vendor_comments, etc.) |
| **Conflict definition** | Both sides changed the same field to different values (relative to SRG baseline) |
| **Auto-merge** | If only one side changed a field, take that change |
| **Nested records** | disa_rule_descriptions, checks, rule_descriptions, references — treated as atomic per-rule (replaced wholesale, not field-merged) |
| **Locked fields** | If a field is locked on the target, incoming changes to that field are flagged as conflicts regardless of merge strategy |

**3-way merge logic for a single rule field:**
```
srg_value = baseline SRG rule's value for this field
ours      = local rule's current value
theirs    = incoming archive's value

if ours == theirs        → no change (identical)
if ours == srg_value     → we didn't change it; take theirs (auto-merge)
if theirs == srg_value   → they didn't change it; keep ours (auto-merge)
if ours != theirs        → CONFLICT (both changed from baseline)
```

**When no SRG baseline exists** (rule was added manually, or SRG not loaded):
fall back to 2-way diff with `updated_at` LWW + `source_instance_id` tiebreaker.

### 4.2 Reviews

| Aspect | Design |
|---|---|
| **Match key** | `(rule_id, created_at, comment_hash)` — see §5 for rationale |
| **New reviews** | G-Set semantics: append all reviews from "theirs" not matched in "ours" |
| **Matched reviews** | Per-field LWW for mutable fields: `triage_status`, `user_email`, `adjudicated_by`, `triage_set_by`, `section` |
| **LWW tiebreaker** | `(updated_at, source_instance_id)` — if timestamps equal, the source specified in merge strategy wins |
| **Comment text** | Immutable after creation. If `comment` text differs on a matched pair, it is a match-key failure, not a merge conflict. Treated as two different reviews. |
| **Threading** | `responding_to_external_id` remapped using the same external_id → new_id dictionary pattern from existing `ReviewBuilder` |
| **Duplicate cross-links** | `duplicate_of_external_id` remapped identically |
| **Attribution** | Uses existing `ImportedAttribution` pattern: resolve by email, fall back to `imported_email`/`imported_name` columns |

**Why reviews are append-mostly:** A review represents a human's comment at a
point in time. The comment text is immutable (edits create new audit records,
not modified text). The mutable fields (triage_status, attribution FKs) are
lifecycle metadata applied after the comment was posted. This maps to G-Set
(the comment set only grows) + LWW-Register (lifecycle fields update in place).

### 4.3 Satisfactions

| Aspect | Design |
|---|---|
| **Match key** | `(rule_id, satisfied_by_rule_id)` — both as rule_id strings |
| **Merge strategy** | Set union (idempotent) |
| **Conflict** | None possible — a satisfaction either exists or doesn't |
| **Deletion** | If a satisfaction exists in ours but not theirs, it is kept (union, not intersection). Explicit removal requires a separate operation. |

### 4.4 Component Metadata

| Aspect | Design |
|---|---|
| **Match key** | `name` (component name within project) |
| **Merge strategy** | Per-field choose-side with defaults |
| **Auto-merge fields** | `comment_phase`, `closed_reason`, `comment_period_starts_at`, `comment_period_ends_at` — take theirs (DISA controls the review lifecycle) |
| **Conflict fields** | `title`, `description`, `admin_name`, `admin_email`, `version`, `release` — present for human resolution |
| **Immutable fields** | `name`, `prefix`, `based_on` (SRG reference) — must match for merge to proceed |

### 4.5 Memberships

| Aspect | Design |
|---|---|
| **Match key** | `email` (user email) |
| **Merge strategy** | Receiving instance is authoritative for access control. Existing members: SKIP (their role on your instance is your decision, not the sender's). New members: add at lowest role (viewer) if user exists locally; skip with warning if user not found. |
| **New members** | Add at viewer role if user exists on this instance (admin upgrades manually); skip with warning + preserve `imported_email` attribution if user not found |
| **Existing members** | SKIP entirely — incoming archive cannot change roles on the receiving instance (security C1) |

### 4.6 Users (Cross-Instance Identity)

User identity resolution follows the existing `ReviewBuilder#resolve_user`
pattern, extended from the GitLab placeholder model:

1. Look up by `email` (case-insensitive)
2. If found → set FK to local user
3. If not found → preserve `imported_email` + `imported_name` on the record
4. Display layer falls back to `imported_*` columns via `ImportedAttribution`
5. No automatic user creation — admin can create users separately and re-run
   merge to resolve placeholders

---

## 5. Match Key Design

### Why (rule_id, created_at) Alone Is Insufficient for Reviews

**Evidence:** CockroachDB issue #40869 documents that `NOW()` within a
PostgreSQL transaction produces identical timestamps for all rows. Bulk-imported
reviews in one request share the same `created_at`. Two reviews on the same
rule created in the same request are indistinguishable by `(rule_id, created_at)`.

**Solution:** Add a content discriminator. The composite match key is:

```
(rule_id, created_at_iso8601, comment_digest)
```

Where `comment_digest` is `Digest::SHA256.hexdigest(comment.to_s)[0..15]`
(first 16 hex chars of the SHA-256 of the comment text). This is:

- **Collision-resistant:** Two different comments produce different digests.
- **Deterministic:** Same comment text always produces the same digest.
- **Immune to timestamp collisions:** Even if `created_at` matches, different
  comment text differentiates the reviews.
- **Stable across instances:** The digest is computed from the comment content,
  which is identical on both sides for the same review.

### ISO 8601 Precision

The export serializer (`BackupSerializer#serialize_review`) uses
`created_at.iso8601`. Ruby's `Time#iso8601` defaults to second precision.
For match-key safety, use `iso8601(6)` for microsecond precision:

```ruby
created_at: review.created_at&.iso8601(6)
```

This matches PostgreSQL's native microsecond precision and prevents
truncation-induced false matches.

### Match Key Summary

| Entity | Match Key | Discriminator | Precision |
|---|---|---|---|
| Rules | `rule_id` | N/A (unique per component) | Exact string |
| Reviews | `(rule_id, created_at, comment_digest)` | SHA-256 of comment text | ISO 8601 with µs |
| Satisfactions | `(rule_id, satisfied_by_rule_id)` | N/A (unique pair) | Exact string |
| Component | `name` | N/A (unique per project) | Exact string |
| Memberships | `email` | N/A (unique per project) | Case-insensitive |

---

## 6. Merge Strategies

A `MergeStrategy` is a configuration object that controls how each entity type
and field is resolved. It is passed to the MergeOrchestrator and can be
constructed from CLI flags or UI selections.

### Strategy Types

| Strategy | Semantics | Use Case |
|---|---|---|
| `ours` | Keep local value, discard incoming | Vendor preserving their rule edits |
| `theirs` | Take incoming value, discard local | Accepting DISA's review decisions |
| `newer` | LWW by `(updated_at, source_id)` | Default for most mutable fields |
| `conflict` | Require human resolution | Fields where both sides changed |
| `union` | Keep both (for collections) | Satisfactions, new reviews |
| `skip` | Do not merge this entity/field | Excluding specific data from merge |

### Default Strategy

```ruby
DEFAULT_MERGE_STRATEGY = {
  rules: {
    default: :three_way,  # 3-way against SRG baseline
    fallback: :conflict,  # DECISION: always ask on conflicts (both sides' edits are high-value human labor)
    locked_fields: :conflict  # always require human resolution
  },
  reviews: {
    new_reviews: :union,         # import all new from theirs
    triage_status: :ours,        # our triage decisions win by default
    user_email: :theirs,         # their attribution wins (they have real emails)
    adjudicated_by: :theirs,
    triage_set_by: :theirs
  },
  satisfactions: {
    default: :union
  },
  component: {
    comment_phase: :theirs,
    title: :conflict,
    version: :conflict,
    release: :conflict
  },
  memberships: {
    existing_members: :skip,         # receiving instance owns access control
    new_members: :add_as_viewer,     # add at lowest role, admin upgrades manually
    unknown_users: :skip_with_warning  # preserve imported_email attribution only
  }
}.freeze
```

### CLI Flag Mapping

```bash
# Dry-run: show diff only
rake sync:diff OURS=/path/to/local/backup.zip THEIRS=/path/to/incoming/backup.zip

# Apply with defaults
rake sync:apply OURS=/path/to/local/backup.zip THEIRS=/path/to/incoming/backup.zip

# Override per-field
rake sync:apply ... REVIEW_STATUS=theirs REVIEW_EMAIL=ours RULES=theirs
```

---

## 7. Failure Modes & Mitigations

Every failure mode is addressed structurally, not by convention.

### 7.1 Silent Data Loss

**Risk:** A review exists on one side but is not included in the merge output.

**Mitigation:** The MergeAnalyzer partitions ALL records into exactly one of
three buckets: `matched`, `only_ours`, `only_theirs`. The sum of all three
buckets must equal the union of both input sets. A post-analysis invariant
check verifies:

```ruby
assert_equal(
  ours_count + theirs_count - matched_count,
  plan.matched.size + plan.only_ours.size + plan.only_theirs.size
)
```

If this fails, the merge is aborted with a diagnostic error. No silent drops.

### 7.2 Silent Corruption (Wrong Side Wins)

**Risk:** Triage status from the wrong side overwrites the correct value.

**Mitigation:** The MergePlan records the resolution source for every field
change: `{ field: :triage_status, value: 'addressed_by', source: :ours,
reason: 'strategy default' }`. The MergePreview UI and rake output both
display this attribution. The audit record for the merge includes the full
resolution log. Post-merge, every changed field is traceable to its source.

### 7.3 Identity Mangling

**Risk:** A comment attributed to the wrong reviewer.

**Mitigation:** Attribution is NEVER auto-merged. The existing
`ImportedAttribution` concern preserves the original email/name from the
archive in dedicated columns (`imported_email`, `imported_name`). User FK
resolution is a separate, explicit step. Display layers fall back to
`imported_*` columns when the FK is nil. The merge does not create, modify,
or delete User records.

### 7.4 Threading Breakage

**Risk:** A reply points to the wrong parent after merge.

**Mitigation:** Threading is preserved by the existing `ReviewBuilder`
two-pass algorithm: pass 1 inserts all reviews and builds
`external_id → new_id` map; pass 2 patches `responding_to_review_id` using
the map. For matched reviews (already in DB), the `external_id → existing_id`
map is built from the match-key index. New reviews from "theirs" go through
the standard two-pass. The map is verified: every `responding_to_external_id`
in the incoming data must resolve to either an existing matched review or a
newly-imported review. Unresolvable references are logged as warnings (not
silently dropped).

### 7.5 Idempotency Failure

**Risk:** Running the merge twice creates duplicate records.

**Mitigation:** The match-key index prevents duplicate insertion. A review
that was already imported in a previous merge will match on
`(rule_id, created_at, comment_digest)` and be classified as `matched`, not
`only_theirs`. The sync_id recorded on the component after merge provides
an additional idempotency guard: re-importing the same archive (same sync_id)
is detected and can be skipped or flagged.

### 7.6 SRG Version Mismatch

**Risk:** Vendor upgrades SRG to V2R2 while DISA is still on V2R1. The 3-way
merge base (SRG baseline) differs between sides.

**Mitigation:** The MergeAnalyzer checks `based_on.srg_id` and
`based_on.version` as a precondition. If they differ, the merge is blocked
with a diagnostic: "SRG version mismatch: ours=V2R1, theirs=V2R2. Align SRG
versions before merging." SRG migration is a separate operation
(`Component#duplicate` with `new_srg_id`) that must happen before merge.

### 7.7 Partial Failure During Apply

**Risk:** Some records merge successfully, then a later record fails, leaving
the database in an inconsistent state.

**Mitigation:** The apply phase uses quarantine mode: valid records are
applied inside a serializable transaction, invalid records are written to
the `merge_quarantine` table with diagnostics. The transaction commits
with the valid subset. The admin reviews quarantined records, fixes the
underlying issue, and retries via `rake sync:retry_quarantined`. For
strict mode (all-or-nothing), the entire transaction rolls back on any
failure. The MergePlan is unchanged by the apply attempt, so it can be
re-applied after fixing the issue.

### 7.8 Timestamp Precision Loss

**Risk:** ISO 8601 serialization truncates microseconds, causing false
match-key collisions.

**Mitigation:** The export serializer uses `iso8601(6)` for all timestamps.
The match-key comparison uses string equality on the full ISO 8601 string.
A manifest version bump (1.0 → 1.1) signals that timestamps use microsecond
precision. Legacy 1.0 manifests (second precision) use the `comment_digest`
discriminator more heavily.

---

## 8. Manifest Extension

### Current (v1.0)

```json
{
  "backup_format_version": "1.0",
  "vulcan_version": "2.3.7",
  "exported_at": "2026-05-24T10:00:00Z",
  "components": [...]
}
```

### Extended (v1.1)

```json
{
  "backup_format_version": "1.1",
  "vulcan_version": "2.3.8",
  "exported_at": "2026-05-24T10:00:00.123456Z",
  "sync_id": "550e8400-e29b-41d4-a716-446655440000",
  "parent_sync_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "source_instance_id": "vendor-vulcan.example.com",
  "components": [
    {
      "name": "Container SRG",
      "prefix": "CNTR",
      "version": 2,
      "release": 4,
      "srg_id": "SRG-APP-000001",
      "srg_title": "Application SRG",
      "srg_version": "V3R4",
      "rule_count": 245,
      "review_count": 207,
      "last_sync_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    }
  ]
}
```

### New Fields

| Field | Type | Purpose |
|---|---|---|
| `sync_id` | UUID | Unique identifier for this export. Recorded on target after import. Enables idempotency detection. |
| `parent_sync_id` | UUID or null | The `sync_id` of the last import this instance received. Enables 3-way merge by identifying the common ancestor point. |
| `source_instance_id` | String | Hostname or identifier of the exporting instance. Used as LWW tiebreaker. |
| `review_count` | Integer | Per-component review count for preview display. |
| `last_sync_id` | UUID or null | Per-component: the sync_id of the last merge applied to this component. |

### Backward Compatibility

- v1.0 archives (no sync fields) import via the existing pipeline unchanged.
- Merge mode requires v1.1 or later. Attempting to merge a v1.0 archive
  falls back to 2-way diff with LWW (no 3-way merge base available).
- The format version check in `ManifestValidator::SUPPORTED_VERSIONS` is
  extended to include `'1.1'`.

---

## 9. Database Changes

### New Column on Component

```ruby
# db/migrate/YYYYMMDD_add_sync_metadata_to_components.rb
add_column :components, :last_sync_id, :uuid, null: true
add_column :components, :last_sync_at, :datetime, null: true
add_column :components, :last_sync_source, :string, null: true
```

No index needed on sync columns — these are metadata read only during merge analysis.

### Composite Index for Review Matching (MUST FIX — data integrity review)

```ruby
# db/migrate/YYYYMMDD_add_review_merge_index.rb
add_index :reviews, [:rule_id, :created_at],
          name: 'index_reviews_on_rule_id_and_created_at'
```

Without this index, match-key lookup is O(N*M) for large components.

### Concurrency Protection

The MergeOrchestrator uses serializable transaction isolation (§19.2) as the
primary concurrency mechanism. This prevents both concurrent merges AND
concurrent UI edits — PostgreSQL raises `SerializationFailure` if another
transaction modified the same data, which the merge catches and reports.

```ruby
ActiveRecord::Base.transaction(isolation: :serializable) do
  # All merge reads + writes are serializable.
  # Concurrent edits cause ActiveRecord::SerializationFailure.
  merge_component(...)
rescue ActiveRecord::SerializationFailure
  raise Import::ConcurrentEditError, "Component modified during merge — retry"
end
```

Advisory lock (via `with_advisory_lock` gem) is retained only for the
pre-merge snapshot export phase to prevent concurrent snapshot writes.

### Review Match Key Support

The existing `(rule_id, created_at)` pair is already queryable. The
`comment_digest` is computed at analysis time from the `comment` column —
no new database column needed. If performance becomes an issue with very
large review sets, a generated column can be added later:

```sql
ALTER TABLE reviews ADD COLUMN comment_digest text
  GENERATED ALWAYS AS (left(encode(sha256(coalesce(comment,'')::bytea),'hex'),16)) STORED;
```

This is deferred — the in-memory computation is sufficient for merge analysis.

---

## 10. File Layout

```
app/services/import/
├── json_archive_importer.rb          # existing — extended with merge mode
├── json_archive/
│   ├── component_builder.rb          # existing
│   ├── manifest_validator.rb         # existing — extended for v1.1
│   ├── membership_builder.rb         # existing
│   ├── review_builder.rb             # existing — used by MergeApplier for new reviews
│   ├── rule_builder.rb               # existing
│   ├── satisfaction_builder.rb       # existing
│   ├── srg_importer.rb               # existing
│   └── merge/
│       ├── analyzer.rb               # NEW — pure diff engine (Layer 1)
│       ├── merge_plan.rb             # NEW — classified diff data structure
│       ├── strategy.rb               # NEW — resolution config
│       ├── applier.rb                # NEW — writes to DB (Layer 3)
│       ├── rule_field_differ.rb       # NEW — SQL EXCEPT + AR Dirty for rule field diffs
│       ├── review_matcher.rb         # NEW — (rule_id, created_at, digest) matching
│       ├── rule_three_way.rb         # NEW — 3-way merge against SRG baseline
│       ├── orchestrator.rb           # NEW — pipeline coordinator (Layer 2)
│       └── merge_result.rb           # NEW — extends Import::Result with conflict counts
├── result.rb                         # existing

lib/tasks/
└── sync.rake                         # NEW — rake sync:diff, sync:apply, sync:preview

spec/services/import/merge/
├── analyzer_spec.rb
├── merge_plan_spec.rb
├── strategy_spec.rb
├── applier_spec.rb
├── rule_field_differ_spec.rb
├── review_matcher_spec.rb
└── rule_three_way_spec.rb

spec/lib/tasks/
└── sync_spec.rb
```

---

## 11. Phasing Plan

### Phase 1: Analysis Engine + CLI (sp:8, ~60 min)

**Delivers:** `MergeAnalyzer`, `MergePlan`, `MergeStrategy`, `RuleFieldDiffer`,
`ReviewMatcher`, `RuleThreeWay`, `MergeInput`, and `rake sync:diff` / `sync:preview`.

**What it does:** Given two backup zips (or a zip + existing component),
produces a complete diff report showing matched/only-ours/only-theirs per
entity type, with per-field diffs for matched records and conflict
classification.

**What it does NOT do:** Does not write to the database. Does not modify the
import pipeline. No UI changes.

**First customer:** Container SRG — run `rake sync:diff` to verify the
118 common / 15 new / 116 email diff analysis.

### Phase 2: Apply Engine + Pipeline Integration (sp:8, ~60 min)

**Delivers:** `MergeApplier`, `MergeOrchestrator`, integration with
`import_backup` controller endpoint, sync metadata columns on Component.

**What it does:** Takes a resolved MergePlan and applies it to the database
inside a transaction. Auto-exports pre-merge snapshot before applying (§14.1).
Updates existing rules, imports new reviews, updates review fields, unions
satisfactions. Records sync_id on component. Full audit trail via VulcanAudit
correlation scope. Membership merge is opt-in (§14.3).

**Depends on:** Phase 1 (analyzer produces the MergePlan that applier consumes).

### Phase 3: Merge UI (sp:5, ~30 min)

**Delivers:** `MergePreview.vue` component, extension to `RestoreBackupModal`
with merge step, per-entity diff tables with resolution controls.

**What it does:** When a backup import hits an existing component, shows the
merge preview (from MergeAnalyzer dry-run) with entity-level and field-level
diff tables. User selects resolution strategy per conflict type. Submits
resolved MergePlan to apply endpoint.

**Depends on:** Phase 2 (controller endpoint that accepts resolved MergePlan).

### Phase 4: Manifest v1.1 + 3-Way Merge (sp:5, ~30 min)

**Delivers:** Extended manifest format, `parent_sync_id` tracking,
`source_instance_id`, 3-way rule merge using SRG baseline, microsecond
timestamp precision in exports.

**What it does:** Enables true 3-way merge for rules when both sides changed
fields from the SRG baseline. Without this phase, rule merge falls back to
2-way LWW.

**Depends on:** Phase 2 (sync_id recording infrastructure).

---

## 12. Test Strategy

### Unit Tests (per service class)

Each service in `app/services/import/merge/` has a corresponding spec file.
Tests use fixture review/rule JSON data (not database records) to exercise
the pure computation layer.

**Critical test cases:**

| Test | What It Verifies | Failure Mode Prevented |
|---|---|---|
| Matched count + only_ours + only_theirs = union | Partition invariant | Silent data loss (§7.1) |
| Resolution source recorded per field change | Audit trail completeness | Silent corruption (§7.2) |
| Attribution preserved on imported_email columns | Identity integrity | Identity mangling (§7.3) |
| responding_to remapped correctly for new reviews | Threading integrity | Threading breakage (§7.4) |
| Re-running merge produces identical result | Idempotency | Duplicate creation (§7.5) |
| SRG version mismatch blocks merge | Precondition enforcement | Merge base confusion (§7.6) |
| Transaction rollback on partial failure | Atomicity | Inconsistent state (§7.7) |
| Microsecond timestamps preserved in round-trip | Precision | False matches (§7.8) |

### Integration Tests

- Round-trip: export → modify → re-import with merge → verify all records
- Container SRG scenario: 118 common, 15 new, 116 email diffs, 92 status diffs
- Empty merge: import same archive twice → zero changes on second run
- Conflict resolution: both sides changed check_content → human picks winner

### Regression Guard

A shared example `'behaves like a merge-safe export'` that verifies:
1. All timestamps use `iso8601(6)` precision
2. All review exports include `comment` text (for digest computation)
3. Manifest includes sync metadata fields

---

## 13. Dependencies

| Dependency | Type | Status |
|---|---|---|
| `with_advisory_lock` gem | Runtime | EXISTING — used for snapshot export lock |
| `audited` gem | Runtime | EXISTING — `request_uuid` + `audit_comment` + `undo` for merge audit |
| `Import::JsonArchive::ReviewBuilder` | Internal | Existing — reused for new review imports |
| `VulcanAudit` / `VulcanAuditable` | Internal | Existing — audit trail with correlation scope |
| `ImportedAttribution` concern | Internal | Existing — cross-instance identity |
| `BackupSerializer` | Internal | Extended with sync metadata + `updated_at` + reactions |
| `ManifestValidator` | Internal | Extended to support v1.1 format |
| `SpreadsheetParser` | Internal | Existing — reused for DISA spreadsheet merge input |
| `Component#compute_rule_changes` | Internal | Existing — field-level diff pattern reused by RuleFieldDiffer |
| `Rule::MERGEABLE_FIELDS` | Internal | NEW — single source of truth for diffable fields |

**Removed dependencies:**
- ~~`hashdiff` gem~~ — replaced by Arel EXCEPT + AR Dirty + SQL column comparison (§19)
- ~~`activerecord-import` gem~~ — native `upsert_all` + `insert_all` sufficient (§19)

---

## 14. Design Decisions (Resolved)

Decided 2026-05-24 by Aaron Lippold.

### 14.1 Pre-merge snapshot: ALWAYS

The MergeApplier auto-exports the component to a zip file before applying any
changes. Stored in a configurable path (default: `tmp/merge_snapshots/`). This
provides a safety net beyond the DB transaction — if the merge completes but
the result looks wrong, the admin can restore from the snapshot without
needing to reconstruct the pre-merge state.

### 14.2 Sync ID visibility: Component Settings page

`last_sync_id`, `last_sync_at`, and `last_sync_source` are displayed on the
Component Settings page. Only admins can access component settings, so this
does not clutter the authoring/review UI. Helps debugging sync issues.

### 14.3 Membership merge: Opt-in checkbox (off by default)

Follows the existing `include_memberships` pattern from the import pipeline.
DISA's project members should not auto-import into the vendor's instance.
The user explicitly opts in via checkbox in the UI or `INCLUDE_MEMBERSHIPS=true`
on the rake task.

### 14.4 Rule content conflicts: Always ask (`:conflict` default)

Both sides' rule edits represent high-value human labor. A vendor's check text
fix and DISA's severity override are both deliberate decisions. LWW risks
silent overwriting. The merge surfaces every rule-level conflict for human
resolution. Power users can override via `RULES=theirs` or `RULES=ours` on
the CLI. Aligns with CouchDB's "accept all, surface conflicts" philosophy
and DISA's review culture (nothing auto-approved).

---

## 15. Expert Review Findings & Remediations

Four specialized review agents audited this design on 2026-05-24: Security,
Architecture/DRY, Test Strategy, and Data Integrity. All findings below are
incorporated into the card acceptance criteria.

### 15.1 Security Findings

| Severity | Finding | Remediation | Phase |
|---|---|---|---|
| CRITICAL | **Membership role escalation** — crafted archive with `role: "admin"` auto-upgrades existing viewer via "higher privilege wins" | Role upgrades from imported data require human confirmation. Classify as conflict, never auto-merge. | 2 |
| HIGH | **Unbounded memory** — MergeAnalyzer loads all reviews into memory. 500K reviews = several GB in Ruby | Add 10K per-component review ceiling for web UI. CLI has no ceiling. | 1 |
| HIGH | **Unverified email attribution** — anyone can inject arbitrary emails into `commenter_imported_email` | Display imported attribution with "(imported, unverified)" visual indicator. | 2, 3 |
| MEDIUM | **sync_id spoofing** — fake `parent_sync_id` tricks 3-way merge into wrong conflict classification | Validate `parent_sync_id` against sync history table, not just `last_sync_id` column. | 4 |
| MEDIUM | **XSS in merge preview** — comment text in MergePreview.vue | Use `{{ }}` interpolation (Vue auto-escapes), never `v-html`. Server-side sanitization in MergeApplier before insert. | 3 |
| MEDIUM | **Audit records must capture before/after per field** — not just "merge happened" | Manual audit records include field-level diffs from MergePlan. Integration test asserts every merged field change has audit entry. | 2 |
| LOW | **No rate limiting** — repeated large merges could fill disk with snapshots | Advisory lock per component. Rotate/cap snapshot directory. | 2 |

### 15.2 Architecture & DRY Findings

| Finding | Remediation | Phase |
|---|---|---|
| **`DIRECT_COLUMNS` duplication** — three lists define rule fields with no single source of truth (`RuleBuilder::DIRECT_COLUMNS`, `BackupSerializer::EXCLUDED_RULE_COLUMNS`, `MergeStrategy`) | Extract `Rule::MERGEABLE_FIELDS` constant that all consumers derive from. | 1 |
| **MergeApplier bypasses builder logic** — direct `assign_attributes + save` skips SRG resolution, nested record rebuilding, counter cache reset | Extract `RuleBuilder#update_rule` method. MergeApplier delegates to it. | 2 |
| **Strategy config permanent home** — frozen Ruby hash is fine for Phase 1 but should become `config/merge_entities.yml` for extensibility | YAML config file defining match keys, diffable fields, default strategies per entity. Ruby classes read from config. | 4 |
| **MergeOrchestrator file location** — breaks nesting (all other merge files in `json_archive/merge/`) | Move to `app/services/import/json_archive/merge/orchestrator.rb` | 1 |
| **`Import::Result` needs extension** — MergePlan needs conflict counts, resolution log | Create `MergeResult < Result` with `conflicts`, `auto_merged`, `skipped` counters and `resolution_log`. | 1 |

### 15.3 Data Integrity Findings

| Severity | Finding | Remediation | Phase |
|---|---|---|---|
| MUST FIX | **Missing composite index** — `reviews(rule_id, created_at)` needed for match-key lookup. Without it, O(N*M) for large components. | Migration: `add_index :reviews, [:rule_id, :created_at]` | 1 |
| MUST FIX | **Polymorphic dual-write gap** — targeted UPDATEs won't fire `sync_commentable_from_rule`. Any UPDATE touching `rule_id` must also update `commentable_type`/`commentable_id`. | MergeApplier must dual-write or call `repair_missing_commentable!` after all updates. | 2 |
| MUST FIX | **Counter cache not recalculated** — `rules_count` goes stale after merge | MergeApplier calls `update_columns(rules_count: ...)` after rule changes, same as RuleBuilder. | 2 |
| SHOULD FIX | **FK translation on UPDATE path** — `responding_to_review_id` and `duplicate_of_review_id` UPDATEs must go through `external_id → existing_id` remap | Explicitly spec remap for all FK updates, not just inserts. | 2 |
| SHOULD FIX | **Concurrent editing during merge** — `find + assign_attributes + save` could overwrite UI edits | `SELECT ... FOR UPDATE` on component rules before merge. Or require component lock (comment_phase=closed). | 2 |
| SHOULD FIX | **Savepoint rollback doesn't cascade** — orchestrator must explicitly `raise` after savepoint failure | Remove savepoints; use all-or-nothing transaction. Simpler and safer. | 2 |
| SHOULD FIX | **`addressed_by_rule_id` FK remapping** — reviews with `triage_status: 'addressed_by'` reference a rule FK | Map `addressed_by_rule_id` through `rule_id_string → db_id` map in MergeApplier. | 2 |

### 15.4 Test Strategy Findings

**Missing test cases (must add):**

1. Concurrent merge — two simultaneous merges on same component must not create duplicates
2. Unicode/emoji in comment text — digest must be stable across NFC/NFD normalization
3. Same-timestamp same-comment on different rules — correctly partitioned, not cross-matched
4. Same-timestamp same-comment on SAME rule — worst-case collision, need detection/error
5. Large component benchmark — 250 rules / 1000 reviews must merge in <10 seconds
6. HTML entities in comment text — `&amp;` vs `&` must produce stable digests
7. Round-trip closure — export → merge → re-export → diff should be empty for accepted fields
8. v1.0 manifest fallback — legacy archive triggers 2-way LWW, not 3-way
9. Locked field conflict override — locked field always classified `:conflict` even if only one side changed
10. Post-merge health check — rake task verifying orphaned reviews, broken threading, counter cache drift

**Match key collision (test case 4) remediation:**
When two reviews have identical `(rule_id, created_at, comment_digest)`, the match
is ambiguous. Add a sequence tiebreaker: sort by `external_id` (archive order) and
match positionally. If counts differ, classify extras as `only_ours`/`only_theirs`.
This is a degenerate case (two identical comments on the same rule at the same
microsecond) but must be handled structurally, not ignored.

**Fixture strategy:**
- Layer 1 (MergeAnalyzer): FactoryBot factories serialized to JSON. No DB.
- Layer 2/3 (Applier, Orchestrator): Real DB records via `let_it_be`. Test FK integrity, counter caches, transaction rollback.
- Container SRG golden test: synthetic fixture matching real data shape (counts, field distributions), NOT a copy of actual SRG content.

**Performance baseline:**
Add benchmark spec: 250 rules with nested records + 1000 reviews must complete
`MergeAnalyzer#analyze` in <10s on CI hardware. Flag if regression detected.

### 15.5 Design Corrections Applied

Based on the reviews, the following design changes are made:

1. **§4.5 Memberships**: Role conflict strategy changed from `:higher_privilege` to `:conflict` (require human confirmation for role changes).
2. **§5 Match Keys**: Added sequence tiebreaker for degenerate same-key collisions.
3. **§7.7 Partial Failure**: Changed from savepoints to all-or-nothing transaction.
4. **§9 Database Changes**: Added composite index migration on `reviews(rule_id, created_at)`.
5. **§10 File Layout**: `merge_orchestrator.rb` moved inside `json_archive/merge/` namespace.
6. **§13 Dependencies**: Added `Rule::MERGEABLE_FIELDS` as centralized field constant.
7. **New §9.2**: Advisory lock on component during merge to prevent concurrent conflicts.

---

## 16. Round 2 Expert Review Findings (2026-05-24)

Second review pass with 4 agents: Security re-review, Disaster Recovery,
Architecture re-review, and Chaos/Edge Case analysis.

### 16.1 Security Re-Review

| Status | Finding | Remediation | Phase |
|---|---|---|---|
| FIXED | C1 membership escalation | Verified: existing members SKIP, new at viewer only | — |
| OPEN | H1 memory ceiling still ~50-100MB | Lower to 10K ceiling; add "use CLI for larger" escape hatch | 1 |
| NEW S1 | **Snapshot data exposure** — full backup in world-readable tmp/ | Store at `Settings.sync.snapshot_path` (default `storage/merge_snapshots/`), mode 0700, auto-purge 7 days, encryption for CUI deployments | 2 |
| NEW S2 | **Advisory lock SQL interpolation** — fragile pattern | Use `with_advisory_lock` gem (already in Gemfile via User model) instead of raw SQL | 2 |
| NEW S3 | **No archive provenance** — any admin can upload any zip | Optional HMAC signature field in manifest v1.1, required before Phase 4 3-way merge | 4 |
| NEW S4 | **Replay attack** — old archive re-uploaded to revert data | Record SHA-256 of imported zip on component, reject re-imports of same hash | 2 |

### 16.2 Disaster Recovery Findings

| Severity | Finding | Remediation | Phase |
|---|---|---|---|
| MUST FIX | **Snapshot missing review `updated_at` + reactions** — restore loses LWW timestamps and all reaction data | Add `updated_at: review.updated_at&.iso8601(6)` to `serialize_review`. Add `reactions` array serialization. | Pre-1 |
| MUST FIX | **No rollback procedure** — snapshot exists but no `rake sync:rollback` | Implement `rake sync:rollback SNAPSHOT=path COMPONENT=name` that: acquires lock, deletes all entity data for the component, re-imports from snapshot, clears sync metadata | 2 |
| MUST FIX | **No snapshot checksum** — corruption discovered only at restore time | Write SHA-256 `.sha256` file alongside each snapshot. Verify after write, verify before restore. | 2 |
| SHOULD FIX | **Container ephemeral storage** — `tmp/` vanishes on restart | Configure via `Settings.sync.snapshot_path`, default `storage/merge_snapshots/` (volume-mountable). Retention: 10 per component, oldest rotated. | 2 |
| SHOULD FIX | **`component_sync_events` table needed NOW** — enables sync history, structured resolution queries, multi-merge audit trail, selective rollback | Move from Phase 4 to Phase 2. Schema: `(id, component_id, sync_id, parent_sync_id, source, direction, resolution_log_json, snapshot_path, archive_hash, created_at)` | 2 |
| SHOULD FIX | **Resolution log not queryable** — only in audit comment text | Persist in `component_sync_events.resolution_log_json` as structured JSON. | 2 |

### 16.3 Architecture Re-Review

| Status | Finding | Remediation | Phase |
|---|---|---|---|
| VERIFIED | All 7 round-1 fixes correctly reflected in design body | — | — |
| NEW | **PRE-EXISTING BUG: ReviewBuilder missing `addressed_by_rule_id`** — importing `triage_status: 'addressed_by'` reviews fails validation today | Fix ReviewBuilder#lifecycle_attrs to handle `addressed_by_rule_id` with FK remap via rule_id_map. **Must fix before Phase 1.** | Pre-1 |
| NEW | **Error messages need structured format** — flat string errors don't identify which entity/step failed | `MergeResult#add_error` captures `entity_type`, `entity_key`, `step`, `message` | 1 |
| NEW | **resolution_log must be plain Hash{String=>String}** — no Ruby symbols, Time objects, or AR references | Enforce at MergeResult construction time | 1 |
| NEW | **Locked field check in Layer 1** — eager-load component rules with `locked_fields` hash, pass to analyzer | Explicitly document that analyzer receives loaded AR objects, not lazy queries | 1 |
| NEW | **EntityDiffer → RuleFieldDiffer rename** — only serves rules (satisfactions are set ops, reviews use ReviewMatcher) | Renamed. Uses Arel EXCEPT + AR Dirty, not hashdiff (§19) | 1 |
| ~~SUPERSEDED~~ | ~~Hashdiff pin~~ | Hashdiff removed entirely — replaced by Arel EXCEPT + SQL column comparison (§19.3) | — |
| OVERALL | **Ready to implement with caveats** — fix ReviewBuilder addressed_by_rule_id first | — | — |

### 16.4 Chaos / Edge Case Findings

| Likelihood | Scenario | Impact | Handled? | Remediation | Phase |
|---|---|---|---|---|---|
| **Common** | **Concurrent UI edit during merge** — advisory lock blocks merges, NOT normal UI writes | Data loss — user's edit silently overwritten | NO | Require `comment_phase=closed` during merge as precondition. MergeAnalyzer checks and blocks if open. | 1 |
| **Common** | **All-or-nothing rolls back valid imports** — 1 bad review kills 199 good ones | Loss of valid work | Handled but user-hostile | Add quarantine mode: import valid records, quarantine invalid with diagnostics, report partial success | 2 |
| **Common** | **Re-merge confusion** — second merge's "ours" is first merge's result, not original | UX confusion | Partially | Document in UI. Recovery requires snapshot restore then re-merge. | 3 |
| **Common** | **Email change between export and merge** — user changed email, no match | Phantom attribution | Not handled | Add name-based fallback after email miss (ReviewBuilder already has this, ensure MergeAnalyzer does too) | 1 |
| **Rare** | **Future-dated created_at** — year 2099 in archive | Match-key poisoning, idempotency failure | NOT handled | Add timestamp sanity bounds: reject reviews with `created_at > Time.current + 1.day` | 1 |
| **Rare** | **Circular responding_to** — A→B→A in malformed archive | Server hang (recursive CTE infinite loop) | NOT handled | Validate acyclicity in MergeAnalyzer before apply. Or add `CYCLE` clause to CTE (requires PG 14+). | 2 |
| **Rare** | **500-component archive merged** — design is single-component | Undefined behavior | NOT handled | MergeAnalyzer accepts single component name param. Multi-component merge iterates with per-component lock. | 2 |
| **Rare** | **10K reviews on one rule** — N+1 in drop_invalid_reviews | Minutes of query time | Partially | Batch `includes(:rule, :responding_to)` in drop_invalid pass | 2 |
| **Theoretical** | **Same email different people** (different LDAP dirs) | Wrong attribution | Not handled | Document risk. Future: qualify user lookup with `source_instance_id` | 4 |

### 16.5 Design Corrections Applied (Round 2)

1. **§7.7**: Changed from "all-or-nothing" to "quarantine mode" — valid records import, invalid ones quarantined with diagnostics. All-or-nothing available as strict mode flag.
2. **§9**: `component_sync_events` table moved to Phase 2 (was Phase 4). Snapshot path configurable via Settings.
3. **§10**: Added `merge_result.rb`, `sync.rake` includes `sync:rollback` and `sync:verify` tasks.
4. **§11 Phase 2**: Added rollback procedure, snapshot checksum, sync events table, quarantine mode.
5. **§12**: Added timestamp sanity bounds, cycle detection, concurrent-edit-during-merge test cases.
6. **Pre-Phase-1 prerequisite**: Fix ReviewBuilder `addressed_by_rule_id` handling.
7. **Phase 1 precondition**: MergeAnalyzer blocks merge if `comment_phase != 'closed'`.

---

## 17. Design Decisions — Round 3 (2026-05-24)

### 17.1 Quarantine: Dedicated `merge_quarantine` table

Invalid records go into a `merge_quarantine` table — same columns as
`reviews` plus `quarantine_reason`, `merge_event_id` (FK to
`component_sync_events`), and `original_archive_data` (JSONB snapshot of the
raw archive record). Admin reviews quarantined records, fixes the underlying
issue, and retries via `rake sync:retry_quarantined MERGE_EVENT=uuid`.
Records visible in merge UI as "X records quarantined — click to review."
Cleanup via `rake sync:clear_quarantine MERGE_EVENT=uuid`.

```ruby
# db/migrate/YYYYMMDD_create_merge_quarantine.rb
create_table :merge_quarantine do |t|
  t.references :component_sync_event, null: false, foreign_key: true
  t.string :entity_type, null: false    # 'review', 'rule', 'satisfaction'
  t.string :entity_key, null: false     # match key value
  t.string :quarantine_reason, null: false
  t.jsonb :original_archive_data, null: false
  t.jsonb :validation_errors
  t.timestamps
end
```

### 17.2 Scale target: 500 rules / 5000 reviews

Performance benchmark required before Phase 1 completion. MergeAnalyzer must
handle 500 rules (each with 5 nested disa_rule_descriptions, 2 checks) and
5000 reviews (mix of threaded and top-level) in <10 seconds with <200MB
memory. If Ruby in-memory approach fails this benchmark, switch to PostgreSQL
temp table staging approach (see §18).

### 17.3 Rollback: Surgical undo via operation log

Each merge writes a per-field operation log to `merge_operations` table.
Every change is recorded with before/after values, enabling surgical undo
of specific merges without affecting later merges.

```ruby
# db/migrate/YYYYMMDD_create_merge_operations.rb
create_table :merge_operations do |t|
  t.references :component_sync_event, null: false, foreign_key: true
  t.string :entity_type, null: false     # 'rule', 'review', 'satisfaction'
  t.bigint :entity_id, null: false       # DB id of the affected record
  t.string :entity_key, null: false      # natural key (rule_id or match key)
  t.string :operation, null: false       # 'insert', 'update', 'skip'
  t.string :field_name                   # null for insert/skip operations
  t.text :old_value                      # null for inserts
  t.text :new_value                      # null for skips
  t.string :source, null: false          # 'ours', 'theirs', 'auto_merge', 'conflict_resolved'
  t.timestamps
end
add_index :merge_operations, :component_sync_event_id
```

**Surgical undo algorithm:**
```
To undo merge B (while preserving merges A and C):

1. Load all operations from merge B
2. For each UPDATE operation:
   a. Check if merges C, D, ... also touched this (entity_id, field_name)
   b. If NO later merge touched it: revert field to old_value
   c. If YES: flag as conflict — human decides (keep C's value or revert to pre-B)
3. For each INSERT operation:
   a. Check if later merges reference this record (responding_to, duplicate_of)
   b. If NO references: delete the record
   c. If YES: flag as conflict — human decides (cascade delete or orphan)
4. Wrap in transaction. Abort if any unresolved conflicts.
5. Write a new sync event of type 'undo' with its own operation log.
```

### 17.4 Archive signing: Phase 1, optional

HMAC-SHA256 signing with shared secret per sync partner. Off by default.
Trivial implementation (~20 lines).

```ruby
# In export: sign the zip contents
signature = OpenSSL::HMAC.hexdigest('SHA256', shared_secret, zip_data)
manifest['signature'] = signature

# In import: verify before analysis
if Settings.sync.require_signed_archives
  expected = OpenSSL::HMAC.hexdigest('SHA256', shared_secret, zip_data)
  raise Import::UnsignedArchiveError unless manifest['signature'] == expected
end
```

Shared secret configured in `Settings.sync.partners`:
```yaml
# config/vulcan.default.yml
sync:
  require_signed_archives: <%= ENV.fetch('VULCAN_REQUIRE_SIGNED_ARCHIVES', false) %>
  partners:
    disa:
      shared_secret: <%= ENV['VULCAN_SYNC_SECRET_DISA'] %>
    vendor_acme:
      shared_secret: <%= ENV['VULCAN_SYNC_SECRET_ACME'] %>
```

---

## 18. PostgreSQL-Native Merge Operations

Research (2026-05-24) identified that the original design did too much work
in Ruby memory. The revised approach uses PostgreSQL for set operations and
bulk I/O, Ruby for business logic only.

### 18.1 What PostgreSQL Replaces

| Operation | Before (Ruby) | After (PostgreSQL) | Speedup |
|---|---|---|---|
| Rule upsert | 500× `rule.save` | `INSERT ON CONFLICT (rule_id, component_id) DO UPDATE` | 10-50× |
| Satisfaction insert | 500× `exists?` + `create!` | `INSERT ON CONFLICT DO NOTHING` | 10-50× |
| Review thread relink | N× `update_all` per review | Single `UPDATE ... CASE` statement | N× |
| Set diff (match/only-ours/only-theirs) | Ruby hash indexing in memory | `EXCEPT` / `INTERSECT` on temp tables | 2-5× + lower memory |
| Field-level diff | ~~Hashdiff gem~~ (removed) | AR Dirty `changes_to_save` + SQL column comparison | Lower memory, no gem dependency |

### 18.2 What Stays in Ruby

| Operation | Why Ruby |
|---|---|
| User resolution (`resolve_user`) | Cross-table lookups with LDAP/OIDC fallback logic |
| Comment phase normalization | Business logic (legacy 4-value → 2-value mapping) |
| Locked field conflict classification | Reads JSONB `locked_fields` + applies strategy logic |
| Merge strategy decisions | Configuration-driven, needs access to MergePlan state |
| Imported attribution | PII-aware display fallback logic |
| Archive parsing (JSON from zip) | Must happen before DB staging |
| Operation log recording | Captures before/after from AR Dirty tracking |

### 18.3 Hybrid Pipeline

```
1. Ruby: Parse archive zip → JSON hashes
2. Ruby: Resolve users, normalize timestamps, compute comment_digest
3. PG:   CREATE TEMP TABLE staging_rules (LIKE base_rules INCLUDING DEFAULTS)
4. PG:   Bulk COPY parsed rules into staging_rules
5. PG:   SQL diff — SELECT from staging JOIN live ON rule_id
         → matched (both sides), only_staging (new), only_live (ours only)
6. PG:   For matched: SELECT columns WHERE staging.col != live.col
         → per-field diff set
7. Ruby: Classify diffs (3-way vs baseline, locked fields, strategy)
         → MergePlan with resolutions
8. Ruby: Present MergePlan to user (CLI or UI)
9. PG:   INSERT INTO base_rules SELECT ... FROM staging_rules
         ON CONFLICT (rule_id, component_id)
         DO UPDATE SET col1=EXCLUDED.col1, col2=EXCLUDED.col2, ...
         WHERE rule_id IN (resolved_update_list)
10. Ruby: Capture AR previous_changes for operation log
11. PG:   Same pattern for reviews (INSERT ON CONFLICT + CASE UPDATE)
12. PG:   INSERT INTO merge_operations VALUES (...) — bulk insert undo log
13. Ruby: Quarantine invalid records, write sync event, cleanup
```

### 18.4 Pre-Existing Issues to Fix

Discovered during PostgreSQL audit of the codebase:

| Issue | File | Fix |
|---|---|---|
| SQL injection in `TO_NUMBER` | `component.rb:544` | Parameterize component ID |
| `component_metadata.data` is JSON not JSONB | `schema.rb:124` | Migration to change column type |
| Missing composite index for UNION query | `project.rb:34-111` | Add index on `(commentable_type, commentable_id, action, triage_status)` |
| ReviewBuilder relink is N queries | `review_builder.rb:234` | Replace with single CASE UPDATE |

---

## 19. ActiveRecord Native Capabilities

Research (2026-05-24) into Rails ActiveRecord source code found that several
proposed custom implementations are already solved by the framework.

### 19.1 What ActiveRecord Provides Natively

| Need | AR Feature | Replaces |
|---|---|---|
| **Bulk upsert with per-field resolution** | `upsert_all` + `on_duplicate: Arel.sql(...)` | Custom merge SQL generation |
| **Surgical undo data capture** | `assign_attributes` + `changes_to_save` | Custom before/after tracking |
| **Concurrent edit protection** | `transaction(isolation: :serializable)` | Advisory lock + comment_phase check |
| **Merge audit grouping** | Audited gem `request_uuid` + `audit_comment` | Custom merge event tagging |
| **Merge audit reversal** | Audited gem `audit.undo` method | Custom undo logic |
| **New review FK remapping** | `insert_all(returning: %w[id rule_id])` | Manual ID capture |
| **Satisfaction dedup** | `insert_all` with implicit `ON CONFLICT DO NOTHING` | `exists?` + `create!` loop |
| **Comment normalization** | Rails 8 `normalizes :comment, with: -> { ... }` | Manual strip/gsub |
| **SQL CASE generation** | `Arel::Nodes::Case` | Raw SQL strings |
| **Set diff in SQL** | Arel `except` / `intersect` | Hashdiff gem in Ruby |

### 19.2 Key Implementation Patterns

**Field-level merge resolution via `on_duplicate:`:**
```ruby
Rule.upsert_all(resolved_rules,
  unique_by: %i[component_id rule_id],
  on_duplicate: Arel.sql(<<~SQL.squish),
    status = EXCLUDED.status,
    severity = EXCLUDED.severity,
    check_text = CASE
      WHEN base_rules.updated_at > EXCLUDED.updated_at
      THEN base_rules.check_text
      ELSE EXCLUDED.check_text
    END
  SQL
  returning: %w[id rule_id])
```

**Surgical undo log via ActiveRecord::Dirty:**
```ruby
rule = Rule.find_by(rule_id: 'SV-230221', component_id: component.id)
rule.assign_attributes(status: 'approved', severity: 'high')
undo_data = rule.changes_to_save
# => {"status"=>["draft","approved"], "severity"=>["medium","high"]}
rule.save!
# Store undo_data in merge_operations table
```

**Concurrent edit protection via serializable isolation:**
```ruby
ActiveRecord::Base.transaction(isolation: :serializable) do
  # All reads + writes are serializable.
  # Concurrent UI edits cause ActiveRecord::SerializationFailure.
  merge_component(archive_data, component, strategy)
rescue ActiveRecord::SerializationFailure
  # Retry or surface to user: "Component was modified during merge"
  raise Import::ConcurrentEditError
end
```

**Merge audit grouping via audited `request_uuid`:**
```ruby
VulcanAudit.with_correlation_scope do
  # All audits in this block share one request_uuid.
  # Tag with merge event for later retrieval:
  Audited.audit_class.as_user(current_user) do
    rule.update!(status: 'approved')
    # Audited auto-captures changes. Tag via audit_comment:
    rule.audit_comment = "merge:#{sync_event.id}"
  end
end

# Later, to undo all changes from this merge:
Audit.where("comment LIKE ?", "merge:#{sync_event.id}").each(&:undo)
```

### 19.3 What This Eliminates from the Design

| Originally Planned | Now Unnecessary | Reason |
|---|---|---|
| `hashdiff` gem | REMOVE from deps | Arel EXCEPT + column-level SQL diff replaces Ruby diffing |
| Custom undo log writer | SIMPLIFY | AR Dirty `changes_to_save` captures before/after natively |
| Custom advisory lock SQL | REMOVE | `transaction(isolation: :serializable)` is stronger + handles concurrent UI edits |
| Custom audit record creation | SIMPLIFY | Audited gem's `request_uuid` + `audit_comment` + `undo` already group and reverse |
| PaperTrail gem | NEVER ADD | Audited already provides `revision`, `undo`, change history — adding PaperTrail is redundant |
| Manual FK ID capture | SIMPLIFY | `insert_all(returning:)` returns new IDs natively |

### 19.4 Revised Dependency List

| Dependency | Status | Reason |
|---|---|---|
| ~~`hashdiff` gem~~ | REMOVED | Replaced by Arel EXCEPT + SQL column comparison |
| `with_advisory_lock` gem | EXISTING (keep) | Still useful for component-level lock during snapshot export |
| `activerecord-import` gem | NOT NEEDED | Native `upsert_all` + `on_duplicate:` with pre-validation via `assign_attributes` + `valid?` is sufficient |
| `audited` gem | EXISTING (keep) | `request_uuid` + `audit_comment` + `undo` are the merge audit backbone |

---

## 20. Input Format Support

The merge system accepts TWO input formats, normalized to the same internal
representation before analysis.

### 20.1 JSON Archive (Primary)

Full-fidelity backup zip containing component.json, rules.json,
satisfactions.json, reviews.json. Carries all entity types including review
lifecycle fields, threading, and attribution. This is the format used for
vendor ↔ DISA transfer.

Parser: existing `Import::JsonArchiveImporter#parse_archive` → returns
`{ component:, rules:, satisfactions:, reviews: }` hash per component.

### 20.2 DISA Spreadsheet (Secondary)

Standard DISA CSV/Excel format with rule content (check text, fix text,
severity, status, vendor comments). Does NOT carry reviews, satisfactions,
or memberships. This is the format DISA distributes for rule content updates.

Parser: existing `SpreadsheetParser#parse_and_validate` → returns
`{ rows: [...] }` with one row per rule.

Merge scope: rules only (no reviews, no satisfactions). Uses
`Component#compute_rule_changes` for field-level diffing. Locked field
enforcement via `Rule#field_editable?`.

### 20.3 Normalized Internal Format

Both input formats are normalized to `MergeInput`:

```ruby
MergeInput = Struct.new(
  :format,          # :json_archive or :spreadsheet
  :rules,           # Array of rule attribute hashes (rule_id keyed)
  :reviews,         # Array of review attribute hashes (empty for spreadsheet)
  :satisfactions,   # Array of satisfaction pairs (empty for spreadsheet)
  :component_meta,  # Component-level fields (nil for spreadsheet)
  :memberships,     # Array of membership hashes (nil for spreadsheet)
  :manifest,        # Manifest metadata (nil for spreadsheet)
  keyword_init: true
)
```

MergeAnalyzer accepts `MergeInput` regardless of source format.

---

## 21. Background Job Architecture

### Decision: Merge runs as ActiveJob (2026-05-24)

Large merges (500 rules / 5000 reviews) could take 30+ seconds. Web requests
timeout at 30s (Heroku) or 60s (Puma default). The merge runs as a background
job with progress tracking.

### Flow

```
1. User uploads archive + selects strategy → POST /import_backup (merge=true)
2. Controller creates MergeJob, returns job_id immediately
3. MergeJob runs in background:
   a. Parse archive → MergeInput
   b. MergeAnalyzer → MergePlan (dry-run)
   c. If auto-resolvable: apply immediately
   d. If conflicts: store MergePlan, notify user "N conflicts need resolution"
4. User resolves conflicts in UI → POST /merge_resolve (job_id + resolutions)
5. MergeApplier runs (still in background job):
   a. Apply resolved MergePlan
   b. Write operation log + sync event
   c. Notify user "merge complete" or "N records quarantined"
```

### Job Class

```ruby
class MergeJob < ApplicationJob
  queue_as :merge  # Dedicated queue, concurrency=1 per component

  def perform(component_id:, archive_path:, strategy:, user_id:, sync_event_id:)
    component = Component.find(component_id)
    user = User.find(user_id)

    ActiveRecord::Base.transaction(isolation: :serializable) do
      # ... merge pipeline ...
    rescue ActiveRecord::SerializationFailure
      retry_count = (self.executions || 0)
      raise if retry_count >= 3
      raise  # ActiveJob auto-retries
    end
  end
end
```

### Progress Tracking

MergeJob updates `component_sync_events.status` as it progresses:
`queued → analyzing → awaiting_resolution → applying → complete / failed / quarantined`

The UI polls `GET /components/:id/merge_status` for current state.
Future: ActionCable for real-time updates (not in Phase 1-3).

---

## 22. Schema Evolution

### Problem

Archive exported from Vulcan 2.3.7 may have different columns than the
target running Vulcan 2.4.0 (or vice versa). The manifest carries
`vulcan_version` but the design must specify how column mismatches are handled.

### Strategy: Lenient Parse, Strict Apply

**On parse (MergeInput construction):**
- Unknown columns in the archive are preserved in a `_extra_fields` JSONB hash
  but not applied to model attributes. Warning logged.
- Missing columns (target has column, archive doesn't) are treated as NULL/absent.
  The merge treats this as "their side didn't change this field" — ours wins.

**On apply (MergeApplier):**
- Only columns in `Rule::MERGEABLE_FIELDS` are considered for upsert.
  Extra archive fields are ignored. Missing archive fields keep current values.
- `upsert_all` with `update_only:` naturally ignores columns not in the list.

**Version compatibility matrix:**

| Scenario | Behavior |
|---|---|
| Archive older than target (missing new columns) | New columns keep target's values. Warning: "archive v2.3.7 predates columns: X, Y" |
| Archive newer than target (extra unknown columns) | Extra data preserved in sync event `_extra_fields` for future use. Warning logged. |
| Same version | Clean merge, no warnings |
| Major version mismatch (2.x → 3.x) | Blocked. MergeAnalyzer rejects with error: "major version mismatch" |

### Manifest Version Gate

```ruby
COMPATIBLE_MAJOR_VERSIONS = [2].freeze

def validate_version_compatibility(manifest)
  archive_version = Gem::Version.new(manifest['vulcan_version'])
  unless COMPATIBLE_MAJOR_VERSIONS.include?(archive_version.segments.first)
    raise Import::IncompatibleVersionError,
      "Archive version #{archive_version} is not compatible with this Vulcan instance"
  end
end
```

---

## 23. Reusable Patterns from Existing Codebase

### 23.1 Spreadsheet Update Pattern (Component#update_from_spreadsheet)

The existing spreadsheet update pipeline at `component.rb:769-806` is the
closest existing precedent for the merge system:

| Spreadsheet Pattern | Merge Equivalent |
|---|---|
| `SpreadsheetParser#parse_and_validate` | `MergeInput` construction |
| `build_update_comparison(rows)` → `{ updated:, unchanged:, skipped_locked: }` | `MergeAnalyzer` → `MergePlan` |
| `compute_rule_changes(rule, row)` → `{ field: { from:, to: } }` | `RuleFieldDiffer` per-field diff |
| `rule.field_editable?(field)` / `rule.row_editable?` | Locked field conflict classification |
| `apply_rule_changes(rule, row, changes)` | `MergeApplier` rule update |
| Transaction wrapping | Serializable transaction |

**Key reuse:** `compute_rule_changes` returns `{ field_sym => { from: old, to: new } }` —
this is exactly the format the `merge_operations` table stores. The
`RuleFieldDiffer` should delegate to `compute_rule_changes` or extract its
comparison logic into a shared method.

### 23.2 Component#duplicate Pattern

The existing `Component#duplicate` at `component.rb:298-443` demonstrates:
- Amoeba deep copy with custom HABTM fix
- Bulk SQL for review/audit transfer (4 queries, not N)
- Counter cache reset after bulk import
- `skip_import_srg_rules` flag to bypass SRG rule cloning

**Key reuse:** The bulk SQL INSERT with CTE mapping table
(`duplicate_reviews_and_history`) is the template for the MergeApplier's
review import path when using `insert_all` + `returning`.

---

## 24. Resolved — No Open Questions

All questions resolved as of 2026-05-24. This design is implementation-ready.

### 24.1 source_instance_id: Configurable in vulcan.default.yml

```yaml
# config/vulcan.default.yml
sync:
  instance_id: <%= ENV.fetch('VULCAN_SYNC_INSTANCE_ID', Socket.gethostname) %>
```

ENV var with hostname fallback. Explicit config preferred over auto-detection
because container hostnames are ephemeral.

### 24.2 PostgreSQL version: PG 18+ confirmed

`docker-compose.yml` pins `postgres:18-alpine`. PG 18 provides:
- `CYCLE` clause for recursive CTE cycle detection (PG 14+)
- `MERGE` statement with `RETURNING` (PG 15+/17+)
- Row-level `pg_dump` filtering (PG 16+)

No version compatibility concerns. Use native PG features freely.

### 24.3 Incremental export: YES, built into Phase 4

Full snapshot is the default and always works. Incremental kicks in
automatically when sync history is intact:

- Component carries `sync_sequence` counter (monotonic, incremented per sync)
- Export adds `WHERE updated_at > last_sync_at` when `since_sync_sequence` present
- Manifest carries `since_sync_sequence: N` so receiver knows it's partial
- Gap detection: `if since_sync_sequence != last_received_sequence + 1` → reject, request full
- Fallback: any gap in history → automatic full snapshot, no user action needed

Adds ~sp:3 to Phase 4 scope (manifest v1.1). Not a separate phase.
