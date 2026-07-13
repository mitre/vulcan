# ADR: Dual-Version XCCDF Export — DISA-Style 1.1.4 and 1.2 From One Content Model

- **Status:** DRAFT v1 — proposed 2026-07-12 per Aaron (phone discussion with
  Will Dower). Awaiting Aaron's read + approval and Will's review.
- **Date:** 2026-07-12
- **Deciders:** Aaron Lippold (XCCDF/SCAP co-author; DISA SRG-author community).
- **Part of:** the larger SRG-Component initiative alongside
  `adr-srg-component-authoring.md` (epic `v2-0d2l`). **All of this lands on the
  same branch** (`feat/comment-triage-context-panel`). It may be carded as its
  **own epic** within that initiative (Aaron is carding the whole effort
  together) — separate epic, same branch. Split into its own ADR file for
  readability (the SRG ADR is already large); multi-parent derivation (SRG ADR
  §5/§0.14) surfaces here as reference/ident cardinality (§4.4).
- **Motivating goal (Aaron):** let Vulcan emit DISA-conformant XCCDF in **both
  1.1.4 (today) and 1.2**, from one content model, to help DISA move to 1.2.

## 0. Decisions (proposed — Aaron, 2026-07-12)

| # | Fork | Decision |
|---|---|---|
| 1 | Version support | Emit **DISA-style XCCDF in both 1.1.4 and 1.2**. Both outputs are DISA-style; the version is a selectable option, default **1.1.4** for back-compat. |
| 2 | Architecture | **One version-agnostic content model + a thin version profile (Strategy).** NOT a forked formatter, NOT a YAML mapping-engine (overkill for a 2-version DISA delta). Learn from cis-bench's config-driven engine; express it as a Ruby strategy. |
| 3 | The only per-version variance | **Namespace/schemaLocation + object-ID encoding.** Centralized in `format_id(type, raw)`. Everything else (groups, rules, checks, descriptions, references, idents) is identical across versions. |
| 4 | ID owner | Reverse-DNS owner for 1.2 IDs is **config** (default `mil.disa.stig`); authored SRG/STIG components may set their own. |
| 5 | Structured version/dates (#1) | **Add** native `<version time=…>` + `<status date=…>` **alongside** the DISA `plain-text` release-info. Additive; do not remove the plain-text (STIG Viewer parses it). |
| 6 | Satisfied-by relation (#2) | **`<requires idref>` in BOTH versions** as the canonical structural edge (a list → multi-parent native); idref encoding differs only via `format_id`. **Optional** typed `<metadata>`/`<dc:relation>` add-on. **Keep** the DISA mitigation/status-justification text. NOT metadata-instead-of-idref per version. |
| 7 | CCIs (#3) | Emit **one `<ident>` per CCI** (conformance fix). The current comma-joined single `<ident>` is the anomaly; multiple idents is what DISA tools expect. Straight replacement — no dual-phase. |
| 8 | Multi-parent (SRG/STIG) | Surfaces as **repeated `<reference>` (per parent SRG) + union of CCI `<ident>`s** — both `maxOccurs="unbounded"` in both versions. **Zero schema change.** |
| 9 | Migration posture | **Additive**; "phase out old" is **consumer-gated, not release-gated** — DISA display strings may stay indefinitely for 1.1.4/STIG-Viewer compat. |

## 1. Context

Vulcan's XCCDF exporter (`app/services/export/formatters/xccdf_formatter.rb`)
emits **XCCDF 1.1** today: namespace `http://checklists.nist.gov/xccdf/1.1`,
schemaLocation `xccdf-1.1.4.xsd` (L58–64), freeform object IDs
(`V-{prefix}-{rule_id}` group L94, `SV-…` rule L98, benchmark = `component[:name]`
L62), CCIs comma-joined into a single `<ident>` (`base_rule.rb:89`
`…map(&:ident).sort.join(', ')`), release info as a `plain-text` string (L82),
and lineage buried in the vuln-discussion text (`satisfaction_text`).

XCCDF 1.2 is the newer NIST standard. DISA STIGs are still published as 1.1.4.
Aaron (a co-author of XCCDF/SCAP and one of the ~4-person DISA SRG-author
community) wants Vulcan to emit DISA-conformant XCCDF in **both** versions so
Vulcan can help drive DISA's adoption of 1.2 — which requires the two outputs to
be the *same content* differing only where the standard actually differs.

The cis-bench project (`~/github/mitre/cis-bench`) already analyzed the
DISA-format-per-version differences and proved a config-driven approach
(MappingEngine + generic handlers; version is a config field). This ADR ports
that *insight* into Vulcan as a lightweight Ruby strategy.

## 2. The verified 1.1.4 ↔ 1.2 delta (evidence)

For DISA content the delta is **small and concentrated** — verified against the
schemas in `cis-bench/schemas/xccdf/`:

| Aspect | 1.1.4 | 1.2 | Source |
|---|---|---|---|
| Namespace / schema | `…/xccdf/1.1` + `xccdf-1.1.4.xsd` | `…/xccdf/1.2` | formatter L58–64 |
| Object IDs | freeform (`V-…`, `SV-…`) | `xccdf_[^_]+_{type}_.+` (schema-enforced) | `xccdf_1.2.xsd:806–872` |
| `<reference>` | `maxOccurs="unbounded"` | `maxOccurs="unbounded"` | both XSDs |
| `<ident>` | `maxOccurs="unbounded"` | `maxOccurs="unbounded"` | `xccdf_1.2.xsd:3359` |
| `<version>` | single, string | single + `@time` (dateTime), `@update` (URI) | `versionType` L638 |
| `<status>` | `@date`, repeatable | `@date`, repeatable | L518 |
| `<requires>` | idref list | `idrefListType` | L1120 |
| `<metadata>` | present (loose) | `metadataType` unbounded, `##other` lax + Dublin Core | L497–511, L1035 |
| tailoring | none formal | first-class `<Tailoring>` | — |

**Key finding:** a 1.2 DISA object ID is a **deterministic wrap** of the 1.1.4
ID (`SV-257777r…_rule` → `xccdf_mil.disa.stig_rule_SV-257777r…_rule`). All
idrefs (Profile `@idref`, `<requires>`, complex-check) wrap the same way. The
benchmark/group/rule/check/description content model is otherwise identical.

## 3. Decision (core): one content model + version profile + `format_id`

Introduce a version strategy; keep the ~200-line content model in one place:

```
Export::Xccdf::VersionProfile
  ├─ V1_1_4  namespace/schema = …/xccdf/1.1 ; format_id(type, raw) = raw
  └─ V1_2    namespace/schema = …/xccdf/1.2 ; format_id(type, raw) =
                "xccdf_#{owner}_#{type}_#{raw}"   # owner default 'mil.disa.stig' (config)

XccdfFormatter.new(version: profile)
  - builds Benchmark/Group/Rule/checks/descriptions ONCE (version-agnostic)
  - every id assignment, namespace, schemaLocation goes through `profile`
```

- **`format_id(type, raw)` is the single source of truth** for the 1.1.4→1.2 ID
  mapping — one auditable function (exactly what DISA needs to evaluate 1.2).
- Export gains an `xccdf_version` option (default `1.1.4`).
- Adding 1.2 becomes a ~40-line profile, not a forked formatter (DRY).

## 4. Enhancements bundled into this refactor

Done now because we are already rebuilding the exporter with one content model —
cheap now, expensive to retrofit later.

### 4.1 Structured version/dates (#1)
Add native `<version time="…">` and repeatable `<status date="…">` (draft →
interim → accepted history). **Keep** the DISA `plain-text` release-info string
(STIG Viewer parses it). Machine-readable win, especially for 1.2.

### 4.2 Satisfied-by as a native relation (#2)
`<requires idref="<parent-rule>">` in **both** versions — the native directional
dependency edge; it is a **list**, so a child satisfied by *several* parents is
native. The idref encoding is the only per-version difference (via `format_id`).
**Optionally** also emit a typed `<metadata>`/`<dc:relation>` (self-describing,
cross-benchmark-safe) — additive, more idiomatic in 1.2, never a per-version
*replacement* for idref. **Keep** the DISA mitigation/status-justification text
(that is DISA's own convention, Process Guide v4r1 §4.1.15). Applies to the
intra-component satisfaction case (parent rule in the same benchmark);
cross-component satisfaction, if any, uses `<metadata>` rather than idref.

### 4.3 CCIs get their own home (#3)
Emit **one `<ident system="…cci">CCI-…</ident>` per CCI** (split the DB `ident`
string on emit; longer-term store idents as a collection). This is a
**conformance fix** — real DISA STIGs use multiple `<ident>` elements; the
comma-joined single ident is the anomaly. Straight replacement, no dual-phase.

### 4.4 Multi-parent derivation (from the SRG-Component ADR)
A requirement deriving from N parent SRGs (e.g. Container SRG ← APP + OS core)
surfaces as **N `<reference>`** (one per parent SRG doc: `href` +
`dc:title`/`dc:publisher` = SRG-ID/version) and the **union of CCI `<ident>`s**.
Both are `maxOccurs="unbounded"` in both versions → **no schema change**. The
requirement's own STIG-ID/SRG-ID stays in its single `<version>`; parents are
references, not `@extends` (which is single-parent and unused for lineage).

## 5. Migration & back-compat

- **Additive first.** New structures (structured dates, `<requires>`,
  `<metadata>`, multi-`<ident>`, multi-`<reference>`) are added; existing DISA
  display forms are retained.
- **"Phase out old" is consumer-gated, not release-gated.** DISA display strings
  (plain-text release-info) may remain indefinitely for 1.1.4 / STIG-Viewer /
  SCC compatibility. Removal happens only after confirming no downstream
  consumer parses a given form — which for 1.1.4 display strings may be never.
- **Exception:** #3 (CCIs) is a bug fix, not a compatibility risk — multiple
  `<ident>` is *more* DISA-compatible than the comma-joined string, so it is a
  straight replacement.
- **Per-version posture:** 1.1.4 keeps DISA display conventions; 1.2 leans into
  the structured forms. The version profile can decide how much structure to
  emit per version.

## 6. Alternatives considered and rejected

- **Fork the formatter per version** — rejected: duplicates ~200 lines, drifts.
- **Port cis-bench's YAML MappingEngine** — rejected for Vulcan: heavy for a
  2-version DISA delta; a Ruby strategy captures the same insight (version =
  config, one content model) at a fraction of the surface.
- **Represent satisfied-by as `<requires>` in 1.1.4 but `<metadata>` in 1.2** —
  rejected: same relationship, two encodings per version, breaks the one-content-
  model principle and burdens consumers.
- **Structure the satisfied-by *instead of* the DISA text** — rejected: DISA's
  convention is deliberately text; the structured relation is additive, not a
  replacement.
- **Use `@extends` for lineage** — rejected: single-parent, wrong semantics.

## 7. Relationship to `adr-srg-component-authoring.md`

Both are part of the same SRG-Component initiative and land on the same branch
(`feat/comment-triage-context-panel`). That ADR owns SRG/STIG authoring and
multi-parent derivation (§0.14); this one owns how any component — STIG or
authored SRG — is *exported* as XCCDF, where multi-parent surfaces as
reference/ident cardinality (§4.4). They may be **separate epics** under the one
initiative (Aaron cards the whole effort together), not separate branches and
not detached concerns.

## 8. Open items / research

- **`<metadata>` typed satisfied-by shape** — exact element/namespace (Dublin
  Core `<dc:relation>` vs a `disa:`-namespaced element) — decide with Aaron;
  optional layer, not blocking.
- **Cross-component satisfaction** — confirm whether Vulcan `satisfied_by`
  (HABTM `rule_satisfactions`) ever spans components in export scope; if so,
  those use `<metadata>` (idref cannot cross benchmarks).
- **1.2 emit-shape validation** — diff Vulcan 1.2 output against a
  cis-bench-produced DISA 1.2 sample + validate against `xccdf_1.2.xsd`.
- **Vendor the XSDs** into Vulcan for round-trip validation tests (they live in
  `cis-bench/schemas/xccdf/`).

## 9. Testing strategy

- **Schema validation** both ways: every exported benchmark validates against
  `xccdf-1.1.4.xsd` (1.1.4 mode) and `xccdf_1.2.xsd` (1.2 mode).
- **`format_id` unit tests**: 1.1.4 passthrough; 1.2 wraps to
  `xccdf_{owner}_{type}_{raw}` and every idref resolves within the doc.
- **Content-parity test**: 1.1.4 and 1.2 outputs are structurally identical
  except namespace + id encoding (parse both, compare normalized trees).
- **Enhancement tests**: structured `<version time>`/`<status date>` present
  alongside plain-text; one `<ident>` per CCI; N `<reference>` for N parents;
  `<requires>` for satisfied-by (single + multi-parent).
- **DISA sample diff**: 1.1.4 output stays byte-compatible with the current
  exporter's shape (no regression to existing STIG-Viewer consumption).

## 10. Phasing (implementation children — carded post-approval)

1. Extract `VersionProfile` + `format_id`; make `XccdfFormatter` version-agnostic
   (1.1.4 output byte-identical to today). *No behavior change.*
   **Cross-ADR sequencing (2026-07-13):** this rebuild lands BEFORE the
   SRG-Component ADR's Phase-7 `Export::Modes::PublishedSrg` — that mode
   layers onto the rebuilt formatter, and the SRG ADR owns the
   `component.rules`-empty-for-SRG fetch fix (export base.rb:195) plus the
   guards on the three Rule-only `rule.satisfies` sites. One rebuild, not
   two independent rewrites of the same file.
2. Add `xccdf_version` export option + `V1_2` profile; schema-validate both.
3. #3 multi-`<ident>` CCIs (conformance fix).
4. #1 structured `<version time>`/`<status date>` (additive).
5. #2 `<requires>` satisfied-by (both versions) + optional `<metadata>`.
6. §4.4 multi-parent `<reference>`/ident union (aligns with SRG-Component
   multi-parent import).
