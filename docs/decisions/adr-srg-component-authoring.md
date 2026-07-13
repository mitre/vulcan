# ADR: Generalized XCCDF Document Authoring — SRG as the First New Profile

- **Status:** DRAFT v7 — v5 core (authored SRG requirements are **expanded
  `SrgRule`s**, not `Rule`s behind a policy layer) stands unchanged; v6 added
  Will's scoping (§0.1) + user workflow (§2.1). v7 (Aaron, 2026-07-12)
  resolves ALL of Will's review items 4–8 (§10): per-profile status
  vocabularies; **relocation redesigned as a first-class record + soft-delete
  tombstone — the `Moved` status is REMOVED** (revises §0.2/§0.3, see §4/§6);
  copy-on-release with a type-scoped XOR constraint (§8.2); primary parent =
  `based_on` ∈ declared parents (§5); delete-and-recreate accepted with the
  pre-delete backup mitigation (§2.1.4/§2.1.5). Will approved v7 (2026-07-13).
  v7.1 (2026-07-13): pre-carding adversarial review corrected five mechanics
  — all code-verified, no decision changes. Root cause of all five: `SrgRule`
  inherits `BaseRule`, not `Rule` — the soft-delete default scope, the
  counter_cache, and the amoeba clone idiom all live on `Rule` only. Fixes:
  `SrgRule` gains its own `deleted_at` default scope (§6); SRG-kind recount
  cannot ride `reset_counters(:rules)` (§6); release-copy is NEW machinery,
  not the amoeba block, which converts to `Rule` (§8.2); authored import
  cannot reuse `SrgRule.from_mapping` (§5.0); `duplicate(new_srg_id:)` must
  reconcile the parent join with `based_on` (§5).
  v7.2 (2026-07-13): schema review (same pre-carding pass, all
  code-verified) hardened the migration plan — relocation FK deletion
  policy (§6: source `dependent: :destroy` + backup/audit preserve
  history; target nullify); XOR CHECK co-migrated with optional srg_id +
  pre-flight guard (§12.1); `component_id` already exists, only
  `derived_from_srg_rule_id` is new (§12.1); `based_on` NOT NULL is an
  ordered §12.3 step (currently nullable, schema.rb:139), not a current
  fact (§5).
  v7.3 (2026-07-13): collision review (same pass) sized the real blast
  radius — every comment/triage/lock/release scoping query routes
  through the `Rule` STI association and must migrate to
  `Component#requirements` (§8: empty triage table, un-releasable SRG
  components otherwise); authored requirements need their own editor
  blueprint (§8 — `RuleBlueprint` calls Rule-only methods); currency/
  backup/revision-guard iterate ALL parents, not `based_on` (§5); SRG
  export is a new mode + fetch + helper guard, not a filter swap
  (§14.7).
- **Date:** 2026-07-10 (v2 per 3-agent swarm; v3 folded Aaron's eight fork
  decisions; v4 per readiness swarm; v5 replaced the storage core);
  2026-07-12 (v6 scoping + workflow, Will; v7 review resolutions, Aaron)
- **Deciders:** Aaron Lippold (with STIG-lead input, 2026-07-10; review
  resolutions 2026-07-12); Will Dower (scoping + workflow, 2026-07-12)
- **Companion:** `adr-satisfaction-restructuring.md` (v2-ulhw) — two
  distinct primitives, §9. `adr-dual-xccdf-export.md` — the export chapter
  of this initiative (same branch).

## 0. Decisions (Aaron, 2026-07-10 — all recorded on card v2-0d2l.1)

| # | Fork | Decision |
|---|---|---|
| 1 | Storage model | **Authored SRG requirements are `SrgRule`s, expanded with component linkage.** The prior Rule+`document_type`-policy design is rejected (§11) — it required a release-time type converter, which was the tell it stored the concept in the wrong type. |
| 2 | Moved mechanics | ~~`Moved` as a third SRG terminal status~~ **REVISED (v7, Aaron 2026-07-12, resolving §10.5): there is NO `Moved` status.** Relocation is a first-class `requirement_relocations` record (pending = the R4 marker; executed = the move). SRG vocabulary = NYD / Applicable / Not Applicable. Completion = not-NYD over LIVE rows stays uniform — moved rows leave the denominator. See §6. |
| 3 | Post-move source rule | **Tombstone via the EXISTING soft-delete** (v7): executing a relocation soft-deletes the source row in the same transaction — excluded from export/counts/UI by the existing `deleted_at` default scope (zero new query dimensions). Reviews/comments are preserved frozen on the tombstone (a move is not an erasure). Documented as a removal in that release's readme/changelog (from executed relocation records); unmentioned in the following release. |
| 4 | Parent modeling | **Primary `based_on` + `component_source_srgs` join table.** Multi-parent display is a follow-on card. |
| 5 | Core recognition | **DB flag** `security_requirements_guides.core`. Provenance: the core SRGs are **not on cyber.mil** — they are working documents of the ~4-person DISA SRG-author community (Aaron is one); they enter Vulcan via **upload**, and the identifiers come from Aaron and the documents themselves. |
| 6 | Creation modes | **Both, defaulting to full union-import** from all declared cores (every exclusion becomes an audited NA); selective mode = the same import machinery behind a requirement picker, not a second code path. |
| 7 | Publication | **Both**: SRG XCCDF export for the official DISA flow AND local catalog attachment on release so other work can base on it immediately (§8.2 — no converter needed under the SrgRule model). |
| 8 | Marker scope + intake | SRG components **only**. **Both consumers ship**: a standing per-family backlog view + an intake prompt at SRG-component creation/open for a family with pending markers. |
| 9 | Cross-document executor | **New primitive owned by v2-0d2l**; ulhw stays intra-component as scoped. |
| 10 | Satisfies UI | **Hidden entirely** on SRG components — structural under the SrgRule model (§7). |
| 11 | Reference benchmarks | **Manual searchable pick in v1** (creation step + settings); the two-stage suggestion engine is an optional, separately-carded follow-on gated on validating its similarity hypothesis (§8.1.3). |
| 12 | Mixed-type aggregates | **Per-type sections** `{ stig: {…}, srg: {…} }`; no cross-type bucket collapse. |
| 13 | Export scope | **Full SRG XCCDF export in v1** — format guidance from the published SRG XCCDFs already imported. |
| 14 | Multi-parent for ALL kinds (2026-07-11) | **STIG components get 1..N parents too** — one join table, one import engine, one invariant for the whole system; the ONLY kind-difference is parent eligibility: SRG components ⊆ the three cores; STIG components ⊆ derived (non-core) SRGs. Matches DISA practice (product STIGs span multiple SRGs). |

Remaining open items (§10): all three core family identifiers
(SRG-NET/SRG-OS/SRG-APP namespace documents — non-public, supplied by
Aaron with the core documents at upload; GPOS is a *derived* SRG, not the
OS core); per-status SRG field-config content (STIG-lead input at
implementation); export emit-shape details (pinned by diffing published
SRG XMLs).

## 0.1 Scoping amendment (Will Dower, 2026-07-12)

Two amendments. Neither overturns a §0 decision; both change what the work
is *called* and what it must make explicit.

| # | Amendment | Rationale |
|---|---|---|
| A | **This is not "adding SRG support." It is generalizing Vulcan to author a document off ANY XCCDF upstream.** SRG authoring is the primary and first-delivered profile; it is not the whole of the capability. | Vulcan's intended trajectory is to scope **beyond the DoD document space** and support authoring against essentially any XCCDF-compliant source document — e.g. organization-specific security policy documents that are neither STIGs nor SRGs. The SRG work builds precisely the machinery that requires: an authored document derived from an upstream benchmark, under its own status vocabulary and field rules. The generalization is therefore free if we take it now, and a rework if we don't — hard-coding the STIG/SRG binary would force a schema reopening the first time a non-DoD upstream shows up. |
| B | **The user workflow is a first-class requirement, not an implementation detail.** Authoring type is **chosen at component creation**, and that choice gates the source options and the per-requirement status options. Specified in §2.1. | The v5 ADR describes storage exhaustively and the user's path not at all. The creation-time choice had to be established by phone (Will→Aaron, 2026-07-11) rather than read off the document — which is the definition of an under-specified ADR. |

**What amendment A does and does not require.** It does **not** mean building
a third profile now — scope stays SRG + STIG, and SRG remains the focus. It
means the seams are *named and shaped* for extension so a third profile is
additive configuration rather than a schema migration. Concretely, five places
currently hard-code the binary and should be expressed as **per-profile
policy** instead (see §2.2):

1. `components.document_type` — an extensible **authoring profile**, not a
   two-value enum.
2. Parent eligibility — a per-profile rule, not the mirror-image pair of
   hard-coded clauses in §5.
3. `security_requirements_guides.core` — conceptually an upstream **tier**,
   not an SRG-specific boolean.
4. `derived_from_srg_rule_id` — conceptually "the upstream requirement this
   derives from." The FK name bakes in "the upstream is an SRG."
5. `SecurityRequirementsGuide` as the sole upstream registry.

Items 3–5 are **naming/widening debt, not re-architecture**: the v5 storage
core (§3) is already general — an authored requirement is a `BaseRule`
subclass linked to a component and to an upstream requirement. That shape
serves any XCCDF upstream. Renaming/widening later is a rename + a nullable
column, not a redesign. We record the debt here so the third profile is a
known, costed follow-on rather than a surprise.

## 1. Context

Per Aaron/STIG leads (2026-07-10): DISA publishes all SRGs and STIGs;
Vulcan's function is to make the **development, review, approval, and
ongoing lifecycle management of STIGs and SRGs easier, faster, and more
approachable**. Today only STIG authoring is first-class: a Component is a
STIG in progress, its requirements are `Rule` rows, and STIG semantics are
hard-coded through the status vocabulary (`RuleConstants::STATUSES`), the
per-status form config (`STATUS_FIELD_CONFIG`), the five-bucket
`Component#status_counts`, the satisfies graph, and the export pipeline.

Teams also author SRGs in Vulcan (Container SRG / Container Platform SRG),
and SRG authoring follows different rules. Crucially, **the codebase
already has the type for an SRG requirement**: `SrgRule`, an STI sibling of
`Rule` on the shared `base_rules` table. This ADR makes SRG authoring
first-class by **expanding `SrgRule`** — not by inventing a parallel
representation.

**The general shape of the problem (Will, 2026-07-12).** STIG-from-SRG and
SRG-from-core are the same operation at different levels: *author a document
whose requirements derive from an upstream XCCDF benchmark, under a status
vocabulary and field policy specific to the kind of document being written.*
That operation is not exhausted by STIGs and SRGs. Vulcan is intended to
eventually scope **beyond the DoD document space** — to support authoring
against essentially any XCCDF-compliant source document, including
organization-specific security policy documents that are neither STIGs nor
SRGs. That is the same operation under a third profile.

So the capability being added here is **generalized XCCDF document
authoring**, of which SRG authoring is the first and primary profile (§0.1
amendment A). STIG stays exactly as it is; SRG is delivered now; a further
profile is a costed, deliberate follow-on rather than speculative
generality — the point is only that the seams are shaped so it does not
require reopening the schema.

## 2. Requirements (Aaron + STIG leads, 2026-07-10 — verbatim-faithful)

R1. **Same state machine, different terminal buckets.** All requirements
    start `Not Yet Determined` in every document type. Terminal
    dispositions: STIG → the existing four; SRG → **Applicable** or
    **Not Applicable**. The **move marker** edge case is a relocation
    record, not a status (v7, §6).

R2. **Parentage: one or more CORE SRGs.** An SRG component derives from
    1..N of the three core SRGs (Network, OS, Application) — non-public
    author-community documents uploaded to Vulcan; core-ness is a
    family-level property. **Today every published SRG has exactly ONE
    core parent; the Container SRG effort is the pilot demonstrating that
    multi-core parentage has value — specifically DUAL lineage from the
    App core AND the OS core, which the authors believe produces the best
    final result** (Aaron, 2026-07-10). So 1 is the common case, and the
    validating scenario for N is concretely N=2 (APP+OS → Container).
    Identifier consequence: a dual-lineage family mints under both core
    namespaces with one shared technology token (`SRG-APP-…-CTR-…` and
    `SRG-OS-…-CTR-…`) — each requirement's ID core-half follows its own
    `derived_from` lineage. `Component.based_on` today is a single FK.

R3. **No Satisfied-By at the SRG level** — satisfaction is STIG semantics.

R4. **Relocation marker**: a requirement can be labeled "needs to move"
    with a target SRG document (in-progress component; published SRG with
    an update under way; or published SRG with no update started = "next
    release of this family"). Markers form a cross-document backlog.

R5. **Edit flow and active fields differ per document type.**

R6. **The authoring profile is chosen by the user at component creation, and
    that choice gates everything downstream** (Aaron, confirmed to Will by
    phone 2026-07-11). A component is a STIG **or** an SRG — never a
    component that permits both behaviors and resolves the difference later.
    Specified in §2.1.

## 2.1 User workflow — the creation choice and what it gates (R6)

This is the section the v5 draft lacked. It is normative: the storage model
(§3) exists to serve it.

**The choice is made once, at creation, and it is exclusive.** The New
Component flow asks *"What are you authoring?"* — **STIG** or **SRG** — before
anything else. We do **not** create a neutral component and let both
behaviors coexist. The chosen profile is persisted as
`components.document_type` and is immutable thereafter (§2.1.4).

Everything below follows from that single answer.

### 2.1.1 What the choice gates

| Surface | STIG profile | SRG profile |
|---|---|---|
| **Source / parent picker** (what you may base the document on) | 1..N **derived (non-core) SRGs** from the catalog — today's single `based_on`, now multi-select (§0.14) | 1..N **core SRGs** (SRG-NET / SRG-OS / SRG-APP) — the non-public author-community documents (§5) |
| **Per-requirement status options** | today's five: NYD, Applicable-Configurable, Applicable-Inherently Meets, Applicable-Does Not Meet, Not Applicable | NYD, **Applicable**, **Not Applicable** (§4; relocation is a record, not a status — §6) |
| **Per-status field config** (which fields are active/required) | today's `STATUS_FIELD_CONFIG` | SRG field config (content from STIG leads — §10.2) |
| **Satisfied-By panel** | present | **absent entirely** — not a disabled state (§7) |
| **Relocation marker** | absent | present (§6) |
| **Export mode** | STIG XCCDF (+ InSpec, disposition matrix) | SRG XCCDF (§8.2) |

The two lists of source options are **mirror images and mutually exclusive**:
a core SRG is never a valid STIG base, and a derived SRG is never a valid SRG
base. Users therefore never see an irrelevant option — the picker is filtered
by the profile they just chose, not merely validated after the fact.

### 2.1.2 Creation walkthrough (both profiles)

1. **Choose the profile** — STIG or SRG.
2. **Choose the source document(s)** — the picker is populated per §2.1.1 and
   is multi-select for both profiles (§0.14).
3. **Identity** — STIG: the component prefix, as today. SRG: the family
   **technology token** (CTR, GPOS, DB, …), the SRG-world analogue of the
   prefix (§5).
4. **Choose the import mode** — full union-import of every requirement from
   every declared source (default), or selective via a requirement picker
   (§5.0). Identical machinery for both profiles.
5. *(Optional)* **Reference benchmarks** — a searchable catalog pick (§8.1.3).

The component is then created with its requirements already imported, in
`Not Yet Determined`, and the editor opens in the profile's mode.

### 2.1.3 Authoring loop

Per requirement the author sets a status from **their profile's vocabulary
only**, and the form shows the fields that profile's config marks active for
that status. STIG authors additionally use Satisfied-By; SRG authors
additionally use the relocation marker. Review, comment, lock, and audit
behave identically across profiles (§13) — those are document-agnostic.

### 2.1.4 Changing your mind

`document_type` is **immutable after creation**. If a user picks the wrong
profile the supported remedy is **delete and recreate** — there is no
in-place conversion, because the status vocabularies and the requirement
types (`Rule` vs `SrgRule`) differ. Consequences to accept and to surface in
the UI:

- The creation dialog must make the choice legible and hard to get wrong
  (short plain-language description of each, not just two radio buttons).
- Deleting loses the live component — but the pre-delete backup (§2.1.5)
  carries its content and reviews/comments out, and restore brings them
  back, so the practical cost of the remedy is near-zero.
- **DECIDED (Aaron, 2026-07-12, closing §10.6):** delete-and-recreate is
  accepted for v1; no conversion path. Revisit only if it bites in
  practice. Mitigated by §2.1.5.

### 2.1.5 Pre-delete backups (Aaron, 2026-07-12)

A general Vulcan safety feature (own epic — not SRG-specific) that this
workflow depends on for its remedy. Recorded here because §2.1.4 is its
motivating case; it applies to every destructive delete.

**Decision: destructive delete actions offer "Create a backup first"
(default ON). The backup is the EXISTING JSON archive, stored server-side
with a retention window, restorable through the EXISTING import path.**
No new serialization format, no new restore machinery — the feature is a
retention shell around export/import that already round-trips
(`BackupSerializer` → zip; `create_from_backup` / archive import restore).

| Aspect | Design | Why |
|---|---|---|
| Artifact | the existing component/project JSON archive (zip) | already round-trips; one format, one importer; zip-bomb defense already on the import path |
| Storage | `bytea` column in Postgres (`deletion_backups.archive`) | Heroku ephemeral filesystem rules out disk; multi-MB-in-DB has precedent (`stigs.xml` / `srgs.xml`); rides DB backup/encryption posture |
| Schema | `deletion_backups`: `archive`, `record_type` (string — no FK/polymorphic association, the target row is gone by design), `record_id`, `metadata` jsonb (name, prefix, version, project name, counts — for listing after the source is gone), `created_by_id`, `expires_at` (indexed), timestamps | list/download/restore must work with zero joins to deleted data |
| Expiry | `expires_at = created_at + Settings.backups.retention_days.days`; **lazy purge** (`purge_expired!` on admin-list access and on each create) | no background-job dependency — same lazy pattern as PAT idle-revocation; moves to a daily job when SolidQueue lands (v2-l0yx) |
| Settings | `backups.pre_delete_enabled` (default **true**), `backups.retention_days` (default **60**, min 1) via `VULCAN_BACKUP_RETENTION_DAYS` in `vulcan.default.yml` | operator-tunable; no magic zero values |
| Scope | Component delete ✅, Project delete ✅. Rule delete ❌ (already a recoverable soft-delete). Catalog SRG/STIG delete ❌ (re-uploadable from source XML). | backups guard the only truly destructive paths |
| Flow | archive generated **before** destroy; backup row insert + destroy in **one transaction** (destroy fails → backup rolls back too — never a "backup" of a live record). **Fail-closed:** if archive generation fails, the delete ABORTS — the user explicitly asked for a safety net; silently deleting without one is the worst outcome. | correctness over convenience |
| Access | creator + site admins: list ("Deleted-item backups": name, type, deleted-by, expires-in, size), download (zip), restore (existing import flow, into a chosen project for components), delete-now | matches export-endpoint sensitivity; archives carry full component content |
| Audit | create / download / restore / delete-now of a backup are audited | deletion-with-backup is a compliance-relevant action |

**Honest limits (stated, not discovered later):** the archive is a
**content lifeboat, not an identity-preserving undo**. It carries rules,
descriptions, checks, and reviews/comments; the `audited` trail of the
deleted record is *not* in the archive — it survives independently in the
audits table (audited retains rows after destroy), and a restored
component starts a fresh audit trail. Build-time verify-point: confirm the
archive's review/history coverage against what §2.1.4 promises before
closing the implementing card.

## 2.2 The profile seam (per §0.1 amendment A)

The variance above is **per-profile policy**, and should be expressed as such
rather than as `if stig? … else …` pairs. One table keyed by profile —
source eligibility, status vocabulary, field config, which panels render,
export mode — is the seam. Adding the third profile (§1) then means adding a
row, not migrating a schema or threading a new conditional through every
call site.

This is a naming and shaping constraint on the implementation, not new
behavior: the v5 storage core (§3) already supports it, and the STI
hierarchy carries the *behavioral* variance. The profile table carries the
*configuration* variance. Keep them distinct.

## 3. Decision (core): expand `SrgRule`; the STI hierarchy IS the seam

An SRG component's requirements are **`SrgRule` rows linked to the
component** (`srg_rules.component_id`, nullable — catalog rows keep it
null). The type system already separates the two authoring worlds:

- **Shared by construction** (lives on the `base_rules` table or the
  polymorphic layers, so it works for `SrgRule` today or nearly so):
  status, severity, `locked`/`locked_fields`, `review_requestor_id`,
  soft-delete, the review/comment system (attaches via polymorphic
  `commentable` — component-level comments with `rule_id: nil` are the
  existing precedent for non-`Rule` commentables), title/fixtext/idents,
  and the check/description associations.
- **Structurally absent for SRG requirements** (defined on `Rule`, not
  `BaseRule` — nothing to gate): the satisfies graph + ADNM automation,
  InSpec code, vendor-comment/STIG-answer machinery. R3 is satisfied by
  the type system, not by a policy object.
- **Component kind**: `components.document_type` remains — the component
  must know its profile before any requirements exist, because the user
  chooses it first and it gates the source picker and status vocabulary
  (§2.1). Backfilled `stig`; immutable post-create (§2.1.4). Model it as an
  **extensible authoring profile**, not a two-value enum (§0.1 A) — the
  third profile (§1) must be a new row in the profile table (§2.2), not a
  migration. The *behavioral* variance rides the STI classes; the column is
  routing metadata plus the key into the profile config — not a policy
  dispatcher.

What this dissolves from the rejected design (§11): the
`Component::AuthoringPolicy` dispatcher, per-document-type validation
conditionals on `Rule`, the policy-gated satisfaction exclusion, and the
release-time Rule→SrgRule materialization converter.

What it costs, honestly: `SrgRule` expansion (component linkage; its
catalog parent becomes optional while authored), an authoring surface for
`SrgRule`s (editor/controllers currently serve `component.rules` of class
`Rule`), and audit wiring (`VulcanAuditable` is included in `Rule`, not
`BaseRule` — authored `SrgRule`s need the same auditing). Enumerated in
§4–§8 and phased in §14.

### 3.1 Frontend leak-surface inventory (unchanged from v4 — still true)

The JS/HAML surfaces hard-code STIG statuses regardless of which model
class holds requirements, so this inventory survives the core rework.
Dispositions: **[P]** route through the document-kind seam, **[G]** gate
to STIG-kind, **[U]** unreachable for SRG-kind.

Ruby:
- `vue_props_helper.rb` — global `statuses` prop ships all 5 STIG statuses
  to every page. **[P]** (per-component, kind-aware). Sharpest leak.
- `Component#status_counts` / `status_buckets` — **[P]** (kind-shaped
  buckets; SRG counts come from the component's `SrgRule`s).
- `Project#details` — hard-codes ac/aim/adnm/na/nyd. **[P]** + §5.1.
- `Project#dashboard_*` — **[P]** per §5.1 (per-type sections).
- `ExcelFormatter` status dropdown = STIG statuses. **[P]**
- `ExportHelper#apply_disa_content_rules!` — STIG field-blanking matrix;
  SRG export mode has its own (Phase 7). **[P]**
- `ReviewsController#lock_controls` — STIG-shaped eligibility; SRG
  eligibility is simpler (no satisfies/mitigation preconditions). **[P]**
- ADNM automation — `Rule`-only; also invoked by rake
  (`container_srg_nesting_fix.rake`), which operates on `Rule`s and
  cannot touch `SrgRule`s. **[U]** (structural now — verified reasoning
  replaces the v4 policy guard).
- Disposition matrix export — comment-driven, STIG-shaped. **[G]** v1.

JavaScript:
- `useRuleFormFields` + `RuleContextPanel.vue` (both read
  `STATUS_FIELD_CONFIG`). **[P]** via a document-kind-keyed config.
- Full-status hard-coding: `useRuleFilters.js`, `useRuleNavigation.js`,
  `FilterBar.vue`, `ProjectSidepanels.vue`, `RuleNavigator.vue` (unsynced
  duplicate of useRuleNavigation — consolidate), `ActiveFilterPills.vue`,
  `RuleForm.vue`, `DisaRuleDescriptionForm.vue`, `CheckForm.vue`,
  `RuleEditorHeader.vue` (duplicates reviewActionHelpers — consolidate).
  **[P]**
- Partial references (lock tooltips/messages): `reviewActionHelpers.js`,
  `terminology.js`. **[P]**
- Phase 2 AC: grep for prefix/substring matches on `'Applicable'` that the
  new bare value would wrongly satisfy.

## 4. Status model — per-profile vocabularies (R1; v7 resolves §10.4/§10.5)

- **Per-profile status vocabularies (v7, resolving §10.4):** each authoring
  profile owns its status set in the profile registry (§2.2) — STIG keeps
  today's five; **SRG = `[NYD, Applicable, Not Applicable]`** (no `Moved` —
  relocation is a record, not a status; §6). No bare `Applicable` ever
  joins a shared flat list. Evidence for the guard posture: an audit found
  **zero substring/prefix status matching in production code** (all
  comparisons are exact full-string), so per-profile separation is
  prevention, not rescue; enforcement is exact-match `inclusion`
  validation per profile, not a source-grep spec.
- **Validation scoping**: profile-vocabulary validation applies to
  **component-linked (authored) rows only** — catalog-imported `SrgRule`s
  keep the legacy superset inclusion so published-XML statuses never break
  ingest. `Rule` needs no change at all: STIG statuses remain exactly
  today's five, enforced as today.
- **Completion** = not-NYD over **live** rows, uniform across types
  (dashboards unchanged). Relocated (tombstoned) rows leave the
  denominator — a document is done when every *remaining* requirement is
  decided.
- **Buckets**: STIG-kind keeps five; SRG-kind reports
  `{ not_yet_determined, applicable, not_applicable }` from live
  `SrgRule`s, plus a separate `moved_out` count from executed relocation
  records (it is a lifecycle fact, not a status bucket).
- **API shape**: add `document_type` to stats/workflow responses;
  `rules_by_status` modeled as **`oneOf` + `document_type` discriminator**
  with `additionalProperties: false` per branch (a type-keyed loose map
  would weaken every shipped STIG contract).

## 5. Multi-parent derivation — ALL document kinds (R2; extended §0.14)

- **Both kinds get 1..N parents** (Aaron, 2026-07-11): one join table
  `component_source_srgs (component_id, security_requirements_guide_id)`,
  one import engine, one invariant — no kind-conditional machinery. The
  gated (SRG-only) version would have cost MORE code, and multi-SRG STIGs
  match DISA practice (product STIGs span multiple SRG scopes; today's
  single `based_on` forces authors to drop lineage).
- `based_on` stays the primary parent for both kinds (zero change to the
  53 existing read sites; primary-only display until the follow-on
  display card, which now serves both kinds). **NOT NULL is a migration
  step to establish, not a current fact (v7.2):** the column is nullable
  today (schema.rb:139) with no presence validation, and the plain
  create path permits a NULL-based_on component — §12.3 must audit for
  NULL/dangling rows, decide repair-vs-skip, and add the NOT NULL
  constraint BEFORE the "based_on ∈ join, ≥1 parent" invariant is
  enforced.
- **Primary-parent selection (v7, resolving §10.8): `based_on` IS the
  designation — no `primary` flag on the join table.** The multi-select
  picker includes a primary radio, **default = first selected**; the user
  may change it post-create only among declared parents. One validation
  ties the mechanisms: `based_on` must be ∈ `component_source_srgs`.
  Changing primary affects display/family defaults only — imports were
  unioned at creation and do not re-run.
- **Join reconciliation on revision (v7.1):** `Component#duplicate`
  (component.rb:408) reassigns `copied_component.based_on = new_srg` when
  `new_srg_id:` is supplied, while `include_association` copies the OLD
  parent set — leaving `based_on` ∉ join and the invariant rejecting the
  revision save. The model must enforce reconciliation: assigning
  `based_on` inserts it into `component_source_srgs` atomically (and the
  upgrade path replaces the superseded family member rather than
  appending unbounded). One spec pins the revision flow end-to-end.
- **Three based_on-only sites are CORRECTNESS under multi-parent, not
  display (v7.3, collision review)** — "primary-only display until the
  follow-on card" does not cover them:
  1. **Currency**: `srg_is_latest = based_on&.latest?`
     (component_blueprint.rb:143-153) and
     `SecurityRequirementsGuide.srg_info_for_components`
     (security_requirements_guide.rb:31-38) check only the primary — a
     dual-lineage component reports "up to date" while a secondary core
     has a new version, silently defeating the §5 staleness cascade.
     Currency iterates ALL of `component_source_srgs`.
  2. **Backup**: `backup_serializer.rb:54-88` records only `based_on`
     identity — restore of a multi-parent component loses every
     secondary parent, breaking the §2.1.5 pre-delete safety net that
     §2.1.4 delete-and-recreate depends on. The backup format captures
     the full parent set (backups epic dependency).
  3. **Revision guard**: `duplicate(new_srg_id:)` short-circuits on a
     primary-only compare (component.rb:405) — a revision changing a
     secondary parent is mis-detected. Guard compares the full set.
- **Invariant — family-level, version-tolerant, both kinds**: every
  requirement's source (`Rule#srg_rule` / authored `SrgRule#derived_from`)
  belongs to a parent-set *family* (exact-record matching is violated by
  real upgraded-component data — `Component#duplicate` keeps old-version
  references by design). Verify against production data before
  enforcement.
- **Parent eligibility is the ONLY kind-difference**: SRG-kind — ≥1
  parent, every parent family must be **core**; STIG-kind — ≥1 parent,
  every parent family must be **derived (non-core)** (mirror-image;
  cores are the authors' non-public raw material and are not valid STIG
  bases). **Express this as per-profile policy (§2.2), not as a hard-coded
  mirror-image pair** — it is the rule that a third profile (§1) most
  obviously breaks, since an arbitrary XCCDF upstream is neither a core nor
  a derived SRG. The same policy drives the *filtered* source
  picker the user sees at creation (§2.1.1), so eligibility is enforced by
  construction rather than validated after the fact.
- The dual-mode creation import (§5.0) serves both kinds — a multi-parent
  STIG component union-imports (or selectively imports) from all its
  declared SRG parents through the same machinery.
- **Core recognition (§0.5)**: `security_requirements_guides.core`
  boolean, set when the (non-public, author-uploaded) core documents are
  uploaded; identifiers supplied by Aaron with the documents.
  **Corrected (Aaron, 2026-07-10): GPOS is NOT the OS core** — it is a
  Level-1 *derived* SRG of the OS core (its requirement IDs
  `SRG-OS-…-GPOS-…` carry both namespaces). The cores are the non-public
  `SRG-NET` / `SRG-OS` / `SRG-APP` namespace documents; none is in repo
  data today, by design.
- **Document hierarchy** (confirmed): Level 0 = the three cores
  (non-public) → Level 1 = derived SRGs, published on cyber.mil and
  authored in Vulcan as SRG components (GPOS from OS; Container Platform
  from APP: `SRG-APP-…-CTR-…`) → Level 2 = STIGs, based on derived SRGs
  (today's STIG components, unchanged).
- **Derived identifier minting (Aaron, 2026-07-10)**: the SRG component
  declares its family **technology token** (CTR, GPOS, DB, …) at creation
  — the SRG-world analogue of a STIG component's prefix. Working
  requirements display their core lineage (`derived_from`); the final
  derived identifiers (`SRG-APP-000014-CTR-000035` = core half from
  lineage + token + local sequence) are **minted at release** so
  mid-authoring adds/removes never renumber a published identifier.
- **Next release of a family (Aaron, 2026-07-10)**: **duplicate the prior
  release + reconcile against the latest cores** (the SRG-world analogue
  of today's STIG-component revision flow), plus the family's pending
  relocation-marker intake (§6). Minted identifiers carry forward stable;
  only new requirements mint new local sequence numbers.
- **The lifecycle cascade — one staleness pattern, three levels**: cores
  version too. Core update → derived-SRG update (authored here,
  reconciled) → STIG updates (existing rebase flow). The same
  `VersionSortable`/is-latest currency machinery that today tells a STIG
  component "your SRG is stale" tells an SRG component "your core is
  stale."
- **Source lineage**: each authored `SrgRule` records the core requirement
  it derives from (`derived_from_srg_rule_id` FK to the catalog row) —
  the SRG-world analogue of `Rule#srg_rule`, powering the invariant,
  related-requirements, and the changelog.

### 5.0 Creation & rule import (Aaron, §0.6)

Two modes, one machinery:
- **Full union-import (default)**: authored `SrgRule`s are generated from
  every requirement of all declared parents (each parent processed like
  today's single-SRG import; cores are disjoint). ~500–600 rows for three
  cores — every exclusion becomes an explicit, audited NA.
- **Selective**: the same generator behind a requirement picker.
- **The authored generator is NEW code (v7.1)** — it must NOT reuse
  `SrgRule.from_mapping` (srg_rule.rb:15 sets
  `security_requirements_guide_id`, which violates the authored XOR:
  both FKs set aborts the import at the CHECK). The generator copies
  content from the catalog row, sets `component_id` +
  `derived_from_srg_rule_id`, and leaves
  `security_requirements_guide_id` NULL.
Both modes: adding a parent later imports (or offers) its requirements;
`Component#duplicate`/overlay must `include_association` the new join
tables and, for SRG-kind, validate core-family membership on rebase.

### 5.1 Mixed-type projects (Aaron, §0.12)

Project aggregates report **per-document-type sections**
(`{ stig: {…}, srg: {…} }`); per-component rows carry their own shape;
type-agnostic numbers (rule_count, completion, locks) stay top-level. No
cross-type bucket collapse anywhere (`Project#details` included).

## 6. Relocation as a first-class record (R4; v7 REDESIGN resolving §10.5)

**v7 replaces the marker-columns + `Moved`-status design.** Status answers
"what did we decide"; relocation answers "where is it going" — Will's §10.5
was right that fusing them (the two-way `Moved`⇄target invariant) was the
tell of two concepts in one column. The redesign:

```
requirement_relocations
  source_rule_id       NOT NULL, FK base_rules   -- dependent: :destroy from
                                                 -- the source rule (v7.2)
  target_family_token  NOT NULL                  -- 'CTR', 'GPOS', …
  target_rule_id       NULL, FK base_rules       -- filled when landed;
                                                 -- on_delete: :nullify (v7.2)
  requested_by_id      FK users
  executed_at          NULL = pending            -- the lifecycle
  + unique partial index ON source_rule_id WHERE executed_at IS NULL
```

- **Deletion interaction (v7.2, schema review).** Existing base_rules FKs
  are NO ACTION/:restrict (schema.rb:461, 473-474) — an unspecified
  relocation FK would BLOCK component delete-and-recreate (§2.1.4) for
  any SRG component with relocation history, aborting mid-backup. Policy:
  the source rule gets `has_many` to its relocation records with
  `dependent: :destroy` — hard-destroy of the source row (component
  delete, SRG destroy) removes its records, pending and executed alike;
  the history survives in the §2.1.5 pre-delete backup and the audit
  trail (relocation events are audited, and audits carry no FK). The
  target row itself is never touched — it keeps its `derived_from`
  lineage. Target-side destruction stays nullify + audit note. §6
  "executed records are immutable" means no user edits; system-side
  cascade/nullify with audit coverage is the same pattern both sides.

- **Pending** (`executed_at` NULL) IS the R4 marker: row badge; per-family
  backlog = `pending.where(target_family_token:)`; creation/open-time
  intake prompt (§0.8). Un-mark = destroy the pending record (audited);
  executed records are immutable.
- **Executed** = ONE transaction: create/link the target requirement →
  set `target_rule_id` → stamp `executed_at` → **soft-delete the source
  row** → recount the component's requirement counter.
- **Tombstone visibility requires a `SrgRule` default scope (v7.1).**
  The `deleted_at` default scope exists ONLY on `Rule` (rule.rb:110) —
  `BaseRule`/`SrgRule` have none, so without it a tombstoned authored
  row stays visible in every SrgRule query (editor, buckets, export)
  and next-release duplication RESURRECTS moved-out rows. Fix:
  `default_scope { where(deleted_at: nil) }` on `SrgRule` (mirroring
  `Rule`; behavior-neutral today — no SrgRule row carries `deleted_at`),
  NOT on `BaseRule` (that would newly filter catalog/StigRule reads).
  Duplicate/copy association traversals additionally exclude deleted
  rows explicitly.
- **SRG-kind recount cannot ride `reset_counters(:rules)` (v7.1)** —
  `has_many :rules` is class `Rule`, so that call zeroes `rules_count`
  for an SRG component. Authored requirements need their own counting
  path (a scoped count over live authored `SrgRule`s, or a dedicated
  counter column) decided at the Phase 1 card; every recount site is
  kind-routed through it.
- **Reviews/comments are preserved, frozen** on the tombstoned row (v7
  decision): they leave active comment views automatically (those joins
  already exclude `deleted_at`) but survive in the DB and audit trail —
  a move is not an erasure.
- **Visibility (v7 decision): history-only.** Moved-out requirements do
  not appear in the editor list (consistent with delete semantics); the
  story lives in the relocation backlog/history view and the release
  changelog. No "Moved out" editor section in v1.
- The single remaining invariant is **one-directional** (`executed_at` ⇒
  source soft-deleted), enforced by the executor transaction + model
  validation — no bidirectional coupling.
- Dangling targets: nullify + audit note on target destruction; orphan
  sweep owned by the relocation phase card.
- Audit: authored `SrgRule`s get `VulcanAuditable` wiring in Phase 1;
  relocation create/un-mark/execute are audited.
- **Intake (both, §0.8)**: standing per-family backlog view + creation/
  open-time prompt ("N requirements are marked for this family") seeding
  the executor phase. SRG components only (source side), per §0.8.

## 7. Satisfied-By exclusion (R3) — structural

`SrgRule` has no satisfies associations, no `RuleSatisfactionValidator`
hookup, no ADNM callbacks — the exclusion is the type system. The SRG
editor simply never renders the satisfies panel (**hidden entirely**,
Aaron §0.10 — a capability that doesn't exist, not a disabled state).
`RuleSatisfactionsController` operates on `Rule` lookups and cannot reach
an `SrgRule`; one request spec pins the 404/422 behavior for an attempted
cross-type call.

## 8. Edit flow / authoring surface (R5)

- **Editor plumbing**: the component editor serves the component's
  requirements — `Rule`s for STIG-kind, authored `SrgRule`s for SRG-kind —
  through a unified accessor (`Component#requirements`, kind-routed).
- **The scoping-query migration is structural work, not column reuse
  (v7.3, collision review).** The polymorphic commentable is genuinely
  `BaseRule`-typed (comments attach to an `SrgRule` fine), but every
  comment/triage/lock/release SCOPING query routes through the `Rule`
  STI association and structurally excludes authored `SrgRule`s:
  `CommentQueryService#build_base_scope` (`@component.rules`,
  comment_query_service.rb:41/81/114/118 — the triage table renders
  EMPTY), `Review.for_components` (`Rule.where(component_id:)`,
  review.rb:95 — dashboard aggregates omit SRG comments),
  `reviews_controller#lock_controls` (`@component.rules`, :525 —
  lock-all locks nothing, so an SRG component can NEVER satisfy
  `rules_must_be_locked_to_release` and cannot be released), the
  addressed-by target lookup (`Rule.find_by`, :367), and the
  `parent.rule&.component` call site (:842 — bypasses the correct
  `Review#component` accessor). Every one migrates to
  `Component#requirements` / a base_rules-scoped subquery
  (`deleted_at IS NULL`). The correct pattern already exists in
  `Component.pending_comment_counts` (component.rb:717, joins
  base_rules directly). These sites are load-bearing for the in-flight
  comment/triage work — the migration is Phase 2 scope, explicit.
- **Authored requirements need their own editor blueprint (v7.3).**
  `RuleBlueprint`'s viewer/editor/picker views call Rule-only methods —
  `satisfies`/`satisfied_by` (rule_blueprint.rb:68-74/102-108),
  `srg_rule` (:88/:137/:141), `additional_answers` (:132) —
  NoMethodError on an `SrgRule`. The existing `SrgRuleBlueprint` is
  read-only nested reference data (no status/reviews/locked) and cannot
  be reused. A dedicated authored-`SrgRule` editor blueprint
  (status/reviews/locked/comment summary; no satisfies/srg_rule/
  additional_answers) plus a kind-routed serializer branch.
- **Field config**: `STATUS_FIELD_CONFIG` gains a document-kind dimension
  (`FIELD_CONFIG_BY_DOCUMENT_TYPE`); both direct consumers
  (`useRuleFormFields`, `RuleContextPanel.vue`) select by the component's
  kind. SRG per-status field content comes from the STIG leads at
  implementation.
- The global `statuses` prop becomes per-component kind-aware (§3.1).

### 8.1 Related requirements + reference benchmarks (Aaron, 2026-07-10)

New backend query work (today `related_rules` returns everything and
filters client-side; no reference-benchmark concept exists):

1. **SRG-kind related requirements query the SRG catalog** — structural
   under this model: authored and published requirements are the same
   type, so "how do the catalog's SRGs handle this requirement" is a
   same-type query keyed by the derived-from lineage.
2. **Reference benchmarks (both kinds)**: `component_reference_benchmarks`
   join; `related_rules` gains server-side filter params; results default
   to declared references (absent a declaration: STIG-kind → its
   `based_on` family; SRG-kind → its parent cores) with an explicit
   **see-all** toggle.
3. **Suggested references — v1 is a manual pick (Aaron, §0.11)**: a
   searchable catalog picker at creation (+ settings) writes the join
   directly; SearchAbbreviation expansion already helps ("postgres" →
   the Postgres STIGs). The **two-stage engine** (Stage 1: class by SRG
   lineage — `stig_rules.srg_id` overlap, verified 1126/1126 populated;
   Stage 2: platform by content-pattern similarity via the existing
   pg_search infrastructure, e.g. `/etc/`+`systemctl` vs `HKLM\…` vs
   `postgresql.conf` vs T-SQL) is **a separately-carded optional
   follow-on**, gated on validating the similarity hypothesis before any
   precompute is built. Recorded here so the follow-on card doesn't
   re-design it.

### 8.2 Publication round-trip + versioning (Aaron, §0.7)

- **Export** (Phase 7): released SRG component → SRG XCCDF for the
  official DISA flow (tombstones excluded; removals in the release
  readme/changelog).
- **Local catalog attachment on release = COPY, never dual-link (v7,
  resolving §10.7).** Releasing an SRG component creates its catalog
  `SecurityRequirementsGuide` row, generates the SRG XCCDF via the
  exporter and stores it on that row (the released entry is shaped
  identically to an uploaded one — basing, is-latest, and seeds work
  unchanged), then **copies each LIVE authored `SrgRule`** into a fresh
  catalog row (`security_requirements_guide_id` = catalog,
  `component_id` = NULL). **The release copy is NEW machinery (v7.1)**:
  `SrgRule`'s amoeba block is hardwired `set type: Rule` /
  `become_rule` (srg_rule.rb:5-9) — it exists to turn catalog rows into
  component `Rule`s at import, and reusing it here would emit a
  wrong-typed `Rule` row that the type-scoped XOR cannot catch. The
  release copy dups AS `SrgRule` (explicit attribute copy or a scoped
  dup that bypasses the amoeba block), asserts the resulting type, and
  is pinned by a spec that a released row is a catalog `SrgRule`.
  Authored rows stay component-linked and editable; tombstones are not
  copied (enforced by the §6 default scope + an explicit
  `deleted_at: nil` guard); reviews/comments/history stay on the
  component.
- **Integrity constraint (v7):** an `SrgRule` is authored XOR catalog —
  `CHECK (type <> 'SrgRule' OR (component_id IS NULL) <>
  (security_requirements_guide_id IS NULL))` — **type-scoped** because
  `base_rules` is the shared STI table (`Rule` and `StigRule` rows carry
  neither/other FKs and must be unaffected). `belongs_to
  :security_requirements_guide` becomes `optional: true`, paired with the
  check. This makes Will's dual-link hazard structurally impossible, not
  merely guarded.
- **Versioning**: component integer `version`/`release` ↔ catalog
  `V{version}R{release}` — one scheme, mapped at release/export.

## 9. Relationship to v2-ulhw — two DISTINCT primitives

v2-ulhw is intra-component satisfies-graph regrouping (its epic scopes
OUT cross-component moves). The relocation marker describes cross-document
moves — **a separate executor owned by this epic (Aaron, §0.9)**: dry-run
+ transactional bulk move consuming the marker backlog, with a simpler
validation set (no satisfies graph on the SRG side). Two ADR files; one
combined review discipline; no shared executor code until real
duplication appears.

## 10. Remaining open items

1. **The three core family identifiers** (SRG-NET / SRG-OS / SRG-APP
   namespace documents) — supplied by Aaron with the core documents at
   upload (non-public; not externally researchable; GPOS is derived from
   the OS core, not the core itself).
2. **SRG per-status field-config content** — STIG-lead input at Phase 2.
3. **Export emit-shape details** — pinned by diffing the published SRG
   XMLs in `db/seeds/srgs/` against the import model (Phase 7 starting
   task; full implementation is in scope, §0.13).

Raised in review (Will, 2026-07-12) — none blocks the §3 core, but 4 and 7
should be settled before their phase is carded:

4. **The bare `Applicable` value is a substring footgun — recommend
   rejecting the flat shared list.** `RuleConstants::STATUSES` today is one
   flat array containing `Applicable - Configurable`,
   `Applicable - Inherently Meets`, `Applicable - Does Not Meet`, and
   `Not Applicable`. Note that **`'Not Applicable'.include?('Applicable')`
   is already true** — substring logic on this vocabulary is fragile
   *before* we touch it. Adding a bare `'Applicable'` to the same list makes
   every prefix/substring check genuinely ambiguous, and §3.1's mitigation
   ("grep for prefix/substring matches" as a Phase-2 AC) is a one-time sweep,
   not a structural guard. **Recommend: per-profile status vocabularies**
   (a set keyed by authoring profile, per §2.2) rather than one shared flat
   array — which is also what amendment A wants anyway. If the flat list is
   kept, this needs a lint/spec guard forbidding substring matching on
   status, not a grep. **RESOLVED (Aaron, 2026-07-12): per-profile
   vocabularies adopted (§4); authored rows only, catalog imports keep the
   legacy inclusion. Audit found zero substring status matching in
   production code — prevention, not rescue.**
5. **`Moved` conflates disposition with routing.** Status answers "what did
   we decide about this requirement"; the relocation marker answers "where is
   it going." Fusing them forces the bidirectional `Moved`⇄target invariant
   (§6), and a needed two-way invariant is usually the tell that two concepts
   share one column. Decided explicitly by Aaron (§0.2) and not overturned
   here — but worth one more pass, since a moved requirement arguably still
   has a disposition in its target. **RESOLVED (Aaron, 2026-07-12): the one
   more pass produced a redesign — relocation is a first-class record and
   the `Moved` status is removed entirely (§0.2/§0.3 revised, §4, §6).
   Concern accepted and answered structurally rather than as accepted
   risk.**
6. **Mis-typed component recovery** (from §2.1.4): `document_type` is
   immutable and the remedy is delete-and-recreate, losing comments/reviews/
   history. Recommend accepting for v1 — but as a recorded decision, not an
   omission. **RESOLVED (Aaron, 2026-07-12):** accepted for v1, recorded in
   §2.1.4; cost mitigated by the pre-delete backup feature (§2.1.5).
7. **Release/catalog aliasing (§8.2) is under-specified.** On release, the
   component's authored `SrgRule`s "attach" to a newly created catalog
   `SecurityRequirementsGuide` — but those rows already carry `component_id`.
   Do they end up holding *both* FKs? If so, one row is simultaneously the
   component's editable requirement and the immutable published catalog
   entry, and a later revision of the component (duplicate + reconcile, §5)
   would mutate published data. Strongly suspect release must **copy** into
   catalog rows rather than dual-link the same row. Must be settled before
   Phase 7. **RESOLVED (Aaron, 2026-07-12): copy-on-release, plus a
   type-scoped authored-XOR-catalog CHECK constraint making dual-link
   structurally impossible (§8.2). v7.1: the copy is NEW machinery —
   `SrgRule`'s amoeba block converts to `Rule` and cannot be reused.**
8. **Primary-parent selection is undefined for N parents.** `based_on` stays
   NOT NULL as the primary parent (protecting 53 read sites), but with a
   multi-select picker (e.g. APP + OS for Container) nothing says which of the
   declared parents becomes primary — user-chosen, or first-selected?
   **RESOLVED (Aaron, 2026-07-12): user designates via a primary radio in
   the picker, default = first selected; `based_on` IS the designation and
   must be ∈ declared parents (§5).**

## 11. Alternatives considered and rejected

- **`Rule` + `document_type` policy seam (the v1–v4 design of this very
  ADR)** — REJECTED by Aaron (2026-07-10). It stored authored SRG
  requirements as `Rule`s and dispatched variance through a
  `Component::AuthoringPolicy`, which forced: per-type conditional
  validation on `Rule`, policy-gated satisfaction exclusion, and a
  release-time Rule→SrgRule materialization converter. The converter was
  the tell: needing a type conversion at publication means the concept
  was stored in the wrong type. The codebase already had `SrgRule`;
  expanding the existing type is the null hypothesis and it dissolves all
  three warts structurally. (Recorded prominently so the reasoning
  survives; see also bd memory `adr-premise-review-failure`.)
- **STI on Component** (`SrgComponent < Component`): ~900-line god model;
  the kind difference at the component level is routing metadata, while
  the real behavioral variance is rule-level — where STI already exists.
- **A brand-new rule type**: `SrgRule` exists; inventing a third
  representation is strictly worse.
- **Second status column**: two sources of truth; smell.
- **Type-keyed loose map for rules_by_status**: forces
  `additionalProperties: true`; rejected for discriminator `oneOf`.
- **Vulcan-side admin curation of "core"**: contradicts provenance — the
  cores are author-community documents; the flag rides their upload.
- **Curated suggestion taxonomy**: rejected in favor of manual pick v1 +
  the optional data-derived engine (no maintained mapping either way).

## 12. Migration & back-compat (phase-aligned)

1. Phase 1: `components.document_type` (default+backfill `stig`,
   immutable); `derived_from_srg_rule_id` (new FK to the catalog row,
   indexed) — **`component_id` already exists** on base_rules
   (schema.rb:83, the shared STI column; do not re-add, v7.2);
   `security_requirements_guide_id` becomes optional for
   component-authored `SrgRule`s **in the SAME migration as the §8.2
   XOR CHECK** (v7.2 — sequencing them separately opens a window where
   a catalog `SrgRule` saves with NULL srg_id and no compensating
   constraint; bulk `SrgRule.import` bypasses validations). Precede
   `ADD CONSTRAINT` with a pre-flight guard proving no existing
   `SrgRule` row is both-NULL or both-set. `SrgRule` `deleted_at`
   default scope (§6 v7.1); `VulcanAuditable` wiring for authored
   `SrgRule`s. Zero behavior change for every existing record; **the
   full suite passing untouched is the faithfulness proof.**
2. Phase 2: `Applicable` status value atomic with the per-profile
   (authored-`SrgRule`-only) exact-match inclusion validation and UI
   gating (§4). No relocation machinery lands here.
3. Phase 3: ordered steps (v7.2): audit components for NULL/dangling
   `based_on` → repair-or-decide → `component_source_srgs` (backfill
   from `based_on`) → NOT NULL on `components.
   security_requirements_guide_id` → only then enforce the §5
   "based_on ∈ join, ≥1 parent" invariant.
   `security_requirements_guides.core` flag (set on core-document
   upload).
4. Phase 4: `requirement_relocations` table (§6) — source FK
   (`dependent: :destroy` from the source rule), target family token,
   nullable target FK (`on_delete: :nullify`), `executed_at`, unique
   partial index on pending source — one atomic change. No new
   `base_rules` columns, no new status value.
5. Phase 6: `component_reference_benchmarks`.
6. `bundle exec rake parallel:prepare` after every migration.

## 13. Testing strategy

- **Type-level**: `SrgRule` authored-subset validation matrix (every
  legal/illegal value; catalog-imported rows unaffected);
  `Rule` untouched (STIG suite is the regression proof).
- **Shared machinery**: shared examples proving locking, reviews,
  comments, audit behave identically on authored `SrgRule`s (the
  component-level-comment precedent extended).
- **Invariants**: parent-set ⊆ core families; derived-from ∈ parent
  families (family-level, prod-verified before enforcement); relocation
  lifecycle (§6): unique pending per source, executed ⇒ source
  soft-deleted (one-directional), executed records immutable,
  dangling-target nullify; `document_type` immutability.
- **Leak-surface regression**: one spec per §3.1 [P] surface asserting
  SRG rendering/config never contains a STIG-only status (the statuses
  prop is the canary).
- **API/contract**: discriminator `oneOf` with per-branch
  `additionalProperties: false`; 7-layer rule per endpoint.
- **Live**: full SRG authoring walkthrough (create → import → bucket →
  mark → release → attach) on the dev server before close (Gate 18).

## 14. Phasing (implementation children of v2-0d2l, carded post-approval)

1. **SrgRule expansion + discriminator** — schema (§12.1), unified
   `Component#requirements` accessor, audit wiring; zero behavior change.
2. **SRG status model + authoring surface** — `Applicable` +
   `SrgRule`-scoped validation; editor/controller `SrgRule` branch; the
   full §3.1 [P] gating (Ruby + JS, incl. the consolidations); type-aware
   buckets/dashboards (`oneOf`); SRG field config (STIG-lead content);
   the cross-type satisfaction request spec (§7); **the Rule-association
   scoping-site migration to `Component#requirements`** (comments/triage/
   lock/release paths, §8 v7.3 — without it the triage table is empty and
   an SRG component cannot be released); **the dedicated authored-SrgRule
   editor blueprint** (§8 v7.3).
3. **Multi-parent (both kinds, §0.14)** — core flag on upload
   (+ identifiers from Aaron), join table, per-kind parent-eligibility
   validation (SRG ⊆ cores; STIG ⊆ derived), family invariants, dual-mode
   creation import (§5.0) for both kinds, amoeba/duplicate gating
   (+ follow-on: multi-parent display, both kinds).
4. **Relocation records (pending intake)** — `requirement_relocations`
   table (§6); pending record = the R4 marker (row badge, per-family
   backlog queries, un-mark = audited destroy); `moved_out` count from
   executed records (§4); **both intake surfaces** (family backlog view +
   creation/open prompt). Depends on 2.
5. **Relocation executor** — dry-run + the §6 transaction per move
   (create/link target → stamp `executed_at` → soft-delete source →
   kind-routed requirement recount, §6 v7.1); reviews preserved frozen;
   history-only visibility; orphan sweep. Depends on 4.
6. **Related requirements + reference benchmarks** — server-side
   `related_rules` params + same-type SRG catalog branch; reference join +
   picker (creation step + settings) + see-all. (Follow-on, separate +
   optional: the two-stage suggestion engine, gated on hypothesis
   validation.)
7. **Publication** — SRG XCCDF export mode. More than a filter swap
   (v7.3): a new `Export::Modes::PublishedSrg` (SRG terminal filtering +
   tombstone exclusion; no satisfies/srg_rule eager-loads —
   published_stig.rb:20-36 pulls Rule-only associations), an
   authored-`SrgRule` fetch replacing `component.rules` (export
   base.rb:195 — the Rule association is EMPTY for an SRG component),
   and a guard on the `rule.satisfies` call in the export helper
   (export_helper.rb:286). Plus release readme/changelog removals +
   local catalog attachment (§8.2). Depends on 2–3.

Ordering: 2, 3, 6 independent after 1; 4 after 2; 5 after 4; 7 after 2–3.

**The creation workflow (§2.1) spans phases 2 and 3 and must be carded
explicitly — it is the user-visible heart of this ADR and the easiest thing
to lose between two storage phases:**

- Phase 2 owns the **profile picker** ("What are you authoring?" → STIG /
  SRG), persisting `document_type`, plus the profile-keyed status vocabulary
  and field config it gates (§2.1.1). The profile config table (§2.2) lands
  here — it is the seam every later phase reads.
- Phase 3 owns the **filtered source picker** (multi-select, eligibility by
  profile — §2.1.1/§5) and the import-mode step (§5.0).
- Acceptance for the workflow is the §13 Live walkthrough exercised **for
  both profiles**: create → pick sources → import → set statuses from the
  correct vocabulary → confirm the wrong profile's options are never
  offered (not merely rejected).
