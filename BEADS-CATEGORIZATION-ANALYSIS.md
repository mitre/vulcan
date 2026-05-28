# Beads Issue Categorization: v2.x / shared / v3.x

**Date**: 2026-02-08
**Total Issues Analyzed**: 50 open beads issues

## Summary

| Category | Count | Description |
|----------|-------|-------------|
| **v2.x** | 18 | Work for Vue 2.7 / Bootstrap-Vue / Rails current codebase |
| **shared** | 8 | Standards, docs, backend work applying to both versions |
| **v3.x** | 24 | Work for Vue 3 / Bootstrap 5 / SPA migration |

---

## Full Categorization Table

| ID | Title | Current Tag | Proposed Tag | Reasoning |
|---|---|---|---|---|
| vulcan-clean-c02 | BUG: Session timeout not working after remember-me fix | none | [v2.x] | Bug fix: session timeout in v2.2.x |
| vulcan-clean-chx | Severity override missing justification field | none | [v2.x] | Bug fix: severity override field in RuleForm (v2.2.x) |
| vulcan-clean-8et | Fix file picker: typo + missing CSV accept | none | [v2.x] | Bug fix: file picker in NewComponentModal (v2.2.x) |
| vulcan-clean-2ce | EPIC: Import/Export Round-Trip Gaps | none | [v2.x] | EPIC: Import/export bugs affect v2.2.x release |
| vulcan-clean-dzg | Tests: import/export round-trip fidelity | none | [v2.x] | Tests for current import/export system |
| vulcan-clean-bru | CSV header alignment: export headers != import headers | none | [v2.x] | CSV header bug in current system |
| vulcan-clean-5bh | EPIC: Unify Command Bar and Filter Bar between View/Edit pages | none | [v2.x] | DRY: CommandBar/FilterBar used in v2.2.x (ComponentCommandBar, RuleCommandBar) |
| vulcan-clean-e30 | Standardize ProjectComponents page layout to match edit/view screens | none | [v2.x] | Layout standardization: ProjectComponents page (v2.2.x) |
| vulcan-clean-mtx | Backport shared STIG/SRG page layout from v2.3.0 | none | [v2.x] | Backport STIG/SRG layout from v3 to v2.x (forward-port candidate) |
| vulcan-clean-8t5 | Split view/edit Rule command bar into stacked sections | none | [v2.x] | Refactor RuleActionsToolbar (v2.2.x component) |
| vulcan-clean-f4z | Auth: Don't merge accounts by email - keep providers separate | none | [v2.x] | Auth bug: provider merging (Rails/Devise) |
| vulcan-clean-w5n | Docker env defaults and admin bootstrap | none | [v2.x] | Docker env and admin bootstrap (infrastructure) |
| vulcan-clean-649 | Implement lazy InSpec control generation (hybrid approach) | none | [v2.x] | InSpec control generation (Rails model concern) |
| vulcan-clean-9du | InSpec import: no path to import existing profiles | none | [v2.x] | InSpec import feature (new backend feature) |
| vulcan-clean-b3q | Audit v2.2.x for syntax highlighting consistency (DRY) | none | [v2.x] | Syntax highlighting audit of v2.2.x (EasyMDE/Shiki) |
| vulcan-clean-ibo | Unify password complexity requirements across frontend/backend | none | [v2.x] | Password complexity unification (Devise + Vue 2) |
| vulcan-clean-buw | EPIC: v2.2.2 Polish Sprint | none | [v2.x] | EPIC: v2.2.2 polish sprint (import/export, bugs, DRY) |
| vulcan-clean-ze9.6 | Clean up lint warnings (275) | none | [v2.x] | Lint cleanup: current codebase warnings |
| vulcan-clean-ipj | DEVELOPMENT-STANDARDS: Hub Card (Always Read First) | none | [shared] | Development standards hub (applies to all work) |
| vulcan-clean-c7f | STANDARD: Code Quality Workflow | none | [shared] | Code quality workflow standard (applies to both) |
| vulcan-clean-02r | STANDARD: Vue2→Vue3 Migration Pattern with TDD | none | [shared] | Vue2→Vue3 migration pattern (applies during transition) |
| vulcan-clean-e3n | PATTERN: Vue3 ShowPage Migration (benchmarks/stigs/srgs) | none | [shared] | Vue3 ShowPage pattern (reference for both v2/v3) |
| vulcan-clean-r4d | Docs: Sync all VitePress docs with codebase state | none | [shared] | Docs sync (covers both v2.x and v3.x architecture) |
| vulcan-clean-kpq | Search quality testing: ambiguity, common patterns, fuzzing | none | [shared] | Search quality testing (feature exists in both v2/v3) |
| vulcan-clean-xnz | Add JSON response test coverage for all controllers | none | [shared] | JSON response test coverage (Rails backend, applies to both) |
| vulcan-clean-og4 | Audit: Controller response pattern inconsistencies | none | [shared] | Controller response audit (Rails backend, applies to both) |
| vulcan-clean-ze9 | v2.3.0 Stabilization | none | [v3.x] | v2.3.0 Stabilization (rename to v3.0.0) |
| vulcan-clean-o57 | Migrate Login/Auth to SPA with TDD | none | [v3.x] | Login SPA migration (Vue 3 + new architecture) |
| vulcan-clean-aj5 | Fix HTML-only controller responses for SPA consistency | none | [v3.x] | Fix HTML-only controllers for SPA (needed for v3.x SPA) |
| vulcan-clean-l4o | Requirements Editor Phase 2.x: NIST Family Grouping | none | [v3.x] | EPIC: Phase 2.x NIST grouping (Vue 3 SPA editor) |
| vulcan-clean-l4o.1 | Backend: Add nist_family field to rule serializer | none | [v3.x] | Backend for NIST grouping (Phase 2.x) |
| vulcan-clean-l4o.2 | useRequirementsGrouping composable | none | [v3.x] | Composable for NIST grouping (Vue 3 Composition API) |
| vulcan-clean-l4o.3 | Group by dropdown in toolbar | none | [v3.x] | Group by dropdown (Phase 2.x feature) |
| vulcan-clean-l4o.4 | Collapsible group headers with progress | none | [v3.x] | Collapsible headers (Phase 2.x feature) |
| vulcan-clean-l4o.5 | Group progress indicators per NIST family | none | [v3.x] | Group progress indicators (Phase 2.x feature) |
| vulcan-clean-laz | Requirements Editor Phase 2: Focus View Refactor | none | [v3.x] | EPIC: Phase 2 Focus View refactor (Vue 3 SPA) |
| vulcan-clean-laz.1 | FocusHeader.vue - Smart header with progress and nav | none | [v3.x] | FocusHeader (Vue 3 component) |
| vulcan-clean-laz.2 | EditorField.vue - Reusable field container | none | [v3.x] | EditorField (Vue 3 component) |
| vulcan-clean-laz.3 | FieldExpandModal.vue - Full-screen field editing | none | [v3.x] | FieldExpandModal (Vue 3 component) |
| vulcan-clean-laz.4 | SlideoutPanel.vue - Slideout infrastructure | none | [v3.x] | SlideoutPanel with Reka UI (Vue 3 + new UI lib) |
| vulcan-clean-laz.5 | useKeyboardNav composable - j/k navigation | none | [v3.x] | Keyboard nav composable (Vue 3 Composition API) |
| vulcan-clean-1w0.4 | Review status indicator in Focus View header | none | [v3.x] | Review indicator in Focus View (Phase 2.x) |
| vulcan-clean-8lt.5 | Update rules.store.ts with lock actions | none | [v3.x] | Lock actions in rules store (Vue 3 store pattern) |
| vulcan-clean-7k6.8 | Smart satisfaction suggestions from reference | none | [v3.x] | Smart satisfaction suggestions (Phase 2.x feature) |
| vulcan-clean-4vj | Editor2 Experiment: Bootstrap 5 + Frontend Design Skill | none | [v3.x] | Editor2 experiment (Bootstrap 5 + Vue 3) |
| vulcan-clean-xzy | Find & Replace: Frontend Refactor | none | [v3.x] | Find & Replace frontend refactor (Vue 3 store pattern) |
| vulcan-clean-aga | Performance Optimization: Frontend Updates | none | [v3.x] | Performance optimization (Vue 3 store pattern) |
| vulcan-clean-aga.4 | Test performance targets (<500ms load, <200ms focus) | none | [v3.x] | Performance targets for v3.x SPA |
| vulcan-clean-efx | DRY: Button standardization across UX | none | [v3.x] | Button standardization for Bootstrap 5 redesign |
| vulcan-clean-a5i | DRY: Typography standardization across UX | none | [v3.x] | Typography standardization for Bootstrap 5 redesign |

---

## Issues Requiring Title Changes

### 4 Issues with "v2.3.x" or "Phase 2.x" nomenclature → need [v3.x] tag

1. **vulcan-clean-ze9**: `v2.3.0 Stabilization`
   - Should be renamed: `[v3.x] v3.0.0 Stabilization`

2. **vulcan-clean-mtx**: `Backport shared STIG/SRG page layout from v2.3.0`
   - Actually a v2.x backport (forward-port candidate)
   - Should be: `[v2.x] Backport shared STIG/SRG page layout from v3.0.0`

3. **vulcan-clean-l4o**: `Requirements Editor Phase 2.x: NIST Family Grouping`
   - Should be: `[v3.x] Requirements Editor Phase 2.x: NIST Family Grouping`

4. **vulcan-clean-laz**: `Requirements Editor Phase 2: Focus View Refactor`
   - Should be: `[v3.x] Requirements Editor Phase 2: Focus View Refactor`

---

## Categorization Rules Applied

### v2.x Criteria
- Work applies to current Vue 2.7 / Bootstrap-Vue / Rails codebase
- Includes: bug fixes, DRY refactoring of existing components, import/export fixes, docker fixes, auth fixes
- References existing component names: RuleList, RuleOverview, ProjectComponent, ComponentCommandBar, etc.
- Forward-port candidates (backports from v3 to v2.x)

### v3.x Criteria
- Work requires or is specifically for Vue 3 / Bootstrap 5 / SPA migration
- Includes: Vue3 migration patterns, Nuxt/SPA work, Bootstrap 5 redesign, new editor experiments
- Phase 2.x work (assumes Vue 3 SPA architecture)
- Reka UI, new store patterns, composables with Composition API

### shared Criteria
- Meta/standards cards that apply to both versions
- Work done in v2.x and forward-ported to v3.x
- Includes: dev standards, code quality workflows, documentation, Rails backend audits

---

## Next Steps

1. Tag all 50 issues with appropriate version tags using `bd update`
2. Rename 4 issues that reference v2.3.x or Phase 2.x
3. Create filtered views:
   - `bd list --filter="[v2.x]"` for v2.2.x work
   - `bd list --filter="[v3.x]"` for v3.0.0+ work
   - `bd list --filter="[shared]"` for cross-version work

---

## Analysis Notes

- **None of the 50 issues currently have version tags in their titles**
- All tags need to be added from scratch
- The 4 "Phase 2.x" issues were incorrectly scoped for v2.2.x but are actually v3.x work
- DRY work (Button/Typography standardization) targets Bootstrap 5 redesign, not current Bootstrap 4 → v3.x
- Import/export round-trip gaps affect v2.2.x release → must be v2.x priority
- Controller response audit and JSON test coverage are backend work applying to both versions → shared
