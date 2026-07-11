# ADR: SRG Component Authoring — SRG-Writing as a First-Class Document Type

- **Status:** DRAFT v5 — core reworked per Aaron's architectural correction
  (2026-07-10, late): authored SRG requirements are **expanded `SrgRule`s**,
  not `Rule`s behind a policy layer. Awaiting Aaron's read + approval.
- **Date:** 2026-07-10 (v2 per 3-agent swarm; v3 folded Aaron's eight fork
  decisions; v4 per readiness swarm; v5 replaces the storage core)
- **Deciders:** Aaron Lippold (with STIG-lead input, 2026-07-10)
- **Companion:** `adr-satisfaction-restructuring.md` (v2-ulhw) — two
  distinct primitives, §9.

## 0. Decisions (Aaron, 2026-07-10 — all recorded on card v2-0d2l.1)

| # | Fork | Decision |
|---|---|---|
| 1 | Storage model | **Authored SRG requirements are `SrgRule`s, expanded with component linkage.** The prior Rule+`document_type`-policy design is rejected (§11) — it required a release-time type converter, which was the tell it stored the concept in the wrong type. |
| 2 | Moved mechanics | **`Moved` is a third SRG terminal status value**; the marker FK carries the target. Completion = not-NYD stays uniform. |
| 3 | Post-move source rule | **Tombstone**: stays `Moved` forever in Vulcan; excluded from exported XCCDF; documented as a removal in that release's readme/changelog; unmentioned in the following release. |
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

## 2. Requirements (Aaron + STIG leads, 2026-07-10 — verbatim-faithful)

R1. **Same state machine, different terminal buckets.** All requirements
    start `Not Yet Determined` in every document type. Terminal
    dispositions: STIG → the existing four; SRG → **Applicable**,
    **Not Applicable**, or the **move marker** edge case (`Moved`).

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
- **Component kind**: `components.document_type` enum (`stig` default,
  backfilled; immutable post-create) remains — the component must know its
  kind before any requirements exist (creation flow, editor routing,
  aggregate shapes). But the *behavioral* variance rides the STI classes;
  the column is routing metadata, not a policy dispatcher.

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

## 4. Status model — ternary state, binary decision (R1)

- New status **values** `Applicable` (Phase 2) and `Moved` (Phase 4,
  atomic with its target invariant) join `RuleConstants::STATUSES`.
- **Validation scoping**: `BaseRule` keeps the superset inclusion (all
  branches; imports unaffected). The SRG-authoring subset —
  `[NYD, Applicable, Not Applicable, Moved]` — is a **`SrgRule`
  validation guarded on `component_id` presence** (catalog-imported
  `SrgRule`s are untouched). `Rule` needs no change at all: STIG statuses
  remain exactly today's five, enforced as today.
- **Completion** = not-NYD, uniform across types (dashboards unchanged).
- **Buckets**: STIG-kind keeps five; SRG-kind reports
  `{ not_yet_determined, applicable, not_applicable, moved }`, computed
  from the component's `SrgRule`s.
- **Post-move tombstone (Aaron, §0.3):** after the executor runs, the
  source `SrgRule` stays `Moved` — permanent audited disposition; excluded
  from XCCDF export; listed as a removal in that release's
  readme/changelog; silent in the next release.
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
- `based_on` stays the primary parent for both kinds (NOT NULL — zero
  change to the 53 existing read sites; primary-only display until the
  follow-on display card, which now serves both kinds).
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
  bases).
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
Both modes: adding a parent later imports (or offers) its requirements;
`Component#duplicate`/overlay must `include_association` the new join
tables and, for SRG-kind, validate core-family membership on rebase.

### 5.1 Mixed-type projects (Aaron, §0.12)

Project aggregates report **per-document-type sections**
(`{ stig: {…}, srg: {…} }`); per-component rows carry their own shape;
type-agnostic numbers (rule_count, completion, locks) stay top-level. No
cross-type bucket collapse anywhere (`Project#details` included).

## 6. Relocation marker (R4; Aaron §0.2/§0.8)

- `base_rules.relocation_target_type/_id` — polymorphic
  (`SecurityRequirementsGuide` = "next release of that family", or
  `Component` = a specific in-progress document). Columns live on the
  shared table; **used only by `SrgRule`** (structural + validated).
- `Moved`⇄target invariant: setting `Moved` requires a target; clearing
  the target reverts the status (model-enforced).
- Family resolution: queries resolve the target's family (the identity
  `VersionSortable` groups by) so markers survive supersession.
- Dangling targets: nullify + audit note on target destruction; orphan
  sweep owned by the Phase 4 card.
- Audit: authored `SrgRule`s get `VulcanAuditable` wiring in Phase 1 (the
  `Rule` class's except-list pattern), so marker changes ride the trail.
- **Intake (both, §0.8)**: standing per-family backlog view + creation/
  open-time prompt ("N requirements are marked for this family") seeding
  the Phase 5 executor.

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
  Controllers gain the `SrgRule` branch (reusing the same
  locking/review/comment flows via the shared columns and polymorphic
  commentable — component-level comments already prove the
  non-`Rule`-commentable path).
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
- **Local catalog attachment on release**: releasing an SRG component
  creates its catalog entry — a `SecurityRequirementsGuide` row that the
  component's authored `SrgRule`s attach to (they already ARE the right
  type; no conversion, just linkage) — so other components can base on it
  immediately.
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
   immutable); `srg_rules.component_id` (nullable FK) +
   `derived_from_srg_rule_id`; `security_requirements_guide_id` becomes
   optional for component-authored `SrgRule`s; `VulcanAuditable` wiring
   for authored `SrgRule`s. Zero behavior change for every existing
   record; **the full suite passing untouched is the faithfulness proof.**
2. Phase 2: `Applicable` status value atomic with the `SrgRule`-scoped
   subset validation and UI gating. `Moved` is NOT introduced here.
3. Phase 3: `component_source_srgs` (backfill from
   `security_requirements_guide_id`); `security_requirements_guides.core`
   flag (set on core-document upload).
4. Phase 4: marker columns + `Moved` value + `Moved`⇄target invariant +
   nullify lifecycle — one atomic change.
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
  families (family-level, prod-verified before enforcement); marker
  gating + `Moved`⇄target + nullify lifecycle; `document_type`
  immutability.
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
   the cross-type satisfaction request spec (§7).
3. **Multi-parent (both kinds, §0.14)** — core flag on upload
   (+ identifiers from Aaron), join table, per-kind parent-eligibility
   validation (SRG ⊆ cores; STIG ⊆ derived), family invariants, dual-mode
   creation import (§5.0) for both kinds, amoeba/duplicate gating
   (+ follow-on: multi-parent display, both kinds).
4. **Relocation marker + `Moved`** — columns, value, invariant,
   lifecycle, backlog queries, dashboard visibility, **both intake
   surfaces** (family backlog view + creation/open prompt). Depends on 2.
5. **Cross-document move executor** — dry-run + transactional bulk move
   consuming the backlog. Depends on 4.
6. **Related requirements + reference benchmarks** — server-side
   `related_rules` params + same-type SRG catalog branch; reference join +
   picker (creation step + settings) + see-all. (Follow-on, separate +
   optional: the two-stage suggestion engine, gated on hypothesis
   validation.)
7. **Publication** — SRG XCCDF export mode (delta on the existing
   `Export::Formatters::XccdfFormatter`, which already emits
   Component→XCCDF; the STIG mode's Applicable-Configurable-only filter is
   replaced by SRG terminal filtering + tombstone exclusion) + release
   readme/changelog removals + local catalog attachment (§8.2). Depends
   on 2–3.

Ordering: 2, 3, 6 independent after 1; 4 after 2; 5 after 4; 7 after 2–3.
