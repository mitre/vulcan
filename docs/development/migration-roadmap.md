# Migration Roadmap: Rails+HAML → Rails API + Composable Vue SPA

This document describes the incremental migration of Vulcan from a Rails server-rendered app with 14 separate Vue instances to a Rails API-only backend with a composable Vue SPA frontend.

**Guiding principle:** Every step ships working software. No big-bang rewrites. Each system migrates independently through the same pipeline. The comment system (v2-05f.62) is the reference implementation — every subsequent migration follows the same pattern.

## Architecture: Today → Destination

```
TODAY (v2.x)                              DESTINATION
──────────                                ───────────
Rails MVC + HAML views                  → Rails API-only (JSON endpoints)
14 separate esbuild packs               → Single SPA bundle (or 2-3 lazy chunks)
Each pack = own Vue + Pinia instance    → One Vue app, one Pinia, Vue Router
Options API + 15 mixins                 → Composition API + composables
Direct API calls scattered in components→ Pinia stores (data) + composables (behavior)
Snake_case in templates                 → camelCase normalized throughout
Turbolinks page transitions             → Vue Router SPA navigation
Bootstrap-Vue 2.x (Vue 2)              → Bootstrap 5 native or Reka UI (Vue 3)
```

## The Migration Pipeline

Every system goes through these phases in order. The comment system proved this pipeline works.

### Phase A: API Layer
**Status:** Mostly done. `app/javascript/api/` has domain-specific modules.

- One file per Rails resource (`reviewsApi.js`, `componentsApi.js`, etc.)
- Pure HTTP calls via `baseApi.js` (ky client)
- CSRF token injection, 401 redirect, error normalization
- No state, no caching, no business logic

**What's left:** Some endpoints still called inline from components (check each system).

### Phase B: Pinia Store
**Pattern:** `app/javascript/stores/{domain}.js`

Each store:
1. Imports from the API layer (Phase A)
2. Manages cache with deterministic keys
3. Normalizes API responses (spread-then-override for incremental camelCase migration)
4. Exposes fetch, mutation, and invalidation methods
5. Shares `fetchAndNormalize` DRY helper for fetch boilerplate
6. Manual `$reset()` for Turbolinks page transitions
7. `acceptHMRUpdate` for dev experience

**Reference:** `stores/comments.js` — fetch (cached + uncached variants), post, triage, bulk triage, cache invalidation.

### Phase C: Composables
**Pattern:** `app/javascript/composables/{domain}/use{Action}.js`

Each composable:
1. Wraps store actions with local `submitting`/`submitError` refs
2. Provides UI-friendly loading state (per-operation, not global)
3. Returns refs + functions — consumed via `setup()` in components

**Reference:** `composables/mutations/useCommentComposer.js`, `useCommentTriage.js`

### Phase D: Consumer Migration
**Pattern:** Component adds `setup()`, replaces direct API imports with store/composable.

Each consumer:
1. Adds `setup()` returning store and/or composable refs
2. Removes direct API imports (`getComments`, `createRuleReview`, etc.)
3. Replaces API calls in methods with store/composable calls
4. Template stays snake_case (spread-then-override normalizer preserves both shapes)
5. Cache invalidation added after non-store mutations

**Reference:** The 5 comment consumers (CommentDedupBanner, ComponentComments, CommentComposerModal, CommentTriageModal, UserComments).

### Phase E: Template Normalization (per-component, incremental)
**Pattern:** Replace `item.snake_case` with `item.camelCase` in templates.

- Done one component at a time, not all at once
- After ALL consumers of a system use the store, remove snake_case from the normalizer
- Tests updated to assert camelCase field access
- This is mechanical work — no logic changes

### Phase F: Mixin Elimination
**Pattern:** Each mixin becomes a composable.

| Mixin | Composable | Status |
|-------|-----------|--------|
| `DateFormatMixin` | `useDateFormat` | Done (bridge: both exist) |
| `AlertMixin` | `useAlert` | TODO |
| `FormMixin` | `useFormCsrf` | TODO |
| `RoleComparisonMixin` | `useRoleComparison` | TODO |
| `ReplyComposerMixin` | `useReplyComposer` | TODO |
| `CommentIconHostMixin` | `useCommentIconHost` | Done (mixin deleted) |

### Phase G: Pack Consolidation
**Pattern:** Merge esbuild packs that share heavy state.

**Wave 1 — Base bundle:**
- `application.js` + `navbar.js` + `toaster.js` → one base bundle loaded on every page
- Shared Pinia instance, no cross-bundle MutationObserver hacks

**Wave 2 — Workspace bundle:**
- `project.js` + `project_components.js` + `project_component.js` + `rules.js` → one workspace bundle
- Most user time is spent here — shared stores eliminate redundant fetches

**Wave 3 — Remaining pages:**
- `users.js` + `login.js` + `stigs.js` + `security_requirements_guides.js` + `stig.js` + `projects.js` → lazy-loaded routes
- These become Vue Router routes, not separate entry points

### Phase H: Vue Router + Turbolinks Removal
**Pattern:** Replace Turbolinks navigation with Vue Router.

1. Install vue-router
2. Define routes matching existing Rails routes
3. Convert HAML views to route components
4. Remove `vue-turbolinks` adapter
5. Remove `turbolinks:load` event listeners
6. Rails routes serve JSON (API) or the SPA shell (HTML)

### Phase I: Rails API-Only
**Pattern:** Remove HAML views, Propshaft, jsbundling-rails.

1. Rails serves the SPA shell from a single controller (`SpaController#index`)
2. All other controllers return JSON only
3. Remove HAML templates, view helpers, Propshaft pipeline
4. Rails becomes `config.api_only = true` (or close to it)
5. Frontend builds independently (Vite, not esbuild-via-Rails)

## System Migration Order

Systems ordered by dependency, complexity, and user impact:

| # | System | Store | Key Consumers | Est. (sp) | Depends On |
|---|--------|-------|--------------|-----------|------------|
| 1 | **Comments** | `useCommentsStore` | 5 consumers | sp:13 | — |
| 2 | **Rules** | `useRulesStore` | RuleForm, CheckForm, DisaRuleDescriptionForm, RuleEditor sidebar | sp:8 | Comments (shared CommentThread) |
| 3 | **Components** | `useComponentsStore` | ComponentCard, ComponentSettings, ControlsCommandBar, export modal | sp:8 | Rules |
| 4 | **Projects** | `useProjectsStore` | ProjectCard, ProjectMembers, ProjectSettings | sp:5 | Components |
| 5 | **Users/Memberships** | `useUsersStore` | UsersTable, EditUserModal, navbar badge, access requests | sp:5 | — |
| 6 | **SRGs** | `useSrgsStore` | SRG list, SRG detail, rule mapping | sp:3 | — |
| 7 | **STIGs** | `useStigsStore` | STIG list, STIG detail, comparison | sp:3 | — |
| 8 | **Auth/Session** | `useAuthStore` | Login, profile, provider linking | sp:5 | Users |

**Total estimate:** ~50 sp across 8 systems, ~10-15 sessions at current velocity.

## The Normalizer Bridge Pattern

During migration, API responses are snake_case (Rails convention) but the target is camelCase (JavaScript convention). The normalizer uses spread-then-override:

```javascript
function normalizeComment(raw) {
  return {
    ...raw,                    // preserve ALL snake_case fields
    ruleId: raw.rule_id,       // add camelCase aliases
    authorName: raw.author_name || raw.commenter_display_name || "",
    triageStatus: raw.triage_status || null,
    // ...
  };
}
```

**Why:** Templates reference 100+ snake_case fields across the app. Converting all at once is a multi-day rewrite. The spread-then-override lets:
- New code use camelCase (the correct JS convention)
- Existing templates keep working with snake_case
- Migration happens per-component in Phase E
- Once all consumers use camelCase, the spread is removed

**Rule:** New components MUST use camelCase. Existing components MAY use snake_case until Phase E migrates them.

### camelCase Migration Tracking — Comment System

| Component | Snake_case fields in template | Status | Target |
|-----------|------------------------------|--------|--------|
| CommentDedupBanner | `section` (shared key) | Minimal — mostly uses CommentItem | Before Wave 2 |
| ComponentComments | `rule_displayed_name`, `triage_status`, `adjudicated_at`, `author_name`, `component_id`, `commentable_type`, +12 more | snake_case — pending | Before Wave 2 |
| CommentComposerModal | None (no row rendering) | N/A — uses composable only | Done |
| CommentTriageModal | `rule_displayed_name`, `triage_status`, `adjudicated_at`, `commenter_display_name`, `triage_set_at`, +8 more | snake_case — pending | Before Wave 2 |
| UserComments | `rule_displayed_name`, `triage_status`, `component_id`, `component_name`, `project_name`, +6 more | snake_case — pending | Before Wave 2 |
| TriageSplitView | Same as ComponentComments (receives rows as props) | snake_case — pending | Before Wave 2 |
| CommentsByRule | Same as ComponentComments (receives rows as props) | snake_case — pending | Before Wave 2 |

**Target:** All comment system templates migrated to camelCase before Wave 2 (Rules store) begins. Once complete, remove the `...raw` spread from `normalizeComment` — only return camelCase fields.

## Quality Gates

Every system migration must pass:

1. Store unit tests (fetch, cache, invalidation, error paths)
2. Composable unit tests (loading state, delegation to store)
3. Consumer integration tests (store called, not direct API)
4. Full Vitest suite green (3097+ tests)
5. ESLint zero warnings (`yarn lint:ci`)
6. esbuild compiles (`yarn build`)
7. Expert review swarm (8 independent reviewers, synthesized report)
8. Cross-layer callback audit (trace ALL model callbacks through ALL controller actions — Gate 17)
9. All enum values tested for fields that trigger callbacks (not just happy path)
10. Live Playwright verification of affected pages
11. All findings fixed before moving to the next system

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-04 | Spread-then-override normalizer | Incremental template migration without big-bang rewrite |
| 2026-06-04 | No cache for project/user fetches | Cross-scope invalidation too complex; table views always want fresh data |
| 2026-06-04 | Cache for component-scope fetches | CommentDedupBanner benefits from reuse; invalidated by store mutations |
| 2026-06-04 | ComponentComments invalidates cache in fetch() | Primary data view always wants fresh data after any mutation |
| 2026-06-04 | fetchAndNormalize DRY helper | 4 fetch methods shared identical boilerplate |
| 2026-06-04 | setup() after props | Vue style guide order: components → mixins → props → setup → data |
| 2026-06-04 | Comments first | Most complex comment system proves the pattern; simpler systems follow mechanically |
| 2026-06-04 | Cross-layer callback audit mandatory | before_save on Review silently undid reopen — callback-fights-endpoint bug invisible to single-layer tests |
| 2026-06-04 | Test ALL enum values for callback-triggering fields | Reopen test only covered 'concur' (non-terminal) — missed 'duplicate'/'informational'/'addressed_by' where callback fires |
| 2026-06-04 | `??` not `||` for normalizer defaults | `||` coerces 0, '', false to fallback — data loss bug flagged by 5/8 expert reviewers |

## References

- [Frontend Architecture](frontend-architecture.md) — four-layer pattern
- [State Management](state-management.md) — Pinia conventions, store patterns, testing
- [Testing Pinia Composables](testing-pinia-composables.md) — test patterns
- [Design System](design-system.md) — CSS variable conventions
