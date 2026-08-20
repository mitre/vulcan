# ADR: Publisher Tier & Field Governance — from "Advanced Fields" to an Authority Boundary

- **Status:** DECIDED v2 (Aaron, 2026-07-14) — every open item resolved
  by interview the same day the v1 draft landed: publisher role =
  membership capability; enforcement = model guards + 422; determination
  = dedicated record over the audited trail; approval = existing review
  machinery; the IA/CCI reference block is absorbed into the config as a
  declared readonly state. §3 is consumed immediately by the SRG
  initiative's field-config card; the governance build (§4–§5) is carded
  under this epic. Will reviews async — feedback folds in as revisions.
  v1 (same day): draft + three-lens cold-read (code-accuracy 10/10, two
  precision fixes).

> **Implementation status (2026-08-16).** Phase A (§3, the field-state
> config) SHIPPED: `app/javascript/composables/fieldStateConfig.js`
> holds the kind × status × tier model (`hidden`/`readonly`/`editable`,
> `TIERS = ["author","publisher"]`, `PUBLISHER_ONLY`), the interim
> `advancedMode → tier` mapping lives in `useRuleFormFields.js`, the
> retired `STATUS_FIELD_CONFIG` four-list shape is gone, and the
> `custom-display-check` bypass below is already deleted — the IA/CCI
> block renders through declared `readonly` states. The exported helpers
> are `buildFieldSets` / `resolveFieldStates` / `hasHiddenFields` (the
> singular `buildFieldSet` named below no longer exists). The
> governance build (§4–§5: publisher capability, model guards,
> determination record) is honestly NOT built yet. "Mechanically,
> today" below describes the pre-implementation shape and is kept as
> the historical record.
- **Date:** 2026-07-14
- **Deciders:** Aaron Lippold (all decisions, 2026-07-14 interview);
  Will Dower (the publisher/advanced-user framing originated in their
  discussion; async review)
- **Companion:** `adr-srg-component-authoring.md` §4.1 — the SRG
  lifecycle table that triggered this design and the first consumer of
  the §3 model.

## 1. Context

Vulcan's rule editor has an **Advanced Fields** checkbox ("Most users do
not need to modify advanced fields"). Mechanically, today
(`ruleFieldConfig.js`, `useRuleFormFields.js`):

- `STATUS_FIELD_CONFIG` gives each STIG status three field groups:
  `rule` and `disa` each carry `displayed`, `disabled` (rendered
  read-only), and additive `advancedDisplayed` / `advancedDisabled`
  lists; the `check` group carries only `displayed`/`disabled` (no
  advanced lists anywhere — `buildFieldSet` guards the absence).
- So a field already has three effective states — **hidden** (omitted),
  **visible read-only** (`disabled`), **editable** (`displayed`) — and
  "advanced" is an additive overlay that reveals more fields
  (e.g. `ia_controls`, `status_justification`, the DISA description
  extras for Applicable - Configurable).
- The toggle is **UX-only** for field submission: any author with editor
  permissions can submit any field regardless of the toggle. (Precision
  note, 2026-08-16: flipping the toggle's *state* is server-gated —
  `check_admin_for_advanced_fields` authorizes the `advanced_fields`
  param on component update — but no server check ties an individual
  field write to that state, which is the gap §4 closes.)
- Verified config-bypass (2026-07-14): the edit page renders an
  always-on **read-only** IA Control / CCI reference block
  (`RuleForm.vue:106-142` — `nist_control_family`/`ident` via
  `custom-display-check="() => true"`, which short-circuits the config
  check in `RuleFormGroup`) with Advanced Fields OFF. It is a display
  bypass, not an editability leak — the *editable* `ia_controls` and
  `ident` paths are correctly config-gated advanced-only
  (`DisaRuleDescriptionForm.vue`, RuleForm's Identity section). Notable:
  this hardcoded block is exactly the three-state model's `readonly`
  state, implemented as a template exception because the config cannot
  express it today.

The trigger: while designing SRG authoring, severity and CCI/IA-control
were decided to display **inherited** from the requirement's core
lineage, with editing reserved for a higher tier. That exposed what
"Advanced Fields" actually is: not a complexity filter, but an
**authority boundary**. Changing which CCI a requirement aligns to is a
benchmark-publisher determination — the kind of change DISA processes
track and approve — not day-to-day authoring. Vulcan has never modeled
that boundary; the checkbox approximates it without naming it, and the
STIG view does not implement it in a DRY or complete way.

## 2. Problem statement

1. "Advanced" conflates **field complexity** with **editing authority**.
2. The field-state mechanics (hidden / read-only / editable) exist but
   are spread across four config lists plus form hardcodes that can
   contradict them.
3. The SRG work is about to add a **document-kind** dimension to the
   same config. Restructuring now without the tier dimension means
   restructuring the same seam twice.
4. Publisher-class changes (CCI alignment, severity) are untracked as
   determinations — the audited gem records the value change, but
   nothing marks it as a governance event or routes it for approval.

## 3. Decision — the field-state config model (consumed by the SRG epic)

1. **Three states per field**: `hidden` | `readonly` | `editable`.
2. **Resolved by (document kind × status × editing tier)** in ONE source
   of truth — `FIELD_CONFIG_BY_DOCUMENT_TYPE` — replacing the
   `displayed`/`disabled`/`advancedDisplayed`/`advancedDisabled`
   four-list shape and the form hardcodes. STIG behavior is preserved by
   construction: the migrated STIG config must be provably equivalent to
   today's (spec-pinned), with any config-vs-form divergences resolved
   explicitly, not silently.
3. **Tier is a narrow per-field OVERLAY, not a parallel config.** Two
   tiers: `author` (default) and `publisher`. A field carries a tier
   override only where the tiers differ — expected to stay a
   one-or-two-field concern (severity, CCI/IA-control). Both
   author-facing shapes exist: *see-but-not-edit* (readonly to authors,
   editable to publishers) and *hidden-from-authors*. **Scale guard:**
   if tier overrides proliferate beyond a handful of fields, that is a
   signal the roles model needs revisiting — not a license for more
   overrides.
4. **Interim tier switch = today's Advanced Fields checkbox.** Until the
   publisher role exists (§4), toggling it selects the publisher tier,
   preserving current capability exactly. The checkbox label/copy is
   revisited when the role ships.
5. The model is **kind-agnostic machinery**: STIG and SRG differ only in
   config content (their status keys and field states), never in code
   paths.

## 4. Governance layer — publisher role (DECIDED 2026-07-14)

1. **Who is a publisher — DECIDED: a per-project membership
   capability**, granted alongside today's roles. Extends the existing
   membership/`effectivePermissions` structure (viewer/author/reviewer/
   admin) rather than adding a parallel system.
2. **Server-side enforcement — DECIDED: model guards + 422.** The
   models reject publisher-tier field changes from non-publishers;
   controllers surface the 422 toast — the same layered pattern as the
   admin-continuity guards. The current UX-only toggle is explicitly
   NOT a security boundary — that gap is acceptable only until this
   ships.
3. **Scope of enforcement at introduction**: SRG components only at
   first (where inherited severity/CCI lands), extending to STIG-kind
   publisher fields after the STIG config migration is verified.

## 5. Governance layer — tracking + approval (DECIDED 2026-07-14)

1. **Determination tracking — DECIDED: a dedicated determination
   record** (field, from, to, **required rationale** enforced at the
   model, actor, requirement, and the approving review) layered on the
   existing audited trail. The audit row is the forensic proof of the
   value change; the determination row carries the queryable governance
   semantics and feeds release changelogs. Rationale for the shape:
   `audited` serializes changes (not built for domain queries); the
   queryable-domain-event pattern (cf. GitLab's migration from
   system-note parsing to dedicated resource-event tables) and Vulcan's
   own relocation-as-first-class-record decision both point the same
   way. Rejected: audit-comment-only (unqueryable at report time);
   Review-as-the-record (overloads commenting with governance — the
   `Moved`-as-status class of mistake).
2. **Approval flow — DECIDED: reuse the existing review machinery.**
   A determination is what's under review; the record links the
   approving review. No new workflow system.
3. **Export/report surface**: determinations feed release changelogs
   ("CCI alignment changed for N requirements") — emit shape decided
   with the release work.

## 6. Alternatives considered and rejected

- **Parallel per-tier configs** (a full author config + a full publisher
  config): duplicates every status table for a one-or-two-field
  difference; drift-prone — rejected for the overlay.
- **Build the role/enforcement now, with the SRG field config**: couples
  an auth-model change to an already-large initiative and threatens the
  Container SRG acceptance goal; the interim checkbox preserves today's
  capability with zero new risk — rejected for phasing.
- **Keep the four-list config shape and bolt kind on top**: preserves
  the complexity/authority conflation and leaves the form hardcodes as
  a second source of truth — rejected; the restructure is the point.

## 7. Phasing (all carded 2026-07-14; build order sequenced by Aaron)

- **Phase A (inside the SRG epic's field-config card):** the §3 model —
  three-state config keyed by kind × status × tier, STIG equivalence
  spec, hardcode retirement, interim checkbox mapping, AND absorbing the
  IA/CCI reference block into the config as a declared `readonly` state
  (delete the `custom-display-check` bypass — decided 2026-07-14).
- **Phase B (this epic):** publisher membership capability + model-guard
  enforcement with 422 surfacing (§4).
- **Phase C (this epic):** determination records + review-machinery
  approval + changelog feed (§5). Depends on B.

## 8. Open items — ALL DECIDED (Aaron, 2026-07-14)

1. Publisher role: **membership capability** (§4.1).
2. Enforcement: **model guards + 422** (§4.2).
3. Determination record: **dedicated record over the audited trail**
   (§5.1).
4. Approval: **existing review machinery** (§5.2).
5. IA/CCI reference block (`RuleForm.vue:106-142`): **absorbed into the
   config as a declared `readonly` state**; the `custom-display-check`
   bypass is deleted in Phase A.
