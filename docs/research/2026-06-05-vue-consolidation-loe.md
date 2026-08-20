# Vue Consolidation LOE Analysis

**Date:** 2026-06-05 | **Agents:** 6 | **Findings:** 24C 25W 34I (83 total)

## Key Insight

v2.x is already 60%% Vue 3 compatible. The real task is a build-system swap, not a rewrite.
The blocker is Bootstrap 4 vs 5 (371 component usages), not the SPA architecture.

## Vue 3 SPA Shell Port: v3.x → v2.x Migration Assessment (3C 5W)

### [CRITICAL] Vue Router 4 → Vue Router 3: Route records ARE compatible, but the router factory is not

v3.x uses `createRouter` + `createWebHistory` from vue-router@4.6.3. Vue 2.7 requires vue-router@3.x which uses `new VueRouter({ mode: 'history', routes })`. The RouteRecordRaw shape in the routes/index.ts file (path, name, component, meta, children, redirect) is structurally identical between VR3 and VR4. All 30 routes — including lazy-loaded components (`() => import('@/pages/...')`), nested admin children, and redirect objects — use the same syntax. The `beforeEach` guard using `useAuthStore(

**Recommendation:** PORT_DIRECTLY (with adaptation): routes/index.ts copies with zero structural changes. router/index.ts needs factory swap: `new VueRouter({ mode: 'history', routes, scrollBehavior })` replaces `createRouter(createWebHistory())`. Drop `import.meta.env.DEV` guard (use `process.env.NODE_ENV === 'develop

### [CRITICAL] Bootstrap 5 (v3.x) vs Bootstrap 4 (v2.x): 371 BVN component usages require rewrite

v3.x uses Bootstrap 5.3.8 + bootstrap-vue-next@0.42.0 (BVN). v2.x uses Bootstrap 4.6.2 + bootstrap-vue@2.23.1 (BV2). These are not compatible at all — different CSS classes (me-/ms- vs mr-/ml-), different component APIs (BVN uses v-model:show, BV2 uses v-model), different modal systems. Grep finds 371 BModal/BTable/BForm/BButton/BDropdown/BBadge/BCard/BAlert usages across v3.x .vue files. The v3.x AdminLayout uses BOffcanvas (BVN-only). The ConsentModal, CommandPalette, and NewMembership use Rek

**Recommendation:** ADAPT: Every v3.x .vue file needs (1) `<script setup lang='ts'>` → `<script>` with Options API or Vue 2.7 composition API, (2) Bootstrap 5 utility classes → Bootstrap 4 equivalents, (3) BVN component props/events → BV2 equivalents, (4) TypeScript type annotations stripped. This is the largest portin

### [CRITICAL] Pinia stores: composition API pattern is fully compatible — v2.x already proven this

v2.x already uses Pinia 2 with PiniaVuePlugin and createPinia() in createVulcanApp.js. The comments.js store (the reference implementation) uses identical defineStore composition API syntax: `ref()`, `computed()`, async actions, `$reset()`. The v3.x stores (auth, projects, components, rules, stigs, srgs, users, navigation, admin, audits, findReplace, settings) all use the same defineStore composition API pattern. Pinia 2 vs Pinia 3 is a semver difference: v3.x uses pinia@3.0.4, v2.x uses pinia@2

**Recommendation:** PORT_DIRECTLY (with Pinia version pin): All 13 v3.x stores port to v2.x with two changes: (1) remove TypeScript type annotations and import types, (2) remove `import.meta.hot` HMR blocks at the bottom. The store logic, state structure, action patterns, and cache strategies are copy-paste compatible.

### [WARNING] @vueuse/core dependency: only 3 files use it, but they are core infrastructure

v3.x uses @vueuse/core in exactly 3 files: useCommandPalette.ts (useMagicKeys, whenever), useGlobalSearch.ts, and useKeyboardShortcuts.ts. @vueuse/core v10+ dropped Vue 2 support. The @vueuse/vue2 package exists but is at a much older API level. useMagicKeys in useCommandPalette (Cmd+J keyboard shortcut) has no direct Vue 2 equivalent in @vueuse. The CommandPalette and global search are v3.x-exclusive features not present in v2.x at all.

**Recommendation:** SKIP for initial port: The command palette (Cmd+J global search) is a v3.x-exclusive feature that v2.x does not have. The 3 @vueuse files are entirely about this feature. Do not attempt to port useCommandPalette, useGlobalSearch, or useKeyboardShortcuts to v2.x — they depend on @vueuse primitives wi

### [WARNING] v3.x auth store requires /api/auth/* Rails endpoints that do NOT exist in v2.x

The v3.x auth.store.ts calls login() → POST /api/auth/login and logout() → DELETE /api/auth/logout and getCurrentUser() → GET /api/auth/me. These are SPA-specific JSON auth endpoints in the v3.x Rails app (which has an admin namespace with /admin/stats, /admin/users, /admin/settings, /admin/audits). v2.x uses Devise form-based auth (devise_for :users) and has no /api/auth namespace. The v3.x navigation store calls GET /api/navigation which also does not exist in v2.x. The v3.x admin store calls

**Recommendation:** REBUILD auth flow: For the v2.x SPA port, the auth store should read from window.vueAppData.currentUser (Rails server-renders this — the pattern is already documented in v3.x auth.store.ts as 'the ONE exception'). The router guard works the same way: check authStore.signedIn which reads from window

### [WARNING] v2.x has the complete PR #717 comment/triage system — v3.x has almost none of it

v2.x has a mature PR #717 comment triage system: comments.js store (233 lines), 6 comment-specific components (CommentComposerModal, CommentDedupBanner, CommentPeriodBanner, CommentsByRule, CommentTriageModal, ComponentTriagePage), full triage route at /components/:id/triage, and a 138-line reviewsApi.js with triage/adjudicate/merge/adminAction operations. v3.x has only CommentModal.vue (generic) and ActionCommentModal.vue — no triage system, no bulk triage, no dedup, no comment period banner. T

**Recommendation:** REBUILD (keep v2.x): The entire comment/triage subsystem stays as-is in v2.x. Do not attempt to port v3.x comment infrastructure to v2.x — there is nothing to port. The v2.x PR #717 system is the authoritative implementation. When evaluating the reverse port (v2.x → v3.x eventually), the comments.js

### [WARNING] v3.x admin SPA (5 admin pages) requires a new Rails /admin namespace that v2.x lacks

v3.x has a full admin section: AdminLayout.vue with nested routes for DashboardPage, UsersPage, AuditPage, SettingsPage, BenchmarksPage. This maps to Rails endpoints in the v3.x /admin namespace (admin/dashboard#stats, admin/users, admin/settings, admin/audits). v2.x has no /admin namespace — admin user management is at /users (UsersController with admin guards). The admin audit log (AuditPage, audits.store.ts) is entirely new functionality not present in v2.x as a dedicated SPA page. The admin

**Recommendation:** ADAPT with phasing: For v2.x SPA port, phase admin pages separately. Phase 1 (SPA shell): exclude /admin routes entirely — admin functions remain at their existing v2.x URLs (/users for user management). Phase 2: add GET /api/navigation to Rails, create minimal Admin namespace controller. Phase 3: p

### [WARNING] v2.x esbuild uses per-pack entry points (24 files) vs v3.x single entrypoint — build migration requi

v2.x esbuild.config.js lists 24 explicit entry points (application, navbar, toaster, login, projects, project, project_components, project_component, project_triage, component_triage, component_settings, released_component, rules, security_requirements_guides, srg, stig, stigs, disa_guide, users, user_profile, user_password, user_activity, user_comments, user_tokens, api_docs). Each maps to a HAML view that includes the corresponding javascript_include_tag. v3.x has a single `application.ts` ent

**Recommendation:** ADAPT: The build migration is mandatory but mechanical. Steps: (1) Add a new SPA entry point (e.g., app/javascript/packs/spa.js) that creates the single Vue Router app. (2) Add a new HAML layout (app/views/layouts/spa.html.haml) with a single `<div id='app'></div>`. (3) Migrate routes one by one: fo

### [INFO] API client layer: v2.x uses ky, v3.x uses axios — different error shapes, both portable

v2.x api/baseApi.js uses ky (recently migrated from axios in 2026-06) with a normalizeResponse wrapper that reshapes errors to `{ response: { data, status, headers } }` — the same shape axios callers expect. v3.x uses axios directly via http.service.ts with interceptors. The store-level code in v3.x calls `response.data` which is the axios response shape. v2.x baseApi resolves to `{ data, status }` matching this shape. The v3.x API files (components.api.ts, projects.api.ts, etc.) use TypeScript

**Recommendation:** ADAPT: Strip TypeScript from v3.x API files and replace `import { http } from '@/services/http.service'` with `import api from '../api/baseApi'`. The function bodies are otherwise identical. Exception: v3.x auth.api.ts calls /api/auth/* endpoints that don't exist in v2.x (see CRITICAL finding above)

### [INFO] Pinia version difference (2 vs 3): PiniaVuePlugin is required in v2.x and removed in v3.x

v2.x uses pinia@2 with PiniaVuePlugin (required for Vue 2 support). v3.x uses pinia@3.0.4 which dropped Vue 2 compatibility. The store SYNTAX is identical between Pinia 2 and 3 (defineStore composition API). The storeToRefs() utility used in useRules.ts composable works identically in both. The acceptHMRUpdate HMR blocks at the bottom of v3.x stores are Pinia 3 + Vite-specific and should be dropped when porting to v2.x (esbuild-based).

**Recommendation:** PORT_DIRECTLY: Keep pinia@2 in v2.x. When copying v3.x stores, strip: (1) TypeScript type annotations and imports, (2) `if (import.meta.hot) { import.meta.hot.accept(acceptHMRUpdate(...)) }` HMR blocks. The store logic, patterns, and exported API are identical. The shared pinia instance in createVul

### [INFO] v3.x findReplace.store is more complete than v2.x FindAndReplace.vue component

v2.x has FindAndReplace.vue (component-local state, basic search) and FindAndReplaceResult.vue. v3.x has a fully-featured findReplace.store.ts (612 lines): navigation (next/prev/first/last/jump), replace-one with custom text, replace-all, undo stack, modal open/close state, and a findReplace.api.ts with replaceInstance/replaceAll/undo API calls. The v3.x store uses the same /components/:id/find Rails endpoint that already exists in v2.x (POST /components/:id/find in routes.rb). The replace opera

**Recommendation:** PORT_DIRECTLY (store only): The findReplace.store.ts ports to v2.x with TypeScript stripped. The Rails replace endpoints need to be verified/added separately. The v3.x FindReplaceModal.vue uses @vueuse/core but only for keyboard shortcuts — that dependency can be replaced with a plain addEventListen

### [INFO] Script setup (Vue 3 only) used across all 26 v3.x pages and 67 components — none in v2.x

Every v3.x page and most components use `<script setup lang='ts'>`. Vue 2.7 introduced limited script setup support but it has known limitations with TypeScript, and v2.x esbuild config uses `useFullVue: true` (runtime compilation) rather than the SFC transform compiler needed for script setup. v2.x has zero script setup usage across its 135 .vue files. All v2.x components use Options API with `export default { data(), methods: {}, computed: {} }`.

**Recommendation:** ADAPT: All v3.x .vue files ported to v2.x must be converted from `<script setup>` to Options API or Vue 2.7 Composition API (`setup()` function). Vue 2.7 does support `setup()` via the built-in `@vue/composition-api` (it's native to 2.7). Using `setup()` with `ref/computed/watch` from vue (not @vue/

## Frontend Feature Completeness: v2.x vs v3.x (6C 8W)

### [CRITICAL] Entire public-comment / triage workflow is v2.x-only

v2.x has a complete, production-ready public-comment review system that does not exist at all in v3.x. This includes: the useCommentsStore Pinia store (50-entry cache, normalizeComment, fetchComments, fetchReplies, postComment, postComponentComment, triageComment, bulkTriage, adjudicateComment, mergeComments, adminAction, invalidateCache — 228 lines); 15 reviewsApi functions (createRuleReview, createComponentReview, getReviewResponses, triageReview, bulkTriageReviews, mergeReviews, adjudicateRev

**Recommendation:** This is the largest single forward-port requirement. All 30+ comment/triage files must be migrated from Vue 2 Options API + Bootstrap-Vue to Vue 3 Composition API + Bootstrap-Vue-Next. The useCommentsStore should migrate nearly verbatim (already uses Pinia + Composition API). The triage components w

### [CRITICAL] DISA Process Guide page is v2.x-only

v2.x has DisaGuidePage.vue (disa_guide.js pack) — a full embedded DISA V4R1 process guide with a 3-panel layout (sidebar nav, main content, sticky TOC), dark mode toggle, smooth scroll, server-rendered HTML sanitized by Rails SafeListSanitizer, and section highlight on scroll. The page has its own route in Rails (/disa-guide/:page). v3.x has no equivalent — no route, no page, no component. DisaGuidePage uses disaGuideInit.js utility and integrates with the dark mode colorMode utility.

**Recommendation:** Add a /disa-guide/:page route to v3.x routes and port DisaGuidePage as a Vue 3 page. The 3-panel CSS layout and TOC scroll logic can be preserved almost verbatim. The dark mode toggle already works in v3.x via useColorMode. Estimate: sp:3, 20-25 min.

### [CRITICAL] Personal Access Token (PAT) management is v2.x-only

v2.x has UserTokens.vue (show-once raw token display, copy-to-clipboard, revoke), CreateTokenModal.vue (name, expiry, IP allowlist, scopes), and tokensApi.js — all wired into the user_tokens.js pack. v3.x has no PAT UI at all: users.api.ts has no token endpoints, AccountSettingsPage has no token section, and there is no CreateTokenModal or UserTokens equivalent. The PAT backend (PersonalAccessToken model, SHA-256 digest, vulcan_ prefix, scopes array, IP CIDR allowlist) was built in Session 18 an

**Recommendation:** Port UserTokens.vue and CreateTokenModal.vue to Vue 3 and integrate into the AccountSettingsPage (already exists in v3.x). Add token CRUD methods to users.api.ts. Estimate: sp:3, 15-20 min.

### [CRITICAL] Autosave (useRuleAutosave) is v2.x-only

v2.x has useRuleAutosave.js — a debounced 5-second autosave composable with localStorage persistence of the enabled toggle per component (autosave-{componentId} key), dirty tracking, lock/review guard (skips if rule.locked or rule.review_requestor_id), and silent-fail on error. Uses '[Auto-saved]' audit_comment. v3.x has no autosave at all — useRequirementEditor has save() and markDirty() but no timer-based autosave. This is an active user-facing feature (toggle visible in the rule editor toolba

**Recommendation:** Port useRuleAutosave to TypeScript and wire into useRequirementEditor. The composable is self-contained (62 lines) and has no Vue 2 dependencies. Estimate: sp:1, 5 min.

### [CRITICAL] SatisfiedByIndicator (container-query responsive) is v2.x-only

v2.x has SatisfiedByIndicator.vue — a CSS container-query-responsive banner that shows parent rule links ('Satisfied by RHEL-08-000001, RHEL-08-000002') with 3 responsive modes: narrow (badge-only, <250px), medium (compact card, 251-500px), full (banner with go-to-parent button, >500px). Uses CSS @container queries. v3.x has SatisfiesIndicator.vue in TableView — but that is the inverse: it shows how many rules THIS rule satisfies (parent→child count badge). The v2.x component shows the child rul

**Recommendation:** Port SatisfiedByIndicator.vue to Vue 3. The component has zero Bootstrap-Vue dependencies (pure CSS + vanilla slots). It can be dropped in with minimal changes. The container-query CSS is forward-compatible with Bootstrap 5. Estimate: sp:1, 5 min.

### [CRITICAL] SectionCommentIcon and comment-period phase enforcement are v2.x-only

v2.x has SectionCommentIcon.vue — per-section comment count badges rendered inline in the rule editor via ControlsSidepanels. It also has CommentPeriodBanner.vue with full comment period lifecycle logic (open-with-deadline countdown, closed-with-past-deadline notice, pending count + open-panel CTA, comment-on-component button). CommentDedupBanner.vue shows existing comments when composing to prevent duplicates. None of these exist in v3.x. v3.x has no concept of a comment period, no section-leve

**Recommendation:** Port all three components. SectionCommentIcon integrates into the editor via useCommentIconHost composable (also v2.x-only). CommentPeriodBanner and CommentDedupBanner are self-contained. All three require the useCommentsStore to be ported first. Estimate: sp:3 total for these 3 components.

### [WARNING] Dark mode implementation diverges: v2.x is simpler, v3.x is better

v2.x has useThemeStore (Pinia, theme.js store) + colorMode.js utility (getPreferredTheme, applyTheme, setStoredTheme) + MutationObserver sync — supports light/dark only. v3.x has useColorMode.ts — supports light/dark/auto (follows system prefers-color-scheme), localStorage persistence with 'vulcan-color-mode' key, cycleColorMode() through all 3 modes, system preference change listener. The v3.x implementation is strictly better. v2.x uses the Bootstrap 5.3 data-bs-theme pattern on Bootstrap 4.6.

**Recommendation:** During port, adopt v3.x useColorMode as the canonical implementation and discard v2.x useThemeStore. The 'auto' mode is a meaningful improvement for users. The v2.x colorMode.js utility functions can be retired.

### [WARNING] Rule form architecture differs: v2.x UnifiedRuleForm vs v3.x Basic+Advanced split

v2.x has UnifiedRuleForm.vue — a single DRY form component created via the 'memory/rule-form-refactor.md' effort that handles both basic and advanced fields, section-lock state visualization (colored left-border indicators for locked/under-review/section-locked states), a field-state legend, lock status badge, and is used in both the editor and triage context panel. v3.x split this into BasicRuleForm.vue + AdvancedRuleForm.vue (separate components), which is arguably more modular but loses the s

**Recommendation:** During port, evaluate which approach is better. The v2.x section-lock state visualization (field-level colored indicators) is more sophisticated than v3.x. The v2.x UnifiedRuleForm pattern should be preserved or the v3.x split components should be enhanced to include equivalent lock state visualizat

### [WARNING] Find-Replace: v3.x has Pinia undo stack, v2.x uses mixin approach

v2.x has FindAndReplaceMixin.vue (Options API mixin) + FindAndReplace.vue + FindAndReplaceResult.vue — client-side field matching with no undo. v3.x has useFindReplace.ts (thin wrapper) + findReplace.store.ts (Pinia store with undo/redo stack, UndoEntry type, FlatMatch type) + FindReplaceModal.vue + findReplace.api.ts (server-side search via Rails FindReplaceService). v3.x implementation is significantly more capable: server-side search, multiple field support (8 fields), undo history, match ins

**Recommendation:** v3.x wins here. The v3.x find-replace is a complete rewrite and should be used as-is during the port. The v2.x mixin can be retired.

### [WARNING] Global search: v2.x has inline navbar search, v3.x has command palette

v2.x has GlobalSearch.vue in the navbar — a b-form-input with b-popover showing project/component/rule results. Simple, low-friction. v3.x has CommandPalette.vue (Reka UI Listbox primitives, Cmd+J shortcut) + useCommandPalette (singleton state) + useGlobalSearch (Fuse.js for quick actions + pg_search for API results, recent items localStorage, 8 result categories). v3.x is far more capable. v2.x GlobalSearch only searches projects, components, rules inline; v3.x searches STIGs, SRGs, quick actio

**Recommendation:** v3.x wins. During port, replace v2.x GlobalSearch with the v3.x CommandPalette. The v2.x navbar search can be retired.

### [WARNING] Admin UI: v2.x uses Rails HAML, v3.x has full Vue SPA admin section

v2.x admin pages are standard Rails HAML views (no Vue). v3.x has an AdminLayout.vue with 5 nested Vue pages: DashboardPage (stats: users, projects, STIGs, SRGs, components, recent activity), AuditPage (filterable audit log with pagination, date range, user/action/type filters), SettingsPage (read-only system config display for all auth providers, SMTP, Slack, banner, project settings), BenchmarksPage (STIG/SRG management), UsersPage. v3.x also has useAdminDashboard, useAdminSettings, useAudits

**Recommendation:** These are free improvements that come with the port. The v3.x admin SPA section is a major UX upgrade over HAML views. No v2.x work needs to be ported here — these are v3.x gains.

### [WARNING] User activity and user comments pages are v2.x-only

v2.x has UserActivityPage.vue (50 most recent audit entries via History component), MyCommentsPage.vue + UserComments.vue (user's comment history, paginated, filterable, with triage status badges), all backed by usersApi.js getUserComments. v3.x AccountSettingsPage has profile management (name, email, slackUserId, password) but no activity feed and no comment history view. v3.x user route only has AccountSettingsPage and IndexPage (admin user management).

**Recommendation:** UserActivityPage and UserComments/MyCommentsPage must be ported forward. These integrate with the comment system (useCommentsStore.fetchUserComments) so the comment store port must come first. Estimate: sp:3 combined.

### [WARNING] ReleasedComponent (read-only published view) exists only in v2.x as a pack

v2.x has ReleasedComponent.vue mounted by released_component.js pack — the read-only view for published/released components accessible without project membership. v3.x has /components/:id route pointing to ShowPage.vue, but it is unclear whether it handles the released/public read-only case differently. v3.x RulesReadOnlyView.vue exists but is an old-style Options API component.

**Recommendation:** Verify whether v3.x ShowPage.vue correctly handles released components without membership. If not, the released-component read-only flow needs explicit handling in the v3.x route.

### [WARNING] ControlsSidepanels (sidebar panels for editor) is v2.x-only

v2.x has ControlsSidepanels.vue — a b-sidebar-based right-panel system with Details (component metadata), Comments (comment list, integrates with useCommentsStore), Members, and Export panels. Also ProjectSidepanels.vue for the project view. v3.x has no sidebar panel system — the RequirementEditor embeds everything inline, and the RequirementsFocus uses a two-column layout directly. v3.x has no sliding sidebars for component details, comments, or exports at the controls page level.

**Recommendation:** Decide whether to port the v2.x sidebar panel approach or adopt v3.x's inline layout. The v2.x pattern is more flexible for context-switching. The comment panel specifically integrates with the triage workflow. This decision affects how comments are surfaced during editing.

### [INFO] v3.x has structured TypeScript type system that v2.x lacks

v3.x has 15 TypeScript type definition files in app/javascript/types/ (rule.ts, component.ts, project.ts, user.ts, benchmark.ts, srg.ts, stig.ts, audit.ts, membership.ts, access-request.ts, navigation.ts, command-palette.ts, common.ts, ui.ts, index.ts). v2.x has no TypeScript and no type definitions — all props/API shapes are untyped. During port, v2.x comment/triage types (Review, Comment, TriagePayload, BulkTriagePayload, reaction types) need to be added to the v3.x type system.

**Recommendation:** Plan to write TypeScript interfaces for all v2.x-only features before porting their components. The useCommentsStore normalizeComment function defines the canonical shape implicitly — extract it into types/review.ts.

### [INFO] v3.x has keyboard shortcuts, release check, error boundary — all v2.x lacks

v3.x has useKeyboardShortcuts.ts (cross-platform key symbols, VueUse useMagicKeys, Mac/Windows detection), useReleaseCheck.ts (semver GitHub release polling, update notification), and ErrorBoundary.vue (onErrorCaptured for async setup errors, retry button). None of these exist in v2.x. These are free improvements that come with the port and require no v2.x feature forward-porting.

**Recommendation:** These come for free with the port. No action needed — they are additive.

### [INFO] Composable count gap: v3.x has 3x more composables than v2.x (60 vs 20)

v3.x has 60 TypeScript composables including full domain composables for every entity (useAuth, useProjects, useComponents, useRules, useSrgs, useStigs, useBenchmarks, useUsers, useProfile, useNavigation, usePermissions, useRevisionHistory, useAudits, useAdminDashboard, useAdminSettings, useConsentBanner, useConfirmModal, useBaseTable, useRailsForm, useCsrfToken, useDateTime, useDeleteConfirmation, useToast — all in TypeScript). v2.x has 20 JS composables that are more narrowly scoped. During th

**Recommendation:** Plan for approximately 11 new TypeScript composables to be created during the port, covering the comment/triage domain that v3.x currently lacks entirely.

### [INFO] Backend test coverage gap: v2.x has 316 spec files vs v3.x 78

v2.x has 316 RSpec spec files covering 3071+ backend tests (per session history). v3.x has only 78 spec files. The v2.x backend is the authoritative implementation — it has all the comment/review/triage/PAT/lockout/consent/export/backup/restore business logic fully tested. The port question is purely frontend: the v3.x Rails backend is less mature and would need v2.x backend migrations pulled in as well.

**Recommendation:** The port direction should be: take v3.x SPA shell (Vue 3 + Router + Pinia + TypeScript + Bootstrap 5) and bring it to v2.x's backend maturity level (316 specs, comment/triage/PAT/lockout features). Do not try to port v2.x frontend into v3.x backend — the v2.x backend is the production system.

## Level-of-Effort Estimate: Porting v3.x SPA Shell into v2.x (0C 3W)

### [INFO] Option A: Vue Router + Pinia Stores Only (Keep HAML pages, add per-page routing)

Scope: Remove Turbolinks (already carded v2-9k7.1), install Vue Router 3 (Vue 2.7 compat, NOT v4), add a single router instance initialized in createVulcanApp, add beforeEach auth guard reading from the existing Pinia theme/comments stores, port the 11 v3.x Pinia stores (rules, components, projects, auth, users, srgs, stigs, navigation, audits, settings, findReplace) from TS to plain JS (or add minimal TS infra), keep ALL HAML views and all v2.x Vue components untouched.

Files to create/modify:

**Recommendation:** Viable for teams that want store parity and turbolinks removal without committing to full migration. sp:8 total, ~71 min. Start here only if the goal is incremental groundwork, not a user-visible SPA experience.

### [INFO] Option B: Editor Cluster SPA (component editor + triage as SPA, rest stays HAML)

Scope: Everything in Option A, plus: migrate the 6 HAML views that make up the component editor cluster (components/show, components/triage, components/settings, projects/show, projects/triage, rules/index) to a single SPA entry point with Vue Router handling those 6 routes. The v3.x page components serve as templates but require Bootstrap-Vue → Bootstrap-Vue-Next migration for all components in scope.

Additional work beyond Option A:
- Replace the 6 page-level HAML views with a single SPA shel

**Recommendation:** Best balance of user-visible impact and scope. Gets the highest-value pages (the editor) onto the SPA without touching 19 remaining HAML pages. ~321 min Claude-pace. The comment-triage forward-port is the critical path; budget 2x on that cluster.

### [INFO] Option C: Full Port (all 24 instances → 1 SPA using v3.x as blueprint)

Scope: Everything in Options A and B, plus migrating the remaining 19 HAML pages/packs: login, projects index, users, user settings (profile/password/tokens/activity/comments), stigs index/show, SRGs index/show, rules index, disa_guide, api_docs, released_component, project_triage, benchmarks. Total HAML views to replace: ~23 (including devise auth pages).

Additional work beyond Option B:
- 19 remaining page migrations using v3.x pages as templates (login/auth pages, user settings cluster, benc

**Recommendation:** Viable, and the v3.x blueprint covers ~70% of it. The remaining 30% is DisaGuide, user settings pages not in v3.x, and the controller/API audit. ~549 min Claude-pace. Do not start Option C without first completing a controller/HAML audit to identify which Ruby-object-to-Vue-prop bindings have no JSO

### [WARNING] Critical Gap: Comment Triage / Public Comment Period Is Absent from v3.x

v3.x has NO equivalent of the comment triage cluster that exists in v2.x on the current branch (feat/comment-triage-context-panel). The following v2.x components have zero counterpart in v3.x: ComponentComments.vue (911 LOC), CommentTriageModal.vue (578 LOC), TriageSplitView.vue (565 LOC), CanonicalCommentPicker.vue, CommentPeriodBanner.vue, CommentDedupBanner.vue, triage/TriageQueueNav.vue (377 LOC), triage/RuleContextPanel.vue (348 LOC), triage/TriageRuleSidebar.vue (296 LOC), triage/CommentPr

**Recommendation:** Before committing to any option, decide whether the comment-triage feature set migrates as-is (forward-port from Vue 2 Options API to Vue 3 Composition API + BVN) or gets redesigned. A redesign would be comparable LOE to a forward-port but yields a cleaner result. Budget sp:13 (75 min Claude-pace) s

### [WARNING] Bootstrap-Vue 2.x → Bootstrap-Vue-Next Migration Is Not Trivial

v2.x uses 63 unique Bootstrap-Vue 2 component types across 135 components. Several have no direct equivalent in Bootstrap-Vue-Next or Bootstrap 5: (1) `<b-icon>` (250 usages) — BVN removed the icon component entirely; must become `<i class='bi bi-*'>` Bootstrap Icons CSS classes. (2) `<b-sidebar>` — replaced by `<BOffcanvas>` with different prop API. (3) `<b-form-row>` — removed in Bootstrap 5; use `<BRow>` or native `<div class='row'>`. (4) `<b-media>` — removed in Bootstrap 5; use flex utiliti

**Recommendation:** For Options B and C: use v3.x component files as the authoritative reference for BVN migration. For the triage cluster (not in v3.x), plan an additional pass for each `<b-*>` type. The `<b-icon>` → Bootstrap Icons CSS swap alone touches 250 call sites across ~60 files.

### [WARNING] TypeScript Infrastructure Is Missing from v2.x

v2.x has no tsconfig.json, no TypeScript in package.json, and the esbuild config uses `esbuild-vue` (not `esbuild-plugin-vue3`). The v3.x Pinia stores and composables are all written in TypeScript (`*.store.ts`, `use*.ts`). Porting them requires either: (a) stripping TypeScript annotations and converting to plain JS — straightforward but loses type safety, or (b) adding TypeScript infrastructure to v2.x (tsconfig, @typescript-eslint, esbuild TS plugin) — adds ~20 min overhead but future-proofs t

**Recommendation:** For any option: strip TypeScript to JS when porting stores and composables. Adding full TS infra to v2.x is a separate sp:5 card (25 min) that should not block SPA work. The v2.x components are all Options API JS and will not benefit from TS until they are individually migrated.

### [INFO] Turbolinks Removal Is Well-Understood and Low Risk

Turbolinks is touched in 31 files: all 25 pack files (each wraps its mount in `document.addEventListener('turbolinks:load', ...)`) plus createVulcanApp.js, application.js, and a handful of components (navbar/App.vue, ComponentComments.vue, UserComments.vue, RuleReviews.vue, DisaGuidePage.vue). The change pattern is mechanical: replace `turbolinks:load` event listener with `DOMContentLoaded`, remove `require('turbolinks').start()` from application.js, remove `vue-turbolinks` from createVulcanApp.

**Recommendation:** Start here. It unblocks all three options and has no downside. The DOMContentLoaded replacement is safe because v2.x packs already mount synchronously if the DOM element exists.

### [INFO] Pinia Stores Are Already Partially Present in v2.x and the API Is Compatible

v2.x already has Pinia 2 with PiniaVuePlugin installed (confirmed in createVulcanApp.js and navbar.js) and two working stores (comments.js with defineStore Composition API at 232 LOC, theme.js at 31 LOC). The defineStore(() => {}) pattern is identical between Vue 2.7 + Pinia 2 and Vue 3 + Pinia 2/3. The v3.x stores use Pinia 3 (package.json: `pinia: ^3.0.4`) while v2.x uses Pinia 2 (`pinia: ^2`). Pinia 3 changes some internals but the defineStore composition API is backward compatible for the pa

**Recommendation:** Port stores before pages. Port them as JS (strip TS types). The comments.js store in v2.x can serve as the syntactic template for how Pinia Composition API stores work in the Vue 2.7 environment.

### [INFO] Option Comparison Summary

Option A (Router + Stores only): ~71 min Claude-pace, sp:8. Low risk. No user-visible SPA. Groundwork for B/C.

Option B (Editor cluster SPA): ~321 min Claude-pace, sp:13 (with overrun risk on triage forward-port). Medium-high risk on triage cluster. Delivers true SPA for the highest-value pages (component editor, triage, project). Rest of app stays HAML.

Option C (Full SPA): ~549 min Claude-pace, sp:21 (epic-sized, should be split into ~4 cards). High risk on controller/API audit and DisaGuide

**Recommendation:** Recommended path: complete Option A as immediate groundwork (1 session), then implement Option B as 3–4 cards splitting the editor cluster, triage forward-port, and Bootstrap migration. Only pursue Option C after B is validated in production. Do NOT attempt Option C as a single card — the controller

## Vue 2.7 Compatibility Assessment for v3.x → v2.x Port (7C 3W)

### [CRITICAL] <script setup> Used in 95/145 .vue Files — Not Available in Vue 2.7

Vue 2.7 backported the Composition API (setup(), ref, computed, watch) but did NOT backport the `<script setup>` sugar syntax. Every one of the 95 files using `<script setup lang="ts">` must be rewritten to use `export default defineComponent({ setup() { ... } })`. This includes all 26 page components, ~70 shared/feature components, and the App.vue root. defineProps<T>(), defineEmits<T>(), defineExpose(), and defineModel() are all `<script setup>`-exclusive macros — they have no direct equivalen

**Recommendation:** All 95 `<script setup>` files must be rewritten to the `defineComponent({ setup() { ... } })` pattern. Plan for a mechanical transformation pass: `<script setup lang="ts">` → `<script lang="ts">` + `export default defineComponent({...})`. Automated codemods can partially handle this but TypeScript g

### [CRITICAL] Suspense + Top-Level Await Used in 10 Page Components — Vue 3 Only

10 of 26 pages (IndexPage, ShowPage, ControlsPage for projects/components/srgs/stigs/users) use top-level `await` inside `<script setup>` to make the component 'suspensible'. The App.vue root wraps every page in `<Suspense>` with a fallback spinner. Vue 2.7 has no Suspense component and does not support async setup components in the same way. ControlsPage.vue does `const componentResponse = await getComponent(componentId)` and `await fetchRules(componentId)` at the top level — this pattern simpl

**Recommendation:** All 10 pages with top-level await must be refactored: move `await` calls from the top level into `onMounted()` with a local `isLoading = ref(true)` state variable. The Suspense wrapper in App.vue must be replaced with a v-if/v-else loading state pattern. This is a full redesign of the page loading s

### [CRITICAL] Reka UI (Headless Primitives) is Vue 3 Only — Used in CommandPalette, ConsentModal, NewMembership

Three components import directly from reka-ui: CommandPalette.vue uses DialogRoot/Content/Portal/Overlay/Title + ListboxRoot/Content/Filter/Group/Item; ConsentModal.vue uses DialogRoot/Close/Content/Portal/Overlay/Title/Description; NewMembership.vue uses ComboboxRoot/Anchor/Content/Empty/Input/Item. Reka UI (the Vue 3 successor to Radix Vue) has no Vue 2 equivalent — it relies on Vue 3's Teleport internally and uses Vue 3's v-model:open binding syntax. The CommandPalette is a key UX feature (Cm

**Recommendation:** These three components cannot be ported — they must be rebuilt. CommandPalette.vue is ~300+ lines and uses Reka UI's accessible dialog + listbox primitives for keyboard navigation and ARIA. For Vue 2.7, replace with Bootstrap-Vue's `<b-modal>` for the dialog wrapper and a custom listbox implementati

### [CRITICAL] Bootstrap-Vue-Next (v0.42) is Vue 3 Only — 240+ Component Usages Across Codebase

The v3.x project uses bootstrap-vue-next with 240+ component usages: BButton (66), BBadge (25), BNavItem (12), BDropdownItem (11), BModal (9), BCard (9), BAlert (9), BOffcanvas (8), BFormTextarea (8), BFormSelect (8), and more. The root App.vue is wrapped in `<BApp>` — a BVN orchestrator that manages toasts, modals, and popovers globally. The `useToast` composable imports directly from bootstrap-vue-next and uses BVN-specific APIs (`bvnToast.create()`, `slots: { default: ({ hide }) => [...] }`,

**Recommendation:** Every BVN component usage must be remapped to its Bootstrap-Vue 2.13 equivalent. BButton → b-button, BModal → b-modal, BBadge → b-badge, etc. BOffcanvas has no BV2 equivalent — use b-sidebar or a custom slide-out. The entire `useToast` composable must be rewritten using Bootstrap-Vue 2.13's `this.$b

### [CRITICAL] Vue Router 4 → Vue Router 3: API Differences Require Changes in Router Config and Guards

The v3.x router uses Vue Router 4 APIs: `createRouter()`, `createWebHistory()`, `RouteRecordRaw` type, `useRoute()`, `useRouter()` inside `<script setup>`, and lazy-loaded routes via `() => import('@/pages/...')`. Vue 2.7 requires Vue Router 3 which uses `new VueRouter({ routes, mode: 'history' })`. The `createRouter`/`createWebHistory` functions don't exist in VR3. The `beforeEach` guard using `useAuthStore()` inside the guard function (which requires Pinia to be installed first) needs careful

**Recommendation:** Replace `createRouter(createWebHistory(), routes)` with `new VueRouter({ mode: 'history', routes })`. Replace `RouteRecordRaw` with `RouteConfig` type. The navigation guard logic itself is compatible. `useRoute()` and `useRouter()` are VR3 Composition API additions available in VR3 — these work. Tot

### [CRITICAL] Pinia 3 vs Pinia 2: Setup Stores Pattern is Compatible But Version Gap Matters

v3.x uses Pinia 3.0.4 with setup stores (all 11 of 12 stores use `defineStore('id', () => { ... })`). v2.x already has Pinia ^2 installed. Pinia 2.x does support setup stores — `storeToRefs()`, `defineStore()` with setup function syntax, and `ref`/`computed` inside stores are all Pinia 2 features. One store (navigation.store.ts) uses Options API style (`state()`, `getters`, `actions`) which is also Pinia 2 compatible. The main risk is Pinia 3 may have introduced subtle behavioral changes or new

**Recommendation:** The Pinia stores are the most portable layer. All 12 stores can be used with Pinia 2 with minimal changes: (1) verify no Pinia 3-specific APIs are used (none found in audit), (2) strip TypeScript generics in prop type annotations if not using vue-tsc, (3) keep all store logic intact. Estimated effor

### [CRITICAL] @vueuse/core v14 is Vue 3 Only — Used for Keyboard Shortcuts and Debouncing

@vueuse/core dropped Vue 2 support at v10. The v3.x project uses v14.1.0 in 5 places: `useMagicKeys` and `whenever` in useCommandPalette.ts and useKeyboardShortcuts.ts, `useDebounceFn` in useGlobalSearch.ts and NewMembership.vue, and `onKeyStroke` in FindReplaceModal.vue. The `useMagicKeys` + `whenever` combination powers the Cmd+J shortcut for the command palette. Without @vueuse/core, these must be replaced with manual event listeners. `useDebounceFn` can be replaced with lodash/debounce (alre

**Recommendation:** Remove @vueuse/core entirely for the Vue 2.7 port. Replace `useDebounceFn` with lodash's debounce (lodash is already in the dependency tree). Replace `useMagicKeys`/`whenever` with a direct `document.addEventListener('keydown', ...)` in onMounted/onUnmounted. Replace `onKeyStroke` with the same patt

### [WARNING] TypeScript Can Be Kept — But Generic Prop Definitions Must Change

TypeScript itself is fully compatible with Vue 2.7 via @vitejs/plugin-vue2 + @vue/composition-api type definitions. The @/ path aliases defined in tsconfig.json will work with esbuild path config. All 178 .ts files (stores, composables, APIs, types, utils) can remain in TypeScript. The main TypeScript issue is that `defineProps<{ id: number }>()` (compiler macros) are `<script setup>` specific — they don't exist outside that context. In `defineComponent({ setup() })` pattern, props must use the

**Recommendation:** Keep TypeScript. Do not strip types. The prop type migration is mechanical: `defineProps<T>()` → `props: { field: { type: X as PropType<T>, required: bool } }`. Use `PropType` from 'vue' for complex types. All TypeScript in stores, composables, API modules, and type definitions is 100% portable as-i

### [WARNING] v-model:propName Named v-model Syntax is Vue 3 Only — 14 Usages

Vue 3 introduced named v-model bindings: `v-model:search`, `v-model:filterStatus`, `v-model:open`, etc. This syntax does NOT exist in Vue 2 — Vue 2 only supports a single `v-model` (which maps to `:value` + `@input`) or `.sync` modifier for additional props. 14 usages found: RequirementsTable.vue passes 7 named v-model bindings to RequirementsToolbar.vue, CommandPalette.vue uses `v-model:open` on Reka UI's DialogRoot (moot — Reka is already blocked), and BTabs uses `v-model:index`. The `defineMo

**Recommendation:** Replace each `v-model:propName="value"` with `:propName="value" @update:propName="value = $event"` (the Vue 3 equivalent expanded form) for non-Reka components, then adapt parent to use `:propName.sync="value"` in Vue 2. In RequirementsToolbar.vue, replace `defineModel<T>('propName')` with explicit

### [WARNING] Composable Layer is 80%+ Portable — Main Issues are Import Paths and Framework Deps

The 32 composables are the highest-quality portable layer. They use standard Composition API (ref, computed, watch, onMounted) that Vue 2.7 fully supports. Patterns like singleton state (module-level refs in useCommandPalette, useColorMode) work identically in Vue 2.7 — module-level reactive state is a language pattern, not a Vue version feature. The `storeToRefs()` pattern from Pinia is available in Pinia 2. The main issues: (1) 3 composables import from @vueuse/core (fixable, see above), (2) u

**Recommendation:** The composable layer is the safest to port. Prioritize fixing the 3 @vueuse/core dependencies and the useToast BVN dependency — these are the only framework-coupled files. The remaining 28 composables are framework-agnostic and will work unchanged (minus TypeScript compilation adjustments for prop t

### [INFO] Percentage Estimates: 15% Works As-Is, 85% Needs Adaptation

Detailed breakdown by layer: Pinia stores (12 files) — 95% portable, only TypeScript generics and Pinia 3→2 version gap matter. Composables (32 files) — 90% portable, 3 files need @vueuse replacement, 1 needs BVN→BV2 toast rewrite. TypeScript types and API modules (50+ .ts files) — 100% portable, pure TypeScript with no Vue dependency. Vue components NOT using script setup (50 of 145) — 70% portable, BVN component names need swapping. Vue components using script setup (95 of 145) — 0% runs as-is

**Recommendation:** If porting is the chosen path, a realistic order of operations is: (1) Port router config (30 min), (2) Port Pinia stores to Pinia 2 (2 hrs, mostly TypeScript cleanup), (3) Port composables — fix @vueuse and BV2 toast (4 hrs), (4) Mechanical script-setup → defineComponent conversion for 95 component

## HAML Views vs v3.x Vue Pages — Migration Coverage Audit (5C 3W)

### [INFO] HAS_V3_EQUIVALENT: projects/index — complete

v2.x: app/views/projects/index.html.haml passes @projects, is_vulcan_admin, can_create_project as JSON props. v3.x: app/javascript/pages/projects/IndexPage.vue uses useProjects composable with await refresh(), gets isAdmin from useAuthStore. Props become API calls: GET /api/v1/projects. Full feature parity including admin flag.

**Recommendation:** No new Vue code needed. Wire GET /api/v1/projects endpoint in v2.x backend to match v3.x api call shape.

### [INFO] HAS_V3_EQUIVALENT: projects/show — complete

v2.x: app/views/projects/show.html.haml passes effective_permissions, initial-project-state, current_user_id, statuses, available_roles. v3.x: app/javascript/pages/projects/ShowPage.vue fetches project via useProjects().fetchById(id), computes effective_permissions client-side from memberships. Includes STATUSES constant in-page. Full parity.

**Recommendation:** No new Vue code needed. effective_permissions is now computed client-side in v3.x — verify the membership data returned by GET /api/v1/projects/:id includes memberships array.

### [INFO] HAS_V3_EQUIVALENT: stigs/index — complete (redirected in v3.x)

v2.x: app/views/stigs/index.html.haml uses BenchmarkListPage component with @stigs_json, is-admin, type='STIG'. v3.x: /stigs redirects to /benchmarks?tab=stig handled by benchmarks/IndexPage.vue via useBenchmarks('stig'). Unified with SRGs/Components in one page.

**Recommendation:** No new Vue code needed. The v3.x unified BenchmarkList is strictly more capable. Rails route for /stigs can redirect to /benchmarks or serve a 301.

### [INFO] HAS_V3_EQUIVALENT: stigs/show — complete

v2.x: app/views/stigs/show.html.haml passes @stig_json as single prop. v3.x: app/javascript/pages/stigs/ShowPage.vue fetches via useStigs().fetchById(id), converts to benchmark via stigToBenchmark(), passes to BenchmarkViewer with deep-link support via ?rule= query param. More capable than v2.x.

**Recommendation:** No new Vue code needed. Verify GET /api/v1/stigs/:id response shape matches IStig type.

### [INFO] HAS_V3_EQUIVALENT: security_requirements_guides/index — complete (redirected)

v2.x: app/views/security_requirements_guides/index.html.haml uses BenchmarkListPage with @srgs_json, is-admin, type='SRG'. v3.x: /srgs redirects to /benchmarks?tab=srg. Same unified BenchmarkList page.

**Recommendation:** No new Vue code needed.

### [INFO] HAS_V3_EQUIVALENT: security_requirements_guides/show — complete

v2.x: app/views/security_requirements_guides/show.html.haml passes single @srg_json prop. v3.x: app/javascript/pages/srgs/ShowPage.vue fetches via useSrgs().fetchById(id), uses BenchmarkViewer with deep-link support.

**Recommendation:** No new Vue code needed.

### [INFO] HAS_V3_EQUIVALENT: components/show (project component editor) — complete

v2.x: app/views/components/show.html.haml has two branches — released component (no auth) and full editor. v3.x: app/javascript/pages/components/ShowPage.vue fetches component + project, computes effective_permissions client-side including inherited memberships. Passes to ProjectComponent with same props. The released-component branch (no auth/permissions) is not separately represented in v3.x routes — ShowPage handles both cases by computing viewer permissions.

**Recommendation:** The separate released_component branch from v2.x should be confirmed handled in v3.x ShowPage. If released components need a read-only view without auth, add a guard or separate route in v3.x.

### [INFO] HAS_V3_EQUIVALENT: components/show (controls/triage) — complete as ControlsPage

v2.x has component_triage.html.haml (triage view) and a separate rules/index.html.haml. v3.x: app/javascript/pages/components/ControlsPage.vue at /components/:id/controls unifies both into table mode (triage) and focus mode (authoring) with LayoutSwitcher. More capable than v2.x triage page.

**Recommendation:** The v2.x triage URLs (project triage and component triage) will need to redirect to /components/:id/controls?mode=table or /projects/:id with appropriate deep-link in v3.x.

### [INFO] HAS_V3_EQUIVALENT: users/index (admin user management) — complete

v2.x: app/views/users/index.html.haml computes token counts in Ruby, passes users JSON, histories, smtp-enabled, password-policy, lockout-enabled. v3.x: admin/UsersPage.vue uses useUsers composable with pagination, filters, search, lock/unlock/reset/delete actions. More capable than v2.x.

**Recommendation:** v3.x Users page lives at /admin/users (admin layout) rather than /users. Ensure Rails redirects /users to /admin/users for admin users. The v2.x Users component is also different from the admin UsersPage — reconcile whether /users should be admin-only or a public profile directory.

### [INFO] HAS_V3_EQUIVALENT: auth pages (forgot-password, unlock, email-confirmation, password-reset) — comple

v2.x: four Devise HAML pages (passwords/new, unlocks/new, confirmations/new, passwords/edit) use server-rendered Bootstrap card_wrapper partial with Rails form_for helpers and smtp-guard conditionals. v3.x: four fully equivalent Vue pages (ForgotPasswordPage, AccountUnlockPage, EmailConfirmationPage, PasswordResetEditPage) with dedicated form components, Bootstrap 5 styling. v3.x routes differ (/auth/forgot-password vs /users/password/new) and will require Rails redirect configuration.

**Recommendation:** Rails must redirect legacy Devise URLs to the v3.x SPA equivalents, or the SPA must be mounted at the legacy paths. The smtp-guard logic (show form vs show 'contact admin' message) must be replicated in the Vue form components via an API flag.

### [INFO] HAS_V3_EQUIVALENT: auth/login — complete

v2.x: app/views/devise/sessions/new.html.haml uses Bootstrap-Vue b-tabs for OIDC/LDAP/local/register tabs, server-rendered conditionals for enabled providers, Devise form_for. v3.x: app/javascript/pages/auth/LoginPage.vue reads provider config from window.vueAppData, renders ProviderButton for OIDC/LDAP, LoginForm for local, RegisterForm for registration — all in one card without tabs. Reads backwards-compat oidcPath/oidcTitle. Different UX than v2.x tabs.

**Recommendation:** The v3.x login page requires window.vueAppData to be injected by the Rails view/layout. This is the one page in v3.x that still depends on server-side data injection (not a pure API call). Ensure the Rails application layout injects authProviders, localLoginEnabled, registrationEnabled into window.v

### [INFO] HAS_V3_EQUIVALENT: users/AccountSettingsPage — complete (partial consolidation)

v2.x splits user settings into 4 separate HAML pages with a shared settings_layout partial: edit (profile), edit/password, edit/activity, edit/tokens. Each has its own pack JS. v3.x: app/javascript/pages/users/AccountSettingsPage.vue is a single page combining profile + password into one form. Activity and tokens sub-pages have no v3.x equivalent yet.

**Recommendation:** Two sub-pages are missing in v3.x: user activity and API tokens. The settings_nav left-rail shell (HAML partial) maps to a single AccountSettingsPage in v3.x — if the SPA keeps sub-page routing, a tabbed or sectioned layout would be needed.

### [INFO] HAS_V3_EQUIVALENT: admin pages — complete (Dashboard, Audit, Settings, Benchmarks)

v2.x has no dedicated admin dashboard, audit, or settings pages — these are new in v3.x (admin/DashboardPage, admin/AuditPage, admin/SettingsPage, admin/BenchmarksPage). They are fully built with proper composables, filters, pagination. These are net-new capabilities in v3.x with no v2.x HAML equivalent. AdminLayout.vue provides the nested routing shell.

**Recommendation:** These are pure gains in v3.x. No migration cost. Verify the API endpoints they depend on (admin stats, audits with pagination/filters, settings read endpoint) exist in the v2.x backend.

### [WARNING] PARTIAL_V3: components/IndexPage — stub only

v2.x: app/views/components/index.html.haml uses BenchmarkListPage with @components_json, is-admin=false, type='Component'. v3.x: app/javascript/pages/components/IndexPage.vue is a TODO stub — 'implementation pending', no useComponents composable wired, no list rendered. In v3.x the route redirects /components to /benchmarks?tab=component, but the standalone IndexPage is incomplete.

**Recommendation:** Either complete components/IndexPage.vue with useComponents composable, or confirm the redirect to benchmarks/IndexPage.vue (tab=component) is the intended UX. If the redirect is the plan, delete the stub to avoid confusion.

### [WARNING] PARTIAL_V3: rules/EditPage — stub only

v2.x: app/views/rules/index.html.haml passes full project, component, rules array, statuses, effective_permissions, current_user_id, available_roles. v3.x: app/javascript/pages/rules/EditPage.vue is a TODO stub — only reads route param, no rule editor rendered. The ControlsPage handles rules in context of a component, but the standalone /rules/:id/edit route has no implementation.

**Recommendation:** This stub needs a full implementation. The v2.x rules/index page is the inline rule editor within a component. Determine if /rules/:id/edit is needed as a standalone route or if ControlsPage fully replaces it. If standalone edit is needed, implement using the RequirementEditor component from v3.x.

### [WARNING] PARTIAL_V3: users/AccountSettingsPage missing activity and tokens sub-pages

v2.x has separate pack files and HAML pages for user_activity (edit_activity.html.haml, histories prop) and user_tokens (edit_tokens.html.haml, usertokens component with no props). v3.x AccountSettingsPage covers profile + password but has no activity feed and no API tokens management. The v3.x users/IndexPage also does not have the comments page equivalent (v2.x users/comments.html.haml with mycommentspage component).

**Recommendation:** Three user settings sub-pages must be built: (1) Activity feed (histories data), (2) API Tokens management (PersonalAccessToken CRUD), (3) My Comments page. All require new API endpoints + Vue components.

### [CRITICAL] NO_V3: projects/triage — no equivalent

v2.x: app/views/projects/triage.html.haml mounts a project-triage component with project_json, effective-permissions, current-user-id. This is the cross-component triage view at the project level. v3.x has no /projects/:id/triage route and no ProjectTriage page component. The ControlsPage handles component-level triage, but not cross-component project-level triage.

**Recommendation:** Must build new Vue page component for project-level triage. Can likely reuse RequirementsTable from ControlsPage with a different data source (project-scope API vs component-scope API). New route: /projects/:id/triage.

### [CRITICAL] NO_V3: components/settings — no equivalent

v2.x: app/views/components/settings.html.haml mounts a componentsettings component with initial-component-state, project, effective-permissions, current-user-id. Component-level settings (name, version, release, prefix, overlay type, etc.) has no dedicated page in v3.x. The ShowPage and ControlsPage do not expose component settings editing.

**Recommendation:** Must build new Vue page component for component settings. New route: /components/:id/settings. Can model after existing componentsettings Vue 2 component in v2.x — needs porting to Vue 3 Composition API.

### [CRITICAL] NO_V3: api_docs/show — no equivalent

v2.x: app/views/api_docs/show.html.haml uses Scalar API reference CDN script + api_docs.js pack. No v3.x page exists for API documentation viewer. This is a standalone page that doesn't need Vue — it's just a div#scalar-docs mount point.

**Recommendation:** Trivial to add: either serve as a non-SPA Rails page (no Vue needed), or add a SPA route that renders a div with the Scalar API reference script. Given it uses a CDN script injection pattern, keeping it as a non-SPA page is simpler.

### [CRITICAL] NO_V3: disa_guide/show — no equivalent

v2.x: app/views/disa_guide/show.html.haml mounts a disa-guide-page component with html-content, page-title, current-page, page-sections, toc. This is the DISA vendor guide documentation viewer (a multi-section rendered document with table of contents). No v3.x page exists.

**Recommendation:** Must build new Vue 3 page component DisaGuidePage. The data (html_content, toc, page_sections) is generated server-side from the DISA guide docx. Port the existing v2.x DisaGuidePage component to Vue 3 Composition API. Route: /disa-guide.

### [CRITICAL] NO_V3: users/comments — no equivalent

v2.x: app/views/users/comments.html.haml conditionally renders inside settings_layout (self) or standalone (viewing another user). Mounts mycommentspage with user-id, user-name, is-self. New in v2.x (PR #717 comment triage feature). No v3.x equivalent exists — the v3.x router has no /users/:id/comments route.

**Recommendation:** Must build new Vue 3 page component for user comment history/triage. This is a v2.x feature that postdates v3.x work. New route: /users/:id/comments. Wire to the comments API added in PR #717.

### [INFO] TRIVIAL: All core business HAML pages are mount-div-only (< 10 lines)

Every v2.x business page HAML (projects, components, stigs, srgs, rules, users) is a trivial mount div passing JSON props. None contain server-rendered HTML content beyond the Vue component tag. The only HAMLs with real server-rendered logic are: sessions/new (Devise form_for, provider conditionals), passwords/new+edit (form_for, smtp guard), confirmations/new (smtp guard), registrations/edit (settings_layout partial), and the card_wrapper/settings_nav partials.

**Recommendation:** The trivial-HAML pattern means the SPA port does not need to replicate any server-rendered content. All data props (effective_permissions, project_json, component_json, statuses, available_roles) become API calls. The layout application.html.haml (navbar props, consent_config, access_requests, locke

### [INFO] Layout: application.html.haml passes 8 props to the Navbar Vue component

app/views/layouts/application.html.haml passes to the Navbar component: navigation (server-built), signed_in, current_user (id/name/email), users_path (admin-only), profile_path, sign_out_path, access_requests, locked_users, consent_config, app_version. The classification banner is server-rendered HAML. In v3.x the App.vue shell handles navigation entirely through the auth store and Vue Router — no server-rendered props needed for the nav.

**Recommendation:** The v3.x App.vue must bootstrap itself by calling GET /api/v1/me (or equivalent) on mount to populate auth state. The access_requests and locked_users counts (used for badge notifications) need dedicated API endpoints if they are not already part of the /me response.

### [INFO] Devise mailer views are not in scope for SPA port

v2.x has 5 Devise mailer HAML files (confirmation_instructions, email_changed, password_change, reset_password_instructions, unlock_instructions) plus 2 user_mailer views. These are email templates, not pages — they are server-rendered and will not be affected by the SPA port.

**Recommendation:** No action needed. Mailer views stay as HAML regardless of frontend migration.

### [INFO] Summary counts: 16 HAS_V3_EQUIVALENT, 3 PARTIAL_V3, 5 NO_V3, 2 TRIVIAL-or-server-only

HAS_V3_EQUIVALENT (16): projects index/show, stigs index/show, srgs index/show, components show/controls, users index (admin), auth login/forgot-password/unlock/email-confirmation/password-reset, admin dashboard/audit/settings/benchmarks. PARTIAL_V3 (3): components IndexPage stub, rules EditPage stub, user settings activity+tokens+comments sub-pages missing. NO_V3 (5): project triage, component settings, api docs, disa guide, user comments. Server-only (2+): mailer templates, classification bann

**Recommendation:** Port plan: (1) Wire existing v3.x pages to v2.x API endpoints — 16 pages, mostly API compatibility work. (2) Complete 3 partial stubs — components/IndexPage, rules/EditPage, user activity/tokens. (3) Build 5 new pages from v2.x component logic — ProjectTriage, ComponentSettings, ApiDocs, DisaGuidePa

## Architecture Migration Strategy: v2.x → v3.x SPA Consolidation (3C 3W)

### [CRITICAL] v3.x SPA is 6 months behind v2.x schema — merging features into v3.x costs ~40 migrations and 8 new

v2.x schema version is 2026-06-04 (113 migrations); v3.x is 2025-12-02 (73 migrations). v2.x has 8 tables entirely absent from v3.x: `component_sync_events`, `merge_operations`, `merge_quarantine`, `personal_access_tokens`, `reactions`, `session_histories`, `sessions`, `triage_response_templates`. The PR #717 comment/triage system represents the largest single block: it requires the `reactions` and `triage_response_templates` tables, 20+ Vue components (TriageSplitView, CommentTriageForm, BulkTr

**Recommendation:** Do not attempt to merge v2.x features into v3.x. The schema and feature gap is too large. The feature work lives in v2.x and should stay there. The frontend migration (Option 3) should be a build-system swap on top of v2.x, not a feature transplant into v3.x.

### [CRITICAL] v2.x is already 60% Vue 3 compatible — the 'port' is much smaller than it appears

v2.x runs Vue 2.7.16, which ships the Vue 3 Composition API as a built-in. All 18 of v2.x's composables already use `import { ref, computed, watch } from 'vue'` — the same import path as Vue 3. Both repos use Pinia 2 with `defineStore`. v2.x already has 0 `$root.$emit` / `$root.$on` / EventBus usage. The 12 components using `setup()` or `<script setup>` will transfer without changes. The 123 remaining components use Options API (`data()` pattern) and will need mechanical translation to `<script

**Recommendation:** The frontend migration path is: (1) swap esbuild for Vite with vite-plugin-ruby, (2) upgrade Vue 2.7 → Vue 3.5, (3) replace bootstrap-vue 2.x → bootstrap-vue-next (API diff is documented in v3.x's BOOTSTRAP-5-MIGRATION-NEEDED.md — primary changes are b-icon removal, BInputGroupPrepend/Append removal

### [CRITICAL] Option 1 (PORT v3.x INTO v2.x) is the wrong framing — the real task is a build-system swap

v3.x's SPA shell is not a 'port' to perform on v2.x — it is a target architecture that v2.x can reach incrementally. The SPA shell components that matter (App.vue, router, Navbar, layouts, CommandPalette, Toaster) total roughly 20 files. The 104 v3.x Vue components are mostly parallel reimplementations of v2.x's 135 components in Vue 3 style. Merging them one-for-one is not required. v2.x's 135 components can be migrated in-place to Vue 3 syntax (with a codemod for `data()` → `ref`, `computed:`

**Recommendation:** Do not treat this as 'port v3.x code files into v2.x'. Treat it as: (1) upgrade the build toolchain in v2.x to Vue 3 + Vite, (2) use a Vue codemod (vue-codemod or @vue/compat mode) to mass-translate Options API components, (3) selectively pull in v3.x's superior redesigned components (requirements/*

### [WARNING] 102 v2.x components use BootstrapVue 2 API — this is the largest concrete migration cost

102 of 135 v2.x Vue components use `b-modal`, `b-table`, `b-form-*`, `b-button`, `b-input`, `b-badge`, or `b-nav` directives. Bootstrap-Vue-Next breaks: `b-icon` (removed, use `<i class='bi bi-...'>`), `BInputGroupPrepend`/`BInputGroupAppend` (removed, use default slot), `BFormRow` (removed, use BRow/BCol), modal `visible` prop → `v-model`. A @vue/compat migration build would catch these at runtime. The v3.x BOOTSTRAP-5-MIGRATION-NEEDED.md is a direct map of what breaks. CSS differences between

**Recommendation:** Prioritize the BootstrapVue API diff as the highest-labor frontend migration item. Create a checklist from v3.x's BOOTSTRAP-5-MIGRATION-NEEDED.md. Run `@vue/compat` mode first to get runtime warnings on all breaking API usages before switching to full Vue 3. Budget 2–3 hours Claude-pace for the Boot

### [WARNING] v2.x has 281 backend specs; v3.x has 59 — the test gap makes v3.x's backend unsafe to rely on

v2.x backend: 281 spec files, 75 request specs, 71 model specs, 12 contract specs (OpenAPI). v3.x backend: 59 spec files, 27 request specs, 12 model specs, 0 contract specs. v2.x covers triage, reactions, PAT auth, merge operations, session limits, Rack::Attack, classification banners, OIDC callbacks, account lockout, consent, and more — none of which exist in v3.x's spec suite. If any work is done in v3.x's Rails layer, these tests must travel with it. The v3.x backend is missing coverage for s

**Recommendation:** The backend must stay in v2.x. There is no path where it makes sense to move Rails controllers, models, and specs to v3.x — the test investment is too asymmetric. Any Rails work (new endpoints, model changes, migrations) happens in v2.x exclusively. The frontend migration is purely a JavaScript/asse

### [WARNING] v2.x has 0 TypeScript; v3.x is fully TypeScript — adding TS is optional but recommended before v3.x

v2.x has 0 .ts files in app/javascript. v3.x has TypeScript throughout (stores are .ts, composables are .ts, pages are .vue with `<script setup lang='ts'>`). When v3.x components (RequirementEditor.vue, CommandPalette.vue, etc.) are pulled into v2.x's upgraded build, they will work without TypeScript if the build is configured for JS-only — esbuild-plugin-ts handles this. However, importing TS components into a non-TS project means losing type safety on props interfaces. The esbuild.config.js in

**Recommendation:** Add TypeScript incrementally as part of the Vite migration rather than trying to add it all at once. New composables and store files can be written in .ts from day one of the Vite swap. Existing .js composables can stay as .js — Vite handles mixed TS/JS projects. v3.x components can be imported with

### [INFO] Recommended sequencing: complete v2.x features first, then do a single frontend migration sprint

Current v2.x active work (PR #717 triage/comments, feat/comment-triage-context-panel branch) is not in v3.x at all and represents the highest product value. Interrupting it to merge codebases creates risk without benefit. The hybrid approach is: (1) land all remaining v2.x feature work (triage, comment period, commenter role, PAT, Login.gov) — these are already designed and partially implemented; (2) once features are stable, execute the frontend migration as a single sprint: Vite swap + Vue 3 u

**Recommendation:** Do not context-switch from active feature development to architectural migration now. The correct moment to do the Vue 3 frontend migration is after the current branch (feat/comment-triage-context-panel) and any remaining planned v2.x features are merged to master. At that point, the migration can b

### [INFO] v3.x's value is as a design reference, not a merge target

v3.x has 180 planning/design/session .md files, a fully working SPA with Vue Router (162-line routes/index.ts, 30 routes), 13 Pinia stores, 30 composables, TypeScript types, and redesigned components (RequirementsTable, CommandPalette, auth pages). These are all directly usable as reference implementations when doing the v2.x frontend migration. The v3.x backend (73 migrations, 59 specs) and v3.x-specific features (pagy pagination, prometheus_exporter, nkf gem) are not needed and should not be m

**Recommendation:** Treat v3.x as a library of solved problems: copy App.vue, router/index.ts, layouts, CommandPalette.vue, auth/* components, and the Pinia store implementations directly into v2.x during the migration sprint. Do not attempt a git merge or rebase between the two repos — cherry-pick specific files. The
