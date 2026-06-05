# Vulcan v2.x Release Roadmap

> **For agentic workers:** Use this plan to understand release boundaries and sequencing. Each tier has a clear gate — do NOT start a later tier before the current tier's gate is met.

**Goal:** Ship correct, architecturally sound releases with clear boundaries between correctness, foundation, capability, and platform work.

**Current state:** v2.3.7 released. Branch `feat/comment-triage-context-panel` is 350 commits ahead with callback stabilization (19 cards), 3 Eugene bug fixes, 35 spec file splits, test-prof infrastructure, and documentation.

**Analysis sources:**
- 8-agent API completeness swarm (2026-06-05): `docs/research/2026-06-05-api-completeness-analysis.md`
- 6-agent Vue consolidation LOE (2026-06-05): `docs/research/2026-06-05-vue-consolidation-loe.md`
- 8-agent MergeAnalyzer expert review (2026-06-05): `docs/superpowers/plans/2026-06-05-v2-480.1-expert-review.md`

---

## Tier 1: Correctness — v2.3.8 patch

**Principle:** The app must be correct before we add anything. Ship bug fixes, security patches, and production data cleanup.

**Release gate:** All existing features work correctly. No security leaks. Production data is clean. Test suite is solid. Zero known regressions.

### Already done (on branch, needs merge to master)

| Work | Cards | Status |
|------|-------|--------|
| Callback stabilization — defensive callbacks, FK constraints, intent registry | v2-05f.68 (19 cards) | DONE |
| Eugene bug: fixtext parent-in-child | v2-05f.67 | DONE |
| Eugene bug: status getter/setter cascade | v2-05f.70 | DONE |
| Eugene bug: reopen bypass for terminal statuses | (gap tests) | DONE |
| Spec infrastructure: let_it_be refind:true global | rails_helper.rb | DONE |
| Spec infrastructure: custom RuboCop cop Vulcan/LetItBeRefind | .rubocop.yml | DONE |
| Spec infrastructure: climate_control for ENV isolation | Gemfile | DONE |
| Spec monolith splits: 4 files → 35 domain files | spec/ | DONE |
| Callback design decision documentation | docs/development/state-management.md | DONE |
| test-prof profiling documentation | docs/development/testing.md | DONE |
| SatisfiedByBlueprint component_prefix | app/blueprints/ | DONE |

### Remaining work for v2.3.8

| # | Card | What | Est | Priority |
|---|------|------|-----|----------|
| 1 | v2-btu.29 | Fix UserBlueprint admin view — replace raw .as_json (SECURITY) | ~12 min | P0 |
| 2 | v2-btu.30 | Fix raw .to_json leaks — Project in HAML, User in Devise (SECURITY) | ~12 min | P0 |
| 3 | v2-btu.34 | Dead route cleanup + Jbuilder deprecation | ~8 min | P2 |
| 4 | v2-05f.69.1 | Production data cleanup — 826 ADNM rules rake task | ~12 min | P0 |
| 5 | v2-71q | OIDC provider conflict fix | TBD | P0 |

**Total remaining: ~45 min Claude-pace + OIDC (TBD)**

### Merge strategy

The branch has 350 commits. Options:
- **Squash merge** — one commit on master, clean history, loses per-card granularity
- **Rebase merge** — preserves all 350 commits, noisy history
- **Topic merge** — group into ~5-8 logical merge commits (recommended)

### v2.3.8 release checklist

- [ ] Security fixes (.29, .30) complete
- [ ] Dead route removed (.34)
- [ ] Production data rake task ready (.69.1)
- [ ] OIDC fix verified (.71q)
- [ ] Full suite green (bin/parallel_rspec + yarn test:unit)
- [ ] RuboCop + ESLint clean
- [ ] OpenAPI spec lint clean
- [ ] Merge to master
- [ ] Tag v2.3.8
- [ ] Deploy + run production data cleanup rake task

---

## Tier 2: Navigation Foundation — v2.4.0 minor

**Principle:** Architecture must be correct before building on it. Remove Turbolinks, add Vue Router, establish the 4 foundational API endpoints that every SPA page needs.

**Release gate:** URLs work for rule selection. Browser back/forward works. Deep linking works. The 4 API foundation endpoints exist. Pages CAN fetch their own data via API (even if most still use HAML injection).

**Depends on:** Tier 1 merged to master.

| # | Card | What | Est | Blocked by |
|---|------|------|-----|------------|
| 1 | v2-9k7.1 | Remove Turbolinks — mechanical 31-file migration | ~15 min | nothing |
| 2 | v2-9k7.2 | Add Vue Router 3 — per-page rule selection routing | ~25 min | .1 |
| 3 | v2-9k7.3 | Build useRuleSelectionStore — Pinia synced with router | ~20 min | .2 |
| 4 | v2-9k7.5 | Adopt Vue Router test helpers | ~15 min | .2 |
| 5 | v2-9k7.4 | Migrate 16 navigation callsites | ~15 min | .3 |
| 6 | v2-btu.9 | SPA auth: GET /api/auth/me + POST login + DELETE logout | ~20 min | nothing |
| 7 | v2-btu.24 | GET /api/settings (pre-auth UI config) | ~12 min | nothing |
| 8 | v2-btu.25 | GET /api/navigation + access_requests | ~12 min | .6 |
| 9 | v2-btu.26 | effective_permissions in project/component responses | ~12 min | nothing |
| 10 | v2-05f.71 | SatisfiedByIndicator wired to Vue Router | ~10 min | .2 |

**Total: ~155 min Claude-pace (~2.5 hours)**

### v2.4.0 release checklist

- [ ] Turbolinks fully removed (no turbolinks imports, no vue-turbolinks)
- [ ] Vue Router installed in all relevant packs
- [ ] Rule selection uses URL params (browser back/forward works)
- [ ] GET /api/auth/me returns current user
- [ ] GET /api/settings works without auth
- [ ] GET /api/navigation works with auth
- [ ] effective_permissions in project/component JSON
- [ ] SatisfiedByIndicator navigates via router
- [ ] Full suite green
- [ ] Tag v2.4.0

---

## Tier 3: Capability — v2.5.0+ minors

**Principle:** Each epic is independently shippable. No dependency ordering between them. Pick based on user need.

**Depends on:** Tier 2 complete.

| Epic | What | Cards | Est | Independent? |
|------|------|-------|-----|-------------|
| v2-btu Phase 2-5 | Admin namespace, Find & Replace, pagination, Blueprint cleanup | ~30 | ~4h | Yes |
| v2-480 | Merge engine (Will's MergeAnalyzer) | ~11 | ~3h | Yes |
| v2-8ea + v2-dd5 | Test infrastructure hardening | ~22 | ~2.5h | Yes (quality, no UI change) |
| v2-gsw | InSpec service extraction | 4 | ~1h | Yes |
| v2-05f.20 | Component search modal (Cmd+K) | TBD | TBD | Yes |
| v2-56p | Import/export gaps (replace mode) | TBD | TBD | Yes |
| v2-fad | Dark mode polish | ~5 | ~1h | Yes |
| v2-k96 | DISA guide system | ~6 | ~1.5h | Yes |

**Recommended priority within Tier 3:**
1. **Test hardening (v2-8ea)** — increases confidence in everything else
2. **API Phase 2 (admin namespace)** — needed for admin page migration
3. **Merge engine (v2-480)** — Will is working this, parallel track
4. **Everything else** — based on user demand

---

## Tier 4: Platform Migration — v3.0

**Principle:** Don't start until Tier 2 is solid and at least some Tier 3 features are shipped. This is a build-system swap, not a rewrite.

**Depends on:** Tier 2 complete + API surface sufficiently filled.

| Phase | What | Depends on | LOE |
|-------|------|-----------|-----|
| 4a | Port v3.x Pinia stores (13) to v2.x | Vue Router exists (Tier 2) | ~2h |
| 4b | Port v3.x composables (31) to v2.x | Stores ported + API endpoints exist | ~3h |
| 4c | Bootstrap 4→5 migration (371 usages) | Independent but massive | ~20-40h |
| 4d | Consolidate 24 Vue instances → 1 SPA | 4a + 4b + 4c all done | ~8h |
| 4e | Vue 2.7 → Vue 3 | 4c done (Bootstrap 5) | ~4h |

**Key insight from consolidation swarm:** v2.x is 60% Vue 3 compatible. The stores and composables port directly (pure composition API). Route structure is identical (20-line factory swap). Bootstrap 4→5 is the actual blocker (371 component usages), not the SPA architecture.

**Decision cards (evaluate before starting):**
- v2-dyh: Evaluate consolidation cost/benefit
- v2-llq: Scope Bootstrap 4→5 migration
- v2-b47: Document v2.x-only features for preservation
- v2-aiz: Assess v3.x artifact portability
- v2-e1v: Plan Pinia migration order

---

## Anti-patterns

- **Do NOT start Tier 3/4 work before Tier 1 is merged** — features built on broken foundations get rebuilt
- **Do NOT build on Turbolinks** — every feature built before Tier 2 has to be rewired
- **Do NOT start Bootstrap 5 migration before Vue Router is solid** — migration touches every component
- **Do NOT port v3.x Vue components** — they use Bootstrap 5 (371 rewrites). Port stores/composables only.
- **Do NOT consolidate Vue instances before stores are ported** — the SPA needs Pinia for state management

## Key metrics

- 183 open cards across ~15 epics
- 350 commits ahead of v2.3.7 on current branch
- v2.x API surface: 46% compatible with v3.x, 25% partial, 29% missing
- v3.x portability: stores (100%), composables (100%), routes (100%), components (0% — Bootstrap 5 blocker)
- Estimation calibration: estimates run ~30% high vs actuals (sp:1=5m, sp:2=7m, sp:3=11m, sp:5=18m)
