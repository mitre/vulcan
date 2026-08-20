# SRG Triage Parity — folding SRG components into the public-comment triage system

**Status:** scoping / design (orientation pass 2026-07-17)
**Relates to:** `docs/decisions/adr-srg-component-authoring.md` (the SRG kind seam:
`Component#document_type`, `Component#requirements`, `SrgRule` as an expanded
`BaseRule`). This doc applies that seam to the triage/public-comment surface.

## 1. Problem

The public-comment triage system (review → triage → adjudicate → disposition
export, plus the split-pane UX) was built for **STIG** components. SRG components
(authored SRGs) are a first-class document kind and, per the SRG ADR, draft SRGs
**do** take public comment — so triage must work for them too, or the SRG
capability is not feature-complete. This is not a request to build a second
triage system; it is to make the **one** triage system kind-aware at the seams
it already has.

## 2. The system decomposes into three layers

Kind-awareness lands cleanly and differently in each:

### Layer 1 — Adjudication workflow (kind-AGNOSTIC by nature)
The `Review` model's `TRIAGE_STATUSES` (`pending / concur / concur_with_comment /
non_concur / duplicate / informational / needs_clarification / withdrawn /
addressed_by`), `ACTION_PERMISSIONS`, the JS vocabulary
(`app/javascript/constants/triageVocabulary.js`), the decision UX
(`CommentTriageForm`, `BulkTriageBar`), and comment enablement
(`Component#accepting_new_comments?` / `#frozen_for_writes?`, which key on
`comment_phase`, not on kind) are all **the DISA public-comment process** —
identical for STIG and SRG.

**Design rule: do NOT fork this layer.** No SRG-specific triage statuses, no
parallel adjudication vocabulary, no kind branch in the decision UX. Forking it
is the anti-pattern; keeping it single is the DRY win.

### Layer 2 — Requirement-scoped queries (must route through the kind seam)
"Which requirements' comments belong to this component" must use the
kind-agnostic primitive, because SRG components store requirements as `SrgRule`,
not `Rule`:

- **Primitive:** `Component#requirements` (`component.rb` —
  `document_type == 'srg' ? authored_srg_rules : rules`) and
  `BaseRule.live_for_components(component_ids)` (`base_rule.rb`). Both return
  **all** requirements regardless of kind.
- **Already migrated:** `Comment​QueryService` (the triage table) uses
  `BaseRule.live_for_components` with an explicit comment
  (`comment_query_service.rb:41` — *"the Rule STI association excludes authored
  SrgRules, emptying the triage table for SRG-kind"*). The triage table already
  works for SRG.

### Layer 3 — Requirement-context rendering (must be kind-aware)
What the triage panel shows about the requirement being commented on — its own
status and fields — differs by kind (SRG lifecycle NYD → Applicable/NA/Moved vs
the STIG status set). The seam already exists: `RuleContextPanel.vue` accepts a
`document_type` prop (validated `["stig","srg"]`) and drives its fields through
`fieldStateConfig` / `ruleFieldConfig` — the same kind-aware config the rule
editor uses.

## 3. The centralization invariant

**No requirement-scoped triage/comment/export code queries `Rule` (or
`component.rules`) directly — always `Component#requirements` /
`BaseRule.live_for_components`.** `Rule` is the STIG STI subclass; using it
silently drops SRG requirements. On the render side, `fieldStateConfig` is
already the single source of truth for kind × status × field visibility — every
surface that renders a requirement threads `document_type` into it.

A guard spec that greps the triage/comment/export paths for
`Rule.where(component_id:` (and `component.rules` in comment/disposition code)
keeps the hardcoding from being reintroduced.

## 4. Verified gaps (2026-07-17, file:line)

**Backend — one real bug (Layer 2):**
- `app/lib/disposition_matrix_export.rb:89, 220, 238` query
  `Rule.where(component_id:)` → returns empty for SRG components → **the
  disposition export silently omits every SRG requirement's comments.** Latent
  until an SRG component takes public comment. Fix: route through
  `BaseRule.live_for_components` (mirror `comment_query_service`).

**Frontend — one threading gap (Layer 3):**
- `app/javascript/components/triage/TriageSplitView.vue:44` passes eight props
  to `RuleContextPanel` but **not `document-type`**, so the panel falls back to
  its `"stig"` default and renders STIG field config for SRG requirements.
  `ProjectComponent.vue:89` already has `component.document_type`;
  `TriageSplitView` just needs to receive and forward it. Completes the explicit
  TODO at `RuleContextPanel.vue:188`.

**Already kind-agnostic / handled (no work):** the triage-table query
(`comment_query_service`), comment enablement (`comment_phase`), the adjudication
vocabulary, and `TriageRuleSidebar` (already renders `srgInfo`).

**To verify during the work (not yet confirmed):**
- `addressed_by` under SRG multi-parent / relocation: `addressed_by_rule` is a
  kind-agnostic `BaseRule` FK, but the "addressed by parent" walk interacts with
  relocation semantics — confirm it holds for SRG components.
- The triage status badge and any other triage surface that renders a
  requirement's own status — confirm kind rendering.

**Out of scope here (separate cards):** SRG XCCDF export (`export/base.rb:201`
uses `component.rules`) and component compare/diff (`components_controller.rb`
compare paths use `.rules`) are their own kind-awareness cards, not triage.

## 5. Plan — three workstreams

1. **Backend — route disposition export through the kind seam.** Replace the
   `Rule.where(component_id:)` sites in `disposition_matrix_export` with
   `BaseRule.live_for_components`; add the anti-regression guard spec for the
   triage/comment/export paths. Live-verify disposition export for an SRG
   component includes its requirements' comments.

2. **Frontend — thread `document_type` through the triage surfaces.** Receive
   `document_type` in `TriageSplitView` and forward it to `RuleContextPanel`;
   confirm the panel renders SRG field config/status; make the status badge
   kind-aware if needed. Playwright the SRG triage panel.

3. **Acceptance — full SRG-component triage walkthrough.** Comment → triage →
   adjudicate → disposition export on a real SRG component, proving parity with
   STIG. This is the feature-complete gate; it depends on (1) and (2).

**Dependencies:** the SRG status model + field config (done) and the multi-parent
schema (done) are prerequisites for kind-aware rendering. This workstream does
not block core SRG authoring, so it slots into the epic's later "prove the model
/ feature-complete" phase and can proceed in parallel with the parent-set /
currency cards.

## 6. Non-goals

- Do not fork the adjudication layer (Layer 1) — one triage workflow for all kinds.
- Do not change comment-period gating — it is already kind-agnostic.
- Do not fold in SRG XCCDF export or component compare — separate kind cards.

## 7. Tracking

Carded as a sub-epic of the SRG-authoring epic, five children (all sp:2–3):
backend kind-seam routing + guard, frontend `document_type` threading, frontend
requirement surfaces, `addressed_by` verification, and the end-to-end acceptance
walkthrough (the gate, blocked by the other four). Depends on the SRG status
model + field config and the multi-parent schema (all landed). See the beads
board for ids and live status.
