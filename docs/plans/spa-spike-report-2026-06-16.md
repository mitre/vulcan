# SPA Phase-0 Spike Report

**Date:** 2026-06-16
**Status:** Complete
**Card:** v2-aiz
**Decider:** Aaron Lippold

## Question

Which API endpoints does the SPA actually need, and what's the gap between
v2.x's current surface and v3.x's requirements?

## Method

Compared v2.x OpenAPI spec (117 documented endpoints) against v3.x API modules
(71 function calls across 14 modules). Cross-referenced v3.x Pinia stores and
composables against v2.x equivalents.

## Findings

### The API gap is smaller than expected

| Category | Count | Action |
|----------|------:|--------|
| v3.x calls that v2.x HAS | 36 | Ready to use |
| v3.x calls that exist in v2.x but UNDOCUMENTED | 19 | Add to OpenAPI + contract tests |
| v3.x calls that are TRULY MISSING | 16 | Build new endpoints |
| v2.x endpoints v3.x doesn't use yet | ~45 | Port incrementally with pages |

### Undocumented endpoints (19) — exist in Rails, need OpenAPI docs

These are Devise endpoints and profile management routes that Rails provides
but we never added to the OpenAPI spec:

**Devise auth flows (7):**
- POST `/users/confirmation` — resend confirmation
- POST `/users/unlock` — resend unlock
- POST `/users/password` — request password reset
- GET `/users/password/edit` — validate reset token
- PUT `/users/password` — execute password reset
- GET `/users/edit` — get profile
- PUT `/users` — update profile

**User management (3):**
- DELETE `/users` — self-delete account
- POST `/users/{id}/lock` — lock user (exists, different path from v3.x)
- POST `/users/{id}/unlock` — unlock user

**Misc (9):**
- GET `/api/access_requests` — pending access requests
- GET `/api/settings/consent_banner` — consent config
- GET `/projects/search` — search projects
- POST `/components/{id}/rules` — create rule via component
- POST `/users/{id}/send_password_reset` — admin send reset
- POST `/consent/acknowledge` — acknowledge consent
- GET `/api/users/search` — user search
- GET `/api/search/global` — global search
- GET `/api/version` — API version

### Truly missing endpoints (16) — need new controller actions

**Admin users namespace (7):**
- GET `/admin/users` — paginated admin list
- GET `/admin/users/{id}` — admin user detail
- PATCH `/admin/users/{id}` — admin user update
- DELETE `/admin/users/{id}` — admin user delete
- POST `/admin/users/{id}/resend_confirmation` — admin resend
- POST `/admin/users/invite` — invite new user
- GET `/admin/stats` — dashboard statistics

**Audit trail viewer (3):**
- GET `/admin/audits` — filterable audit log
- GET `/admin/audits/{id}` — audit detail
- GET `/admin/audits/stats` — audit statistics

**Find & Replace (5):**
- POST `/api/components/{id}/find_replace/find`
- POST `/api/components/{id}/find_replace/replace_instance`
- POST `/api/components/{id}/find_replace/replace_field`
- POST `/api/components/{id}/find_replace/replace_all`
- POST `/api/components/{id}/find_replace/undo`

**SRG versions (1):**
- GET `/srgs/latest` — latest SRG per family

### Store/composable portability

| Status | Stores | Composables |
|--------|-------:|------------:|
| PORT_DIRECTLY | 5 | 6 |
| ADAPT | 4 | 13 |
| REBUILD (needs new endpoints) | 3 | 6 |
| ALREADY_EXISTS_V2 | — | 9 |

### v2.x features not yet in v3.x (~45 endpoints)

Comment triage system, review lifecycle, section locks, PAT management,
backup/restore, bulk export, merge engine, spreadsheet import, satisfaction
management, triage response templates. These get SPA views incrementally
as pages migrate — they are NOT blockers for the SPA shell.

## Recommendation

**v2-btu (39 cards) should be re-scoped to 3 phases:**

### Phase A — Document undocumented (19 endpoints, ~sp:8)
Pure OpenAPI + contract test work. No new code. Unblocks v3.x stores
that call these endpoints.

### Phase B — Build missing (16 endpoints, ~sp:21)
New controller actions grouped by domain:
1. Admin users namespace (sp:8)
2. Audit trail viewer (sp:5)
3. Find & Replace API (sp:5)
4. SRG latest versions (sp:3)

### Phase C — Port SPA architecture
After Phase A+B, the API surface supports all v3.x stores. Port:
1. Vue Router shell + auth guard
2. Pinia stores (5 direct, 4 adapted)
3. Composables (port + merge with existing v2.x ones)
4. Page migration (one page at a time, starting with simplest)

### What to DEFER (the 45 v2.x-only endpoints)
These features work today via HAML+Vue. They get SPA views when their
page migrates — not before. No upfront API work needed.

## Impact on v2-btu

The 39-card v2-btu epic was built before this spike. Many of its cards
overlap with Phase A+B above, and many target endpoints the SPA doesn't
need yet. Re-scope v2-btu to match these findings.
