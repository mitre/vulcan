# SRG Workstream — Codebase Impact & Completion Map

**Status:** scoping / design (deep sweep 2026-07-18)
**Relates to:** `docs/decisions/adr-srg-component-authoring.md` (the kind seam),
`docs/plans/srg-triage-parity.md` (the triage slice of this same question).
**Method:** five parallel read-only sweeps (backend queries · export/import/backup ·
frontend · API contract · documentation), every load-bearing claim re-verified
against source before inclusion. All file:line references below are verified.

## 1. Verdict

The SRG architecture is **structurally right and mostly landed**. The kind seam
(`Component#requirements`, `BaseRule.live_for_components`), the field-state
config (`fieldStateConfig` keyed kind × status × tier), the export fetch
(`Export::Base#load_rules` gated by `mode.supports_srg_kind?`), the JSON
backup/restore round-trip, and the API **read** surface (oneOf-routed schemas
with a real-fixture contract test) were all migrated correctly and verify clean.

What remains is a **second fetch family** the first migration never touched:
copy/duplicate, spreadsheet update, pickers and in-component search, comment
decoration, one validator, and the write side of one API schema. Each is a
small fix; all share one root shape — `Rule`-scoped access to requirement rows.
Plus the documentation surfaces, which are entirely STIG-voiced today.

## 2. What is already right (verified, no work)

| Layer | Evidence |
|---|---|
| Requirement primitives | `component.rb:143` `requirements`, `:158` `requirements_count`; `base_rule.rb:34` `live_for_components` |
| Counts / stats / workflow | `component.rb` status_counts, dashboard_stats, workflow_state, releasable all kind-route; `project.rb:266-319` aggregates use `live_for_components` |
| Triage table + enablement | `comment_query_service.rb` and `project.rb:142` visibility scope; comment gating keys on `comment_phase`, not kind |
| Export service seam | `base.rb:194-203` — ONE kind-routing fetch for every formatter; formatters stay kind-blind on passed-in rows |
| Backup round-trip | serializer branches STI type, guards `respond_to?(:satisfies)`, restores `document_type` and rebuilds `SrgRule` rows re-linked by portable version |
| Frontend config seam | `fieldStateConfig.js` single source of truth; every STIG-only affordance gated ONCE at a parent boundary (`!isSrg` in toolbar/editor/form; `document_type` checks in sidepanels/histories) |
| API read contract | Editor/stats/workflow schemas oneOf-routed and Blueprint-aligned; `spec/contracts/srg_components_contract_spec.rb` exercises real authored rows |
| HAML views + props seam | Follow-up sweep (2026-07-18): `app/views/` has ZERO Rule-traversal or STIG-status hardcodes; `vue_props_helper.rb` verified kind-aware (`AuthoringProfile.for(component.document_type).statuses` — the former "sharpest leak" properly fixed). Mailers had exactly one gap (G16). |

## 3. Verified gaps — the second fetch family

Severity: ★★★ integrity/data-loss · ★★ wrong/empty results · ★ hardening/hygiene.

### 3.1 Comment / triage domain (fits the triage-parity sub-epic)

| # | file:line | Defect | Sev |
|---|---|---|---|
| G1 | `app/models/review.rb:645-650` | `duplicate_of_must_be_same_component` resolves component via `Rule.where(id:)` / `Rule.joins(:reviews)` — nil for SrgRule, and the validator returns on nil. **The cross-component/cross-project duplicate guard silently passes for every SRG comment** (the guard exists to prevent review-ID leaks across project boundaries). Fix: `Rule` → `BaseRule`. | ★★★ |
| G2 | `app/models/project.rb:181` | Project comment view: visibility scope (`:142`) already kind-aware, but page decoration does `Rule.where(id: page_rule_ids)` — SRG comment rows render with nil rule-ID/prefix/component. Fix: `Rule` → `BaseRule` (mirror `comment_query_service`). | ★★ |
| G16 | `app/mailers/user_mailer.rb:79-85` | `find_latest_request_review` re-fetches the row via `Rule.find_by(...).id` — nil for an authored SrgRule → **NoMethodError; the review-workflow email family crashes for SRG requirements** when SMTP is enabled (the review-request workflow is kind-shared by design). Redundant lookup — the method already receives the row. Found by the follow-up HAML/helpers/mailers sweep (2026-07-18). | ★★ |

### 3.2 Copy & data-lifecycle domain

| # | file:line | Defect | Sev |
|---|---|---|---|
| G3 | `app/models/component.rb:38` (amoeba `include_association :rules`) + user paths `components_controller.rb:611-620` (`create_or_duplicate`, `overlay`) | User copy/duplicate/overlay copies only `Rule` rows — **an SRG component copy silently produces an empty component** (all authored requirements dropped). The release-copy card owns only the release path; the user path is unowned. | ★★★ |
| G4 | `app/models/component.rb:805,814` via `components_controller.rb` update/apply actions | Spreadsheet **update/apply** flow has no `document_type` guard (the create-branch guard card covers create only). Applying a spreadsheet against an SRG component operates on the wrong STI family. | ★★ |
| G5 | `app/services/import/backup_serializer.rb` (manifest emits singular `based_on` only) + restore `component_builder.rb:78-83` | `component_source_srgs` join rows never serialized or restored — **a multi-source (dual-lineage) SRG component does not survive a backup round-trip intact**. | ★★★ |
| G6 | `app/controllers/components_controller.rb:146` | Destroy bulk cleanup is `Rule.unscoped`-scoped: for SRG components the fast path no-ops and deletion falls to per-row cascade — kind-inconsistent delete semantics (bulk `delete_all` vs audited cascade) and latent perf risk. | ★ |

### 3.3 Discovery surfaces (pickers / search / find)

| # | file:line | Defect | Sev |
|---|---|---|---|
| G7 | `components_controller.rb:342-346` `rules_picker` (`@component.rules.includes(:satisfied_by, :satisfies)`) → `RulePicker.vue` | Move-to-rule / duplicate-target picker is **empty for SRG components** — triage admin actions cannot target authored requirements. Kind-routing must drop the Rule-only preloads for the SRG branch. Schema `RulePickerResponse` is STIG-only too. | ★★ |
| G8 | `components_controller.rb:529` `find` (search-within-component) | `Component.find_by(id:).rules` + `Check`/`DisaRuleDescription` child scans — empty results for SRG components. SRG branch should scan requirement-applicable fields. (Sibling of the global-search card, which owns `api/search_controller.rb:113`.) | ★★ |

### 3.4 API contract (write side; read side is done)

| # | file:line | Defect | Sev |
|---|---|---|---|
| G9 | `doc/openapi/components/schemas/RuleInput.yaml` | Request-body status enum lists only the 5 STIG statuses; PATCH/PUT `/rules/:id` serves both kinds and accepts `"Applicable"` for authored rows at runtime — the write side needs the same kind variant the responses already have (oneOf or a second input schema). | ★★ |
| G10 | `rules_controller.rb:68` (`revert` 404s unless `is_a?(Rule)`) | Audit-history revert is Rule-only. Parity question: authored SRG rows are audited too — enable revert, or bless as a deliberate exception. **Decision, not auto-card.** | ★ |

### 3.5 Frontend

| # | file:line | Defect | Sev |
|---|---|---|---|
| G11 | `app/javascript/constants/terminology.js:12` | `RULE_TERM` is a static module-level global consumed in template literals at load — the entity noun cannot differ per document kind ("Rule" for STIG rows, "Requirement" for SRG rows) within one deployment. `STATUS_DESCRIPTIONS_BY_DOCUMENT_TYPE` in the same file already models the correct kind-keyed shape. **Whether per-kind nouns are wanted is a product decision.** | ★ |
| G12 | `rules/forms/RuleForm.vue:174,192` | `rule.disa_rule_descriptions_attributes.length` / `checks_attributes.length` without the `|| []` guard — the one break in the omitted-keys defense pattern. Reachability for SRG depends on the editor payload shape; the fix pins the payload in a spec and makes the guard structural (shared `ruleArray` helper) instead of per-call-site vigilance (~8 hand-written `|| []` sites today). | ★ |

### 3.6 Dev infrastructure

| # | Location | Defect | Sev |
|---|---|---|---|
| G13 | `db/seeds/**` | Zero `document_type: 'srg'` seed data — no demo component exercises ANY SRG path (grep-confirmed). The seeded "Container SRG Test" project is STIG-kind. | ★★ |
| G14 | `component.rb:791` `csv_export` + `export_helper.rb` | Dead code: no live callers (live CSV path is the export service). Same treatment as the dead editor components previously removed. | ★ |
| G15 | `lib/tasks/db_analyze.rake:16,68,88` | Dev diagnostics traverse `.rules` — SRG components report 0. Fold into the invariant-guard card. | ★ |

### Flagged elsewhere (not this epic's cards)

- `components_controller.rb:407-408` (compare) and `:427-429` (history version diff) traverse `.rules` — SRG components compare as empty. This is the compare/diff world (the sync/merge epic being split to its own PR); flagged so it is not silently dropped. **Ownership decision needed.**
- No backend sync/merge engine exists on this branch to audit (frontend `MergeCommentsModal.vue` only) — consistent with the split plan.

## 4. Architecture — how it stays DRY

**4.1 The one rule.** No requirement-scoped code touches `Rule.where(...)` or
`component.rules` — always `Component#requirements` /
`BaseRule.live_for_components`. Genuinely STIG-only surfaces (satisfies graph,
InSpec, spreadsheet import, STIG ID minting) instead **guard at the door** with
`document_type` (the pattern `rules#create` already uses) so unsupported kinds
fail loudly instead of returning silently-empty results. Silent-empty is the
defect behind most of §3.

**4.2 Enforcement.** Generalize the triage-parity guard spec into a
codebase-wide invariant: a custom RuboCop cop (or grep-guard spec) that flags
`Rule.where` / `.rules` traversal in requirement-scoped app code, with an
explicit allowlist for the deliberate STIG-only surfaces. The comment-domain
regressions (G1/G2 sitting next to an already-fixed sibling) prove vigilance
alone does not hold.

**4.3 One copy path.** The amoeba `include_association :rules` family (user
copy, overlay, release-copy) converges on one kind-aware deep-copy helper that
copies `requirements` — not three call sites each branching.

**4.4 One count.** Serialize `Component#requirements_count`, never raw
`rules_count` (the Rule-only counter cache), across Blueprint views and
`Project#available_components` — one field, one backing method.

**4.5 Search is a BaseRule capability.** `pg_search` lives on `Rule` only;
move it up (or add the SrgRule scope) so global search, in-component find, and
pickers hit the requirement surface, not one STI branch.

**4.6 Frontend seams.** `fieldStateConfig` is the proven pattern — extend it,
never scatter v-ifs (current gating altitude is correct; keep it). Two additions:
kind-keyed terminology lookups (if the product decision says yes), and a shared
`ruleArray(rule, key)` guard so the authored-rows-omit-Rule-keys invariant is
structural.

**4.7 API shape policy.** Keep separate schemas + `oneOf`; **no discriminator,
no collapsed nullable-everything schema** — `document_type` lives on the parent
component (the stats schemas' sibling-tag pattern is correct), and disjointness
is already enforced by `required` + `additionalProperties: false`. Bring the
write side (`RuleInput`) up to the same standard as the read side.

## 5. Documentation plan — DISA Process docs

**5.1 Wiring (verified).** ONE markdown source — `docs/disa-process/*.md` —
rendered by two pipelines: VitePress (markdown-it, mermaid supported via
`config.mjs` fence transform) and the in-app guide
(`DisaGuideController` → Commonmarker → SafeListSanitizer → `v-html`;
**mermaid fences show as raw code blocks in-app** — verified, no mermaid JS in
that pack). Page nav is duplicated in `config.mjs` and the controller's
`PAGE_SECTIONS` — a new page must be added to both.

**5.2 New page: `docs/disa-process/srg-authoring.md`.** The SRG authoring
workflow: what CORE SRGs are, derived-SRG authoring (NYD → Applicable/NA
lifecycle), multi-parent derivation incl. dual lineage, ID minting at release,
draft → public comment (triage) → published SRG, and how a published SRG then
seeds STIG components. Derives from ADR §2.1, §4/§4.1, §5/§5.1, §8.2. Wired
into both navs.

**5.3 Staleness edits (verified line numbers).**
- `overview.md:39` ("Each SRG becomes a separate Component" — SRG-as-basis
  only) and `:112-119` mapping table — add SRG-authoring rows and an
  "authoring an SRG vs authoring a STIG" section; this page also hosts the
  hierarchy diagram (it is the big-picture page).
- `field-requirements.md` — matrix is the STIG status vocabulary; add the SRG
  lifecycle matrix (from `fieldStateConfig`, the code source of truth).
- `export-requirements.md` — add the SRG publication model (full SRG XCCDF;
  different public/CUI semantics than STIG).
- `intent-form.md` — one paragraph: SRG authors are a different entry path
  than the vendor STIG intake.
- `vendor-stig-process-guide.md` — **do not hand-edit** (regenerated verbatim
  from DISA's DOCX); reference-only.

**5.4 Diagrams — CORE SRG → derived SRGs → STIGs (+ dual-lineage).** Format
options:
- **(a) Single PNG artifact** in `attachments/` (the existing
  `vendor-stig-process-milestones.png` pattern) rendered from a committed
  mermaid/`.mmd` source — displays identically in BOTH surfaces, one artifact,
  no drift. *Recommended.*
- (b) Mermaid fence — beautiful in VitePress, raw code block in-app.
- (c) Teach the in-app pipeline mermaid — real engineering (client lib in the
  pack + sanitizer interplay) for one page's diagrams; not warranted yet.

**5.5 Small fixes.**
- In-app 404: `vendor-stig-process-guide.md:10` links the DOCX with a leading
  slash; the controller rewrite (`disa_guide_controller.rb:62-65`) only matches
  relative `attachments/...` links → the download 404s in-app. Fix link or regex.
- User-guide touches: `user-guide/authoring-rules.md`, `user-guide/overview.md`,
  `user-guide/data-management/import-export.md`, `getting-started/quick-start.md`
  each need the SRG-kind branch mentioned (one section or paragraph each).

## 6. Decisions (Aaron, 2026-07-18)

1. **Per-kind entity noun: YES — kind-keyed.** SRG surfaces say "Requirement",
   STIG surfaces say "Rule" (DISA vocabulary); layers on top of the existing
   deployment-wide rename capability. (G11 → v2-0d2l.37)
2. **Revert for authored SRG rows: ENABLED** — parity; they are audited.
   (G10 → v2-0d2l.33.7)
3. **Compare/history kind-routing: THIS epic**, not the sync/merge epic.
   (→ v2-0d2l.33.8)
4. **Docs delivery: keep VitePress and EMBED the static build in the Rails
   app** (design-first), retiring the Commonmarker dual pipeline. Alternatives
   evaluated and rejected: Docusaurus/Starlight/MkDocs (migration cost, no
   embed advantage), Rails-native generators (reinvents nav/search/mermaid),
   SaaS docs (airgapped disqualifies). Diagrams become pure mermaid; the
   in-app DOCX-link 404 dies with the pipeline. (→ v2-0d2l.34.1)

## 7. Card structure (created 2026-07-18)

- **v2-0d2l.32.6** — comment kind-seam stragglers: duplicate guard + project
  comment decoration (G1+G2, sp:2) — under the triage-parity sub-epic.
- **v2-0d2l.33 [EPIC] SRG kind-seam completion** — `.33.1` one copy path
  (G3, sp:5; v2-0d2l.24 now depends on it) · `.33.2` spreadsheet update guard
  (G4, sp:2) · `.33.3` backup multi-parent round-trip (G5, sp:3, dep .20) ·
  `.33.4` destroy cleanup (G6, sp:2) · `.33.5` rules picker (G7, sp:3) ·
  `.33.6` in-component find (G8, sp:2) · `.33.7` revert parity (G10, sp:3) ·
  `.33.8` compare/history (sp:3) · `.33.9` SRG seed data (G13, sp:3) ·
  `.33.10` dead-code removal (G14, sp:2) · `.33.11` invariant cop incl. G15
  (sp:3, dep on the .33 fixers) · `.33.12` review-workflow mailer crash
  (G16, sp:1) · `.33.13` **independent dry-pass sweep — the epic's
  acceptance gate** (sp:3, dep on ALL .33 siblings; loop-until-dry: done
  only when a full fresh-agent round finds zero new gaps and the cop
  allowlist is exactly the blessed set).
- **Standalones:** v2-0d2l.35 RuleInput write-side variant (G9, sp:1) ·
  v2-0d2l.36 ruleArray helper + payload pin (G12, sp:2) · v2-0d2l.37
  terminology keying (G11, sp:3).
- **v2-0d2l.34 [EPIC] DISA Process documentation — SRG authoring** —
  `.34.1` VitePress embed, design-first (sp:5) · `.34.2` srg-authoring.md page
  (sp:3) · `.34.3` hierarchy diagrams (sp:2, dep .34.2) · `.34.4` staleness
  edits (sp:3) · `.34.5` user-guide touches (sp:2).

## 8. Non-goals

- No forking of the adjudication layer, comment gating, or export formatters —
  all deliberately kind-agnostic.
- No 3NF/database redesign; no changes to the satisfies graph, InSpec, or
  spreadsheet-import STIG-only semantics (they guard at the door instead).
- No sync/merge-engine kind work here (its own epic/PR).
