# Vulcan v2.x API Surface Audit Report

## Executive Summary

**Audit Date**: 2026-06-05
**Audited by**: 8 specialized agents (HAML injection, data flow, REST completeness, endpoint coverage, serialization, authorization, OpenAPI alignment, v3.x gap analysis)
**Reference**: v3.x SPA codebase at ~/github/mitre/vulcan-v3.x (14 API clients, 13 Pinia stores, 31 composables)

### Unique Findings by Severity

| Severity | Count |
|----------|-------|
| CRITICAL | 18 |
| WARNING  | 24 |
| INFO     | 13 |
| **Total** | **55** |

### Top 5 Most Critical Gaps

1. **No SPA authentication endpoints** (POST /api/auth/login, DELETE /api/auth/logout, GET /api/auth/me) -- blocks ALL Vue Router migration. Every page needs /me to boot.
2. **No /api/settings or /api/navigation endpoints** -- blocks navbar, banner, consent modal migration. These are on every page.
3. **No /admin/* namespace** (stats, settings, audits, users) -- blocks admin dashboard, user management, and audit log migration. 14 missing endpoints.
4. **effective_permissions has no API endpoint** -- injected on 7 pages, controls all authorization UI. Blocks component/project editor migration.
5. **Raw .to_json / .as_json bypasses Blueprints** -- leaks sensitive fields (encrypted_password, reset_password_token) into DOM. Security issue today, architecture issue for migration.

### Estimated Cards Needed: 19

### Recommended Implementation Order

```
Phase 1 — SPA Foundation (unblocks everything)
  Card 1: GET /api/auth/me, POST /api/auth/login, DELETE /api/auth/logout
  Card 2: GET /api/settings (public, pre-auth)
  Card 3: GET /api/navigation + GET /api/access_requests
  Card 4: effective_permissions in JSON responses

Phase 2 — Admin Namespace (unblocks admin pages)
  Card 5: GET /admin/stats
  Card 6: GET /admin/settings
  Card 7: GET /admin/audits, GET /admin/audits/:id, GET /admin/audits/stats
  Card 8: GET /admin/users (paginated/filtered) + user detail/actions

Phase 3 — Serialization Hygiene (security + correctness)
  Card 9: UserBlueprint admin view (replace raw .as_json)
  Card 10: Fix raw .to_json leaks (Project, User, Component#reviews)
  Card 11: ReviewBlueprint for responses + Component#reviews

Phase 4 — Feature Endpoints (unblocks specific v3.x features)
  Card 12: Find & Replace (5 endpoints)
  Card 13: GET /srgs/latest
  Card 14: POST /components/:id/duplicate
  Card 15: PATCH /rules/:id returns updated rule

Phase 5 — API Consistency & Cleanup
  Card 16: Dead route cleanup (POST /rules/:rule_id/comments)
  Card 17: Contract tests for backup/restore + file upload/export
  Card 18: OpenAPI spec for ComponentShowResponse
  Card 19: Jbuilder deprecation (6 files)
```

---

## Findings by Business Domain

---

### 1. Auth / Session

**Unique findings: 4 CRITICAL, 1 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 1 | CRITICAL | No SPA login endpoint | POST /api/auth/login | 3, 4, 8 |
| 2 | CRITICAL | No SPA logout endpoint | DELETE /api/auth/logout | 3, 4, 8 |
| 3 | CRITICAL | No current-user endpoint | GET /api/auth/me | 1, 2, 3, 4, 8 |
| 4 | CRITICAL | current_user.to_json leaks all User columns in profile/password pages | Fix serialization (use Blueprint) | 1, 5 |
| 5 | INFO | POST /users (registration) returns HTML redirect, no JSON | POST /users (JSON response) | 8 |

**Recommended Card**: `feat: SPA authentication endpoints (api/auth/login, logout, me)` -- sp:5, ~25 min Claude

This is the single most important card. GET /api/auth/me is called on every page load by the v3.x SPA to determine auth state, user identity, permissions, and admin status. Without it, no page can migrate to client-side rendering. The login/logout endpoints replace Devise's HTML-redirect flow with JSON responses suitable for SPA consumption.

**Vue Router blocker**: YES -- nothing works without /api/auth/me.

---

### 2. Navigation & Settings (HAML to API)

**Unique findings: 3 CRITICAL, 1 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 6 | CRITICAL | No public settings/configuration API (banner, consent) | GET /api/settings | 1, 2, 3, 4, 8 |
| 7 | CRITICAL | No navigation API endpoint | GET /api/navigation | 1, 2, 3, 4, 8 |
| 8 | CRITICAL | No access requests listing endpoint | GET /api/access_requests | 3, 4, 8 |
| 9 | WARNING | Navbar receives 9 HAML-injected props with no API fallback | Covered by above endpoints | 1, 2 |

**Recommended Cards**:
- `feat: GET /api/settings -- public pre-auth UI configuration` -- sp:3, ~12 min Claude
- `feat: GET /api/navigation + GET /api/access_requests` -- sp:3, ~12 min Claude

GET /api/settings must be unauthenticated (AC-8 consent banner displays before login). GET /api/navigation requires auth and returns nav links + pending access request notifications.

**Vue Router blocker**: YES -- the app shell (navbar, banner, consent modal) cannot render without these.

---

### 3. Effective Permissions

**Unique findings: 1 CRITICAL, 3 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 10 | CRITICAL | effective_permissions injected on 7 pages with no API endpoint | GET /api/projects/:id/permissions or include in resource responses | 1, 2 |
| 11 | WARNING | Project show page needs effective_permissions in JSON response | Include in GET /projects/:id | 1, 2 |
| 12 | WARNING | Component settings/triage pages need effective_permissions | Include in GET /components/:id | 1, 2 |
| 13 | WARNING | Project triage page needs effective_permissions | Include in GET /projects/:id | 2 |

**Recommended Card**: `feat: Include effective_permissions in project/component JSON responses` -- sp:3, ~12 min Claude

The effective_permissions string ('admin', 'author', 'viewer', nil) controls whether edit buttons, review actions, and admin overrides appear. The cleanest approach is to add it to ProjectBlueprint and ComponentBlueprint responses (gated by current_user context), rather than creating a separate endpoint.

**Vue Router blocker**: YES -- every editor page needs this.

---

### 4. Admin Dashboard

**Unique findings: 2 CRITICAL**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 14 | CRITICAL | No admin stats endpoint | GET /admin/stats | 3, 4, 8 |
| 15 | CRITICAL | No admin settings endpoint | GET /admin/settings | 3, 4, 8 |

**Recommended Cards**:
- `feat: GET /admin/stats -- admin dashboard statistics` -- sp:3, ~12 min Claude
- `feat: GET /admin/settings -- admin configuration viewer` -- sp:3, ~12 min Claude

These are v3.x-only features (v2.x has no admin dashboard page). They can be deferred until after the core editor pages are migrated.

**Vue Router blocker**: No -- only blocks the v3.x admin dashboard, which is new functionality.

---

### 5. Audit Trail

**Unique findings: 1 CRITICAL, 1 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 16 | CRITICAL | No audit log browsing endpoints | GET /admin/audits, GET /admin/audits/:id, GET /admin/audits/stats | 3, 4, 8 |
| 17 | WARNING | User activity page injects histories from HAML | GET /users/:id/activity or GET /api/auth/me/activity | 1, 2 |

**Recommended Card**: `feat: Admin audit log API (GET /admin/audits with pagination/filters)` -- sp:5, ~20 min Claude

The audit log is a new v3.x feature but builds on the existing Audited::Audit model. Pagination, filtering by type/action/user/date, and stats aggregation are all needed.

**Vue Router blocker**: No -- blocks admin audit page only.

---

### 6. Admin User Management

**Unique findings: 1 CRITICAL, 1 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 18 | CRITICAL | All 8 /admin/users/* endpoints missing | GET /admin/users (paginated), GET /admin/users/:id, POST /admin/users/invite, lock/unlock/reset/confirm under /admin/ | 3, 4, 8 |
| 19 | WARNING | GET /users returns different response shape than v3.x expects | GET /users with histories in JSON, or migrate to /admin/users | 5, 8 |

**Recommended Card**: `feat: Admin user management namespace (/admin/users)` -- sp:5, ~20 min Claude

v2.x has user management under /users with lock/unlock/reset scattered as custom routes. v3.x expects everything under /admin/users with pagination, filtering, and a detail endpoint. Options: (a) create new /admin/ namespace pointing to existing logic, (b) alias /admin/users to /users with enhanced JSON responses.

**Vue Router blocker**: Partially -- blocks user management page migration.

---

### 7. Component Management

**Unique findings: 2 CRITICAL, 4 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 20 | CRITICAL | POST /components/:id/duplicate has no v2.x route | POST /components/:id/duplicate | 3, 4, 8 |
| 21 | CRITICAL | Component show page injects 7 props including nested project/rule JSON | Covered by existing endpoints + permissions card | 1, 2 |
| 22 | WARNING | Component settings page is HTML-only, no JSON API | GET /components/:id/settings.json | 3, 4 |
| 23 | WARNING | POST /components/history uses wrong HTTP method in v3.x | Fix v3.x client to use GET, or add POST route | 8 |
| 24 | WARNING | GET /components/:id/export uses query param in v3.x vs path param in v2.x | Align URL patterns | 8 |
| 25 | WARNING | v3.x IComponent expects rules_summary and parent_rules_count not in v2.x Blueprint | Extend ComponentBlueprint | 5 |

**Recommended Cards**:
- `feat: POST /components/:id/duplicate -- dedicated duplication endpoint` -- sp:2, ~8 min Claude
- `fix: Align component export/history URL patterns between v2.x and v3.x` -- sp:2, ~8 min Claude

**Vue Router blocker**: Duplicate endpoint blocks component duplication in SPA. Others are lower priority.

---

### 8. Find & Replace

**Unique findings: 1 CRITICAL**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 26 | CRITICAL | All 5 find_replace endpoints missing | POST /api/components/:id/find_replace/{find, replace_instance, replace_field, replace_all, undo} | 3, 4, 8 |

**Recommended Card**: `feat: Find & Replace API (5 endpoints with undo)` -- sp:8, ~45 min Claude

This is a substantial new feature. v2.x has basic POST /components/:id/find (text search only). v3.x adds replace with instance-level targeting, field-level targeting, and audit-backed undo. This is new functionality, not a migration of existing behavior.

**Vue Router blocker**: No -- only blocks the v3.x find-and-replace feature.

---

### 9. Rule Authoring

**Unique findings: 1 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 27 | WARNING | PATCH /rules/:id does not return updated rule object | PATCH /rules/:id should return {toast, rule} | 8 |

**Recommended Card**: `fix: PATCH /rules/:id returns updated rule in response` -- sp:2, ~8 min Claude

v3.x expects the updated rule object in the response for cache invalidation. v2.x returns only a Toast. This forces an extra GET roundtrip after every save.

**Vue Router blocker**: No -- functional workaround exists (refetch).

---

### 10. Project Management

**Unique findings: 1 WARNING, 1 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 28 | WARNING | ProjectAccessRequest create returns HTML redirect, no JSON | POST /projects/:id/project_access_requests (JSON response) | 3, 7 |
| 29 | INFO | v3.x searchProjects path differs (/projects/search vs /search/projects) | Align URL patterns | 8 |

**Recommended Card**: `fix: ProjectAccessRequest#create returns JSON + align search paths` -- sp:2, ~8 min Claude

**Vue Router blocker**: Access request creation blocks SPA project access workflow.

---

### 11. Review / Triage

**Unique findings: 1 WARNING, 1 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 30 | WARNING | Triage pages (components, projects) are HTML-only, block SPA migration | Client-side routes (no new endpoints needed) | 3, 4 |
| 31 | INFO | Reviews resource lacks standard show endpoint | GET /reviews/:id | 3 |

These are not API gaps per se -- triage and settings pages should become client-side routes in the SPA, using the same underlying data endpoints (components, projects, comments) that already exist.

**Vue Router blocker**: No -- existing data endpoints suffice.

---

### 12. Export / Import

**Unique findings: 2 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 32 | WARNING | Export endpoints are HTML-only (send_data), awkward for SPA | GET /components/:id/export/:type (with blob response) | 3, 4 |
| 33 | WARNING | bulk_export allows any authenticated user to export released components without project membership | Authorization check on GET /components/bulk_export/:type | 6 |

**Recommended Cards**:
- `fix: Export endpoints support SPA download pattern (blob or download URL)` -- sp:3, ~12 min Claude
- `fix: bulk_export checks project membership for unreleased components` -- sp:2, ~8 min Claude

**Vue Router blocker**: Export is a secondary flow -- not a migration blocker.

---

### 13. Search

**Unique findings: 1 WARNING, 1 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 34 | WARNING | Api::SearchController builds inline hash maps for 7 types without Blueprints | Refactor to use Blueprints | 5 |
| 35 | INFO | Api::UserSearchController uses inline hash identical to UserBlueprint default | Use UserBlueprint | 5 |

**Recommended Card**: `refactor: SearchController uses Blueprints instead of inline hash maps` -- sp:3, ~12 min Claude

**Vue Router blocker**: No -- search works, just uses inconsistent serialization.

---

### 14. SRG/STIG Management

**Unique findings: 1 WARNING, 2 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 36 | WARNING | No GET /srgs/latest endpoint | GET /srgs/latest | 3, 4, 8 |
| 37 | INFO | STIG/SRG missing update (PATCH) action | PATCH /stigs/:id, PATCH /srgs/:id | 3 |
| 38 | INFO | STIG/SRG index/show endpoints already exist and work | None | 1, 2 |

**Recommended Card**: `feat: GET /srgs/latest -- latest version per SRG for dropdown population` -- sp:2, ~8 min Claude

**Vue Router blocker**: Partially -- blocks SRG dropdown in component creation.

---

### 15. Blueprint / Serialization Gaps

**Unique findings: 4 CRITICAL, 5 WARNING, 2 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 39 | CRITICAL | UsersController renders all JSON via raw .as_json -- no Blueprint | Create UserBlueprint :admin view | 5 |
| 40 | CRITICAL | Component#reviews returns raw Review.as_json -- bypasses ReviewBlueprint | Use ReviewBlueprint in Component#reviews | 5 |
| 41 | CRITICAL | @component.project.to_json in 3 HAML templates leaks all Project columns | Use ProjectBlueprint | 1, 5 |
| 42 | CRITICAL | ReviewsController#responses hand-builds reply hashes | Use ReviewBlueprint | 5 |
| 43 | WARNING | ApplicationController locked_users uses raw .as_json | Use UserBlueprint | 5 |
| 44 | WARNING | TriageResponseTemplate serialized via inline method | Create TriageResponseTemplateBlueprint | 5 |
| 45 | WARNING | ComponentBlueprint :editor uses additional_questions.as_json | Create AdditionalQuestionBlueprint | 5 |
| 46 | WARNING | v3.x IUserDetail expects fields not in any v2.x serializer | Extend UserBlueprint with :detail view | 5 |
| 47 | WARNING | Six jbuilder templates duplicate Blueprint serialization | Deprecate jbuilder files | 5 |
| 48 | INFO | ComponentsController#based_on_same_srg uses intentional inline hash | Documented as intentional | 5 |
| 49 | INFO | ProjectBlueprint :show renders access_requests with inline hash | Minor cleanup | 5 |

**Recommended Cards**:
- `fix: UserBlueprint admin view replaces raw .as_json in UsersController` -- sp:3, ~12 min Claude
- `fix: Eliminate raw .to_json leaks (Project in HAML, User in Devise views)` -- sp:3, ~12 min Claude
- `fix: ReviewBlueprint for Component#reviews and responses endpoint` -- sp:3, ~12 min Claude
- `chore: Deprecate 6 jbuilder templates in favor of Blueprints` -- sp:2, ~8 min Claude

**Vue Router blocker**: The .to_json leaks are a security issue today. Blueprint consistency is needed before migration.

---

### 16. OpenAPI Spec Gaps

**Unique findings: 1 CRITICAL, 4 WARNING, 3 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 50 | CRITICAL | Dead route POST /rules/:rule_id/comments maps to non-existent controller | Remove dead route | 6, 7 |
| 51 | WARNING | Missing ComponentShowResponse schema (non-member view) | Add schema to OpenAPI spec | 7 |
| 52 | WARNING | No contract tests for backup/restore endpoints | Add contract tests | 7 |
| 53 | WARNING | No contract tests for file upload endpoints (detect_srg, spreadsheet) | Add contract tests | 7 |
| 54 | WARNING | No contract tests for export endpoints | Add contract tests | 7 |
| 55 | INFO | POST /projects/:id/project_access_requests spec documents HTML-only endpoint | Remove from OpenAPI or add JSON support | 7 |
| 56 | INFO | Reviews/histories schema items typed as generic object | Add property definitions | 7 |
| 57 | INFO | Spec version 3.2.0, all 80 path files valid, lint passes | No action | 7 |

**Recommended Cards**:
- `fix: Remove dead POST /rules/:rule_id/comments route` -- sp:1, ~5 min Claude
- `test: Contract tests for backup/restore + file upload + export endpoints` -- sp:5, ~20 min Claude
- `docs: ComponentShowResponse schema in OpenAPI spec` -- sp:2, ~8 min Claude

**Vue Router blocker**: Dead route is a bug today. Contract test gaps are quality debt.

---

### 17. Authorization Matrix Gaps

**Unique findings: 2 WARNING, 4 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 33 | WARNING | bulk_export bypasses project membership check | Add authorization | 6 |
| 58 | WARNING | PersonalAccessTokens admin_revoke uses inline auth instead of before_action | Refactor to before_action pattern | 6 |
| 59 | INFO | Users#comments code/comment contradict on access scope | Fix comment or add self-only guard | 6 |
| 60 | INFO | ApiDocsController requires auth -- may conflict with public docs goal | Intentional, note for future | 6 |
| 61 | INFO | CSRF correctly configured with API token bypass | No action | 6 |
| 62 | INFO | ConsentController correctly skips auth for AC-8 | No action | 6 |

**Recommended Card**: `fix: bulk_export authorization + admin_revoke before_action pattern` -- sp:2, ~8 min Claude

**Vue Router blocker**: No -- authorization correctness issue, not migration blocker.

---

### 18. DISA Guide

**Unique findings: 1 WARNING**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 63 | WARNING | DISA Guide page injects rendered HTML with no API endpoint | GET /api/disa-guide/:page | 1, 2 |

**Recommended Card**: `feat: GET /api/disa-guide/:page -- DISA guide content API` -- sp:3, ~12 min Claude

**Vue Router blocker**: Only blocks DISA guide page migration.

---

### 19. Static Constants & Misc

**Unique findings: 2 INFO**

| # | Severity | Title | Endpoint Needed | Agents |
|---|----------|-------|-----------------|--------|
| 64 | INFO | Static constants (STATUSES, ROLES) injected from Ruby on 3 pages | Hardcode in frontend config | 1, 2 |
| 65 | INFO | current_user.id injected on 6 pages as separate prop | Covered by GET /api/auth/me | 1, 2 |

No card needed -- constants go in frontend config, current_user.id comes from /api/auth/me.

---

## v3.x API Client to v2.x Endpoint Comparison Table

### auth.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| login() | POST /api/auth/login | None | **MISSING** |
| logout() | DELETE /api/auth/logout | DELETE /users/sign_out (HTML) | **MISSING** |
| getCurrentUser() | GET /api/auth/me | None | **MISSING** |
| register() | POST /users | POST /users (Devise, HTML redirect) | PARTIAL |
| getProfile() | GET /users/edit | GET /users/edit (HTML) | PARTIAL |
| updateProfile() | PATCH /users | PATCH /users (Devise) | EXISTS |
| changePassword() | PATCH /users | PATCH /users (Devise) | EXISTS |
| requestPasswordReset() | POST /users/password | POST /users/password (Devise) | EXISTS |
| validateResetToken() | GET /users/password/edit | GET /users/password/edit (HTML) | PARTIAL |
| resetPassword() | PATCH /users/password | PATCH /users/password (Devise) | EXISTS |

### settings.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| fetchSettings() | GET /api/settings | None | **MISSING** |

### navigation.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getNavigation() | GET /api/navigation | None | **MISSING** |
| getAccessRequests() | GET /api/access_requests | None | **MISSING** |

### admin.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getStats() | GET /admin/stats | None | **MISSING** |
| getSettings() | GET /admin/settings | None | **MISSING** |

### audits.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getAudits() | GET /admin/audits | None | **MISSING** |
| getAuditDetail() | GET /admin/audits/:id | None | **MISSING** |
| getAuditStats() | GET /admin/audits/stats | None | **MISSING** |

### users.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getUsers() | GET /admin/users | GET /users (different shape) | PARTIAL |
| getUserDetail() | GET /admin/users/:id | None | **MISSING** |
| inviteUser() | POST /admin/users/invite | POST /users/admin_create (different path) | PARTIAL |
| lockUser() | POST /admin/users/:id/lock | POST /users/:id/lock (different path) | PARTIAL |
| unlockUser() | POST /admin/users/:id/unlock | POST /users/:id/unlock (different path) | PARTIAL |
| resetUserPassword() | POST /admin/users/:id/reset_password | POST /users/:id/send_password_reset (different path) | PARTIAL |
| resendConfirmation() | POST /admin/users/:id/resend_confirmation | None | **MISSING** |
| updateUser() | PATCH /admin/users/:id | PATCH /users/:id (different path) | PARTIAL |
| deleteUser() | DELETE /admin/users/:id | DELETE /users/:id (different path) | PARTIAL |

### projects.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getProjects() | GET /projects | GET /projects.json | EXISTS |
| getProject() | GET /projects/:id | GET /projects/:id.json | EXISTS |
| createProject() | POST /projects | POST /projects | EXISTS |
| updateProject() | PATCH /projects/:id | PATCH /projects/:id | EXISTS |
| deleteProject() | DELETE /projects/:id | DELETE /projects/:id | EXISTS |
| searchProjects() | GET /projects/search | GET /search/projects (different path) | PARTIAL |
| exportProject() | GET /projects/:id/export | GET /projects/:id/export/:type (path param) | PARTIAL |
| createFromBackup() | POST /projects/create_from_backup | POST /projects/create_from_backup | EXISTS |
| importBackup() | POST /projects/:id/import_backup | POST /projects/:id/import_backup | EXISTS |

### components.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getComponents() | GET /components | GET /components.json | EXISTS |
| getComponent() | GET /components/:id | GET /components/:id.json | EXISTS |
| createComponent() | POST /projects/:pid/components | POST /projects/:pid/components | EXISTS |
| updateComponent() | PATCH /components/:id | PATCH /components/:id | EXISTS |
| deleteComponent() | DELETE /components/:id | DELETE /components/:id | EXISTS |
| duplicateComponent() | POST /components/:id/duplicate | None (uses create with flag) | **MISSING** |
| exportComponent() | GET /components/:id/export?type= | GET /components/:id/export/:type (path param) | PARTIAL |
| getRevisionHistory() | POST /components/history | GET /components/history (wrong HTTP method) | PARTIAL |
| searchComponents() | GET /components/search | GET /search/components (different path) | PARTIAL |
| detectSrg() | POST /components/detect_srg | POST /components/detect_srg | EXISTS |
| previewSpreadsheet() | POST /components/:id/preview_spreadsheet_update | POST /components/:id/preview_spreadsheet_update | EXISTS |
| applySpreadsheet() | PATCH /components/:id/apply_spreadsheet_update | PATCH /components/:id/apply_spreadsheet_update | EXISTS |

### rules.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getRules() | GET /components/:cid/rules | GET /components/:cid/rules.json | EXISTS |
| getRule() | GET /rules/:id | GET /rules/:id.json | EXISTS |
| createRule() | POST /components/:cid/rules | POST /components/:cid/rules | EXISTS |
| updateRule() | PATCH /rules/:id | PATCH /rules/:id (missing rule in response) | PARTIAL |
| deleteRule() | DELETE /rules/:id | DELETE /rules/:id | EXISTS |

### srgs.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getSrgs() | GET /srgs | GET /security_requirements_guides.json | EXISTS |
| getSrg() | GET /srgs/:id | GET /security_requirements_guides/:id.json | EXISTS |
| getLatestSrgs() | GET /srgs/latest | None | **MISSING** |
| uploadSrg() | POST /srgs | POST /security_requirements_guides | EXISTS |
| deleteSrg() | DELETE /srgs/:id | DELETE /security_requirements_guides/:id | EXISTS |
| exportSrg() | GET /srgs/:id/export/:type | GET /security_requirements_guides/:id/export/:type | EXISTS |

### stigs.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getStigs() | GET /stigs | GET /stigs.json | EXISTS |
| getStig() | GET /stigs/:id | GET /stigs/:id.json | EXISTS |
| uploadStig() | POST /stigs | POST /stigs | EXISTS |
| deleteStig() | DELETE /stigs/:id | DELETE /stigs/:id | EXISTS |
| exportStig() | GET /stigs/:id/export/:type | GET /stigs/:id/export/:type | EXISTS |

### members.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| searchUsers() | GET /api/projects/:pid/search_users | GET /api/users/search (different path + params) | PARTIAL |
| createMembership() | POST /memberships | POST /memberships | EXISTS |
| updateMembership() | PATCH /memberships/:id | PATCH /memberships/:id | EXISTS |
| deleteMembership() | DELETE /memberships/:id | DELETE /memberships/:id | EXISTS |

### findReplace.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| find() | POST /api/components/:id/find_replace/find | POST /components/:id/find (basic only) | PARTIAL |
| replaceInstance() | POST /api/components/:id/find_replace/replace_instance | None | **MISSING** |
| replaceField() | POST /api/components/:id/find_replace/replace_field | None | **MISSING** |
| replaceAll() | POST /api/components/:id/find_replace/replace_all | None | **MISSING** |
| undo() | POST /api/components/:id/find_replace/undo | None | **MISSING** |

### github.api.ts

| v3.x Function | v3.x Endpoint | v2.x Route | Status |
|---------------|---------------|------------|--------|
| getLatestRelease() | https://api.github.com/... | N/A (client-side only) | N/A |

---

## Summary Statistics

| Category | EXISTS | PARTIAL | MISSING | Total |
|----------|--------|---------|---------|-------|
| Auth | 3 | 3 | 3 | 9 |
| Settings | 0 | 0 | 1 | 1 |
| Navigation | 0 | 0 | 2 | 2 |
| Admin | 0 | 0 | 2 | 2 |
| Audits | 0 | 0 | 3 | 3 |
| Users (admin) | 0 | 5 | 2 | 7 |
| Projects | 7 | 2 | 0 | 9 |
| Components | 6 | 3 | 1 | 10 |
| Rules | 3 | 1 | 0 | 4 |
| SRGs | 4 | 0 | 1 | 5 |
| STIGs | 4 | 0 | 0 | 4 |
| Members | 3 | 1 | 0 | 4 |
| Find/Replace | 0 | 1 | 4 | 5 |
| **Total** | **30** | **16** | **19** | **65** |

- **30 endpoints** (46%) fully exist and are compatible
- **16 endpoints** (25%) exist but have path, method, or response shape mismatches
- **19 endpoints** (29%) are completely missing from v2.x

---

## v2.x-Only Endpoints (No v3.x Client)

These 22 endpoints exist in v2.x but have no v3.x API client. They must be preserved during migration:

1. POST /users/admin_create
2. POST /users/:id/generate_reset_link
3. POST /users/:id/set_password
4. GET /users/:id/comments
5. GET/POST/DELETE /personal_access_tokens (full CRUD)
6. DELETE /personal_access_tokens/:id/admin_revoke
7. POST /components/detect_srg
8. POST /components/:id/preview_spreadsheet_update
9. PATCH /components/:id/apply_spreadsheet_update
10. GET /components/:id/related (based_on_same_srg)
11. GET /components/bulk_export/:type
12. GET /components/:id/histories, GET /projects/:id/histories
13. POST /projects/create_from_backup, POST /projects/:id/import_backup
14. PATCH /reviews/bulk_triage, PATCH /reviews/merge
15. PATCH /reviews/:id/admin_withdraw, admin_restore, admin_destroy
16. PATCH /reviews/:id/move_to_rule, PATCH /reviews/:id/section
17. GET /reviews/:id/responses
18. PATCH /rules/:id/section_locks, PATCH /rules/:id/bulk_section_locks
19. POST /reviews/:review_id/reactions
20. GET/POST/PATCH/DELETE /projects/:id/triage_response_templates
21. GET /components/:id/rules_picker
22. POST /consent/acknowledge
