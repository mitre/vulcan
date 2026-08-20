# Plan: Deduplicate effective_permissions — provide/inject + usePermissions composable

**Date:** 2026-06-07
**Card:** v2-xcy.5 (rescoped)
**Epic:** v2-xcy (HAML → Vue serialization standardization)

## Architectural Decision

**Pattern:** Vue provide/inject + usePermissions() composable (Vue 2.7 Composition API)

**Why provide/inject:**
- Vue core DI mechanism — NOT deprecated, works identically in Vue 2.7 and Vue 3
- Designed for tree-scoped data (permissions are per-resource, not global)
- Eliminates prop drilling without introducing a mixin (mixins are deprecated in Vue 3)
- Even in a full Pinia SPA, provide/inject is the correct tool for tree-scoped data

**Why composable (not mixin):**
- Vue 3 Composition API is the standard — composables replace mixins
- Vue 2.7 supports Composition API natively — no bridge needed
- `usePermissions()` wraps inject + computed helpers — same API survives Vue 3 migration
- Explicit dependencies (import) vs implicit (mixin merge)

**Why NOT Pinia for this:**
- Permissions are tree-scoped (this user on THIS project/component), not global state
- Pinia is for Phase 4 (API data stores, caching, normalization)
- provide/inject is the correct tool even in a full Pinia app

## Current State (BEFORE)

### Data flows through THREE redundant paths:
1. Controller `set_*_permissions` → `@effective_permissions` → HAML prop → Vue prop
2. Controller Blueprint render with `current_user:` option → Blueprint field → inside JSON data
3. Both arrive at the same Vue component — duplication

### Prop drilling chain per page:
```
HAML prop → Root Vue component (prop declaration)
  → Child 1 (prop declaration, passes to grandchild)
    → Grandchild (prop declaration, uses for permission check)
  → Child 2 (prop declaration, uses for permission check)
  → Child 3 (prop declaration, passes further)
```

## Target State (AFTER)

### Single data path:
1. Blueprint field (computed from current_user) → inside JSON data → Vue root reads it → provides to tree

### No prop drilling:
```
Root Vue component (reads from initial data, provides)
  → Any descendant: const { canEdit, canAdmin } = usePermissions()
```

## Audit: Complete Change Map

### Phase 1 — Create composable + utility (no behavior change)

| File | Action | Notes |
|------|--------|-------|
| `app/javascript/composables/usePermissions.js` | CREATE | Composable wrapping inject + computed helpers |
| `app/javascript/utils/roleComparison.js` | CREATE | Extract role_gte_to as pure function from mixin |
| `spec/javascript/composables/usePermissions.spec.js` | CREATE | Test composable |

### Phase 2 — Root components: provide from data, remove HAML prop (6 pages)

Each page = 1 HAML file + 1 root Vue component + 1 controller check.

| # | HAML File | Vue Root Component | Pack File | Controller Action |
|---|-----------|-------------------|-----------|-------------------|
| 1 | `components/show.html.haml` | `ProjectComponent.vue` | `project_component.js` | `components#show` |
| 2 | `components/settings.html.haml` | `ComponentSettingsPage.vue` | `component_settings.js` | `components#settings` |
| 3 | `components/triage.html.haml` | `ComponentTriagePage.vue` | `component_triage.js` | `components#triage` |
| 4 | `projects/show.html.haml` | `Project.vue` | `project.js` | `projects#show` |
| 5 | `projects/triage.html.haml` | `ProjectTriagePage.vue` | `project_triage.js` | `projects#triage` |
| 6 | `rules/index.html.haml` | `Rules.vue` | `rules.js` | `rules#index` |

**Per page, root component change:**
- Remove `effective_permissions` prop declaration
- Add `provide()` returning `effectivePermissions` read from initial data prop
- Keep passing to children via props TEMPORARILY (Phase 3 removes those)

### Phase 3 — Child components: replace prop with composable (~15 components)

| Component | Current Source | Permission Checks | Passes to Children? |
|-----------|---------------|-------------------|---------------------|
| `ControlsCommandBar.vue` | prop | `role_gte_to(author)`, `=== 'admin'`, `!!` | No |
| `ControlsSidepanels.vue` | prop | `role_gte_to(admin)`, `role_gte_to(author)` | Yes → child components |
| `ProjectCommandBar.vue` | prop | `=== 'admin'` | No |
| `ProjectSidepanels.vue` | prop | `=== 'admin'`, `role_gte_to(author)` | No |
| `ProjectMembersModal.vue` | prop | `role_gte_to(admin)` | No |
| `ProjectTriagePage.vue` | prop | passes to TriageSplitView | Yes |
| `ComponentTriagePage.vue` | prop | passes to TriageSplitView | Yes |
| `TriageSplitView.vue` | prop | `role_gte_to(author)`, `=== 'admin'` | No |
| `ComponentComments.vue` | prop | `role_gte_to(author)`, `role_gte_to(admin)`, `!!` | No |
| `ComponentCard.vue` | prop | `role_gte_to(reviewer)`, `=== 'admin'` (4x) | No |
| `CommentTriageModal.vue` | prop | `role_gte_to(author)`, `=== 'admin'` | No |
| `ComponentCommandBar.vue` | prop | `role_gte_to(author)`, `=== 'admin'` (2x) | No |
| `RulesCodeEditorView.vue` | prop | `=== 'viewer'` | Yes → RuleEditor |
| `RuleActionsToolbar.vue` | prop | `=== 'admin'` | No |
| `RuleEditorHeader.vue` | prop | `== 'admin'`, `== 'reviewer'` | No |
| `UnifiedRuleForm.vue` | prop | `includes(['admin','reviewer'])` | No |
| `RuleReviews.vue` | prop | `!!` | No |
| `MembersModal.vue` | prop | `role_gte_to(admin)` | No |

**Per component change:**
- Remove `effectivePermissions` prop declaration
- Remove RoleComparisonMixin import (if only used for permissions)
- Add `setup()` with `const { canEdit, canAdmin, isMember, effectivePermissions } = usePermissions()`
- Replace `this.role_gte_to(this.effectivePermissions, 'author')` → `this.canEdit`
- Replace `this.effectivePermissions === 'admin'` → `this.canAdmin`
- Replace `!!this.effectivePermissions` → `this.isMember`
- Remove prop pass-through to children (children inject directly)

### Phase 4 — Controller + test cleanup

| File | Action |
|------|--------|
| `app/controllers/application_controller.rb` | Remove `set_project_permissions` + `set_component_permissions` if unused |
| `app/controllers/components_controller.rb` | Remove `before_action :set_component_permissions` if unused |
| `app/controllers/projects_controller.rb` | Remove `before_action :set_project_permissions` if unused |
| `spec/javascript/**/*` (6 files) | Change `props: { effectivePermissions }` → `provide: { effectivePermissions }` in test mounts |
| `spec/requests/components_show_spec.rb` | Verify effective_permissions still in JSON response (from Blueprint) |
| `spec/requests/projects_show_spec.rb` | Verify effective_permissions still in JSON response (from Blueprint) |

**IMPORTANT:** `@effective_permissions` is ALSO used in `components/show.html.haml` line 1 for a server-side conditional (`if @component.released && @effective_permissions.nil?`). This controls whether to render the released-component view vs the editor view. This is a RAILS decision, not a Vue decision — it CANNOT be removed from the controller. The controller before_action stays; only the HAML prop is removed.

### Phase 5 — Cleanup + verify

| Check | Command |
|-------|---------|
| Zero effectivePermissions props in Vue | `grep -rn "effectivePermissions.*prop\|effective_permissions.*prop" app/javascript/components/` |
| Zero HAML effective_permissions props | `grep -rn "effective.permissions" app/views/` — should only show line 1 of components/show |
| RoleComparisonMixin removable? | `grep -rn "RoleComparisonMixin" app/javascript/` — if zero imports, delete the file |
| All tests pass | `bin/parallel_rspec spec/ && yarn test:unit` |
| Live test every page | Playwright: component editor, project page, triage (x2), settings, rules |

## Composable API Design

```javascript
// app/javascript/composables/usePermissions.js
import { inject, computed } from 'vue'
import { roleGteTo } from '../utils/roleComparison'

export function usePermissions() {
  const effectivePermissions = inject('effectivePermissions', null)

  return {
    effectivePermissions,
    canView:   computed(() => roleGteTo(effectivePermissions, 'viewer')),
    canEdit:   computed(() => roleGteTo(effectivePermissions, 'author')),
    canReview: computed(() => roleGteTo(effectivePermissions, 'reviewer')),
    canAdmin:  computed(() => effectivePermissions === 'admin'),
    isMember:  computed(() => !!effectivePermissions),
  }
}
```

```javascript
// app/javascript/utils/roleComparison.js
const ROLE_HIERARCHY = ['viewer', 'author', 'reviewer', 'admin']

export function roleGteTo(effectiveRole, requiredRole) {
  if (!effectiveRole || !requiredRole) return false
  return ROLE_HIERARCHY.indexOf(effectiveRole) >= ROLE_HIERARCHY.indexOf(requiredRole)
}
```

## LOE Estimate

| Phase | Cards | SP | Claude-pace | Human ref |
|-------|-------|----|-------------|-----------|
| 1. Composable + utility | 1 | 2 | ~8 min | ~1 h |
| 2. Root components (6 pages) | 1 | 3 | ~15 min | ~2 h |
| 3. Child components (~15) | 2-3 | 5 | ~25 min | ~4 h |
| 4. Controller + test cleanup | 1 | 2 | ~10 min | ~1 h |
| 5. Verify + cleanup | 1 | 1 | ~5 min | ~30 min |
| **Total** | **5-6** | **13** | **~63 min** | **~8.5 h** |

## Risk Assessment

**High risk items:**
- `components/show.html.haml` line 1: server-side conditional uses `@effective_permissions` — must NOT remove the controller before_action, only the HAML prop
- Vue test files mount components with `props: { effectivePermissions }` — must change to `provide`
- `ComponentCard.vue` uses `==` not `===` for admin checks — should fix during migration

**Low risk items:**
- Blueprint fields unchanged — JSON API responses unaffected
- Wire format unchanged — Vue receives same data, just from a different source
- One page at a time — rollback is straightforward
