# ADR: DISA Library Service — Catalog Sync, Version Currency, One-Click Import

**Status:** Proposed
**Date:** 2026-06-15
**Deciders:** Aaron Lippold
**Epic:** v2-54tg (VersionCurrency) + new epic (DISA Library Service)

## Context

Vulcan helps teams author STIGs by building on top of SRGs (Security Requirements
Guides) published by DISA. Staying current with DISA's baseline releases is critical
— an outdated SRG means the authored STIG won't align with current requirements.

### Problems today

1. **No awareness of upstream updates.** Users have no way to know if DISA published
   a newer SRG or STIG without manually checking cyber.mil. A component based on
   "Web Server SRG V3R3" shows no indication that V4R4 exists.

2. **Manual, indirect import pipeline.** The existing `stig_and_srg_puller:pull` rake
   task fetches from a GitHub repo (`mitre/inspec-profile-update-action/stigs.json`)
   — a stale intermediary, not DISA directly. Admins must run a CLI command; there's
   no in-app way to browse or import.

3. **No version currency signal.** The SRG, STIG, and Component list pages show no
   green/yellow indicator for whether a record is current or outdated. Users discover
   staleness only when DISA reviewers flag it during STIG submission.

### Discovery (2026-06-15)

The DISA Cyber Exchange at `https://www.cyber.mil/stigs/downloads` runs on
**Salesforce Experience Cloud**. The STIG/SRG catalog is served by a single
unauthenticated Apex API call:

```http
POST https://www.cyber.mil/webruntime/api/apex/execute
     ?language=en-US&asGuest=true&htmlEncode=false
Content-Type: application/json

{
  "namespace": "",
  "classname": "@udd/01pRw0000002mOj",
  "method": "getCyberDocumentCatalogByDocumentLibrary",
  "isContinuation": false,
  "params": { "documentLibrary": "STIGs" },
  "cacheable": false
}
```

Returns ~400 entries (25 SRGs + 324 STIGs + tools/docs) with:

| Field | Example |
|-------|---------|
| `FileName` | "General Purpose Operating System SRG - Ver 3, Rel 3" |
| `DownloadLink` | `https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_GPOS_SRG_V3R3_Manual-xccdf.zip` |
| `UploadDate` | "2024-06-06" |
| `RawDownloadType` | "General Purpose OS;STIGs" |

**No Playwright/browser automation needed.** Verified with raw `curl` — one HTTP POST,
one JSON response, ~200ms. The stig-manager project's `disaScraper.js` uses Playwright
unnecessarily for this; a finding has been documented in that repo.

### Decision drivers

- Aaron (2026-06-15): "Keep the list current, let users download STIGs and SRGs with
  a cache, query every 24 hours, and expose it in the Vulcan API."
- The version currency dots (green/yellow on list pages) require knowing what's
  available upstream, not just what's imported locally.
- The existing puller should go direct to DISA instead of through a GitHub intermediary.
- Air-gapped deployments must continue to work (manual upload, no network requirement).

## Decision

### Three-layer architecture

```
Layer 1: Catalog Cache
  DISA Apex API → disa_catalog_entries table → refreshed every 24h

Layer 2: Version Currency
  catalog entries ↔ local SRGs/STIGs → is_latest computation
  → green/yellow dots on all list pages

Layer 3: Download + Import
  Admin clicks "Import" → fetch ZIP from dl.dod.cyber.mil
  → extract XCCDF → existing Benchmark.parse pipeline
```

### Layer 1 — Catalog Cache

**Table: `disa_catalog_entries`**

| Column | Type | Description |
|--------|------|-------------|
| `disa_filename` | text | Raw FileName from DISA ("...STIG - Ver N, Rel M") |
| `normalized_title` | text | Lowercase, stripped of "STIG"/"SRG"/version suffix |
| `parsed_version` | text | Extracted "V{N}R{M}" for numeric comparison |
| `download_url` | text | Direct ZIP URL on dl.dod.cyber.mil |
| `upload_date` | date | DISA's publish date |
| `raw_download_type` | text | Semicolon-separated categories |
| `entry_kind` | text | "stig", "srg", "tool", or "document" (parsed from type + filename) |
| `matched_record_type` | text | "SecurityRequirementsGuide" or "Stig" (polymorphic) |
| `matched_record_id` | integer | FK to the local record, null if not imported |
| `update_available` | boolean | True if parsed_version > local record's version |
| `last_seen_at` | timestamp | Tracks catalog removals (entry not in latest fetch) |

**Unique constraint:** `download_url` (each ZIP URL appears once in the catalog).

**Service class: `DisaCatalogService`**

```ruby
DisaCatalogService.refresh!            # POST to DISA, upsert entries, match against local
DisaCatalogService.catalog             # all cached entries (refresh if stale)
DisaCatalogService.updates_available   # entries where update_available=true
DisaCatalogService.stale?              # last refresh > 24h ago
DisaCatalogService.download!(entry)    # fetch ZIP, extract XCCDF, import
DisaCatalogService.last_refreshed_at   # timestamp
```

**Matching engine:** Normalize DISA filenames and local SRG/STIG titles using the
same algorithm. Version comparison uses `VersionSortable`'s SQL-based `V{N}R{M}`
parsing — no string comparison.

```ruby
# DISA: "General Purpose Operating System SRG - Ver 3, Rel 3"
#   → normalized: "general purpose operating system"
#   → version: "V3R3"
#   → kind: "srg"

# Local: SecurityRequirementsGuide title="General Purpose Operating System Security Requirements Guide"
#   → normalized: "general purpose operating system"
#   → version: "V3R3"
#   → match! update_available: false (same version)
```

### Layer 2 — Version Currency

Extend the existing `VersionSortable` concern (already on SRG + Stig models) with:

- `is_latest?` — true if this is the highest local version of its family
- `is_current_with_disa?` — true if no newer version exists in the catalog
- `latest_available` — the catalog entry for the newest version (for linking)

Three-state dot indicator:

| State | Dot | Meaning | Click action |
|-------|-----|---------|-------------|
| Current | Green | Latest version locally AND on DISA | None |
| Local update | Yellow | Newer version already imported locally | Navigate to local SRG/STIG |
| DISA update | Orange | Newer version on DISA, not yet imported | Navigate to catalog → Import |

Surfaces on: SRG list, STIG list, Component list (via `based_on` SRG), comment
triage sidebar, comment table Rule column.

### Layer 3 — Download + Import

Admin-only action. One-click from the catalog browser or from a yellow/orange dot:

1. Fetch ZIP from `dl.dod.cyber.mil` (direct, no auth)
2. Extract XCCDF XML from ZIP (same logic as current puller)
3. Import via `Xccdf::Benchmark.parse` + `model.from_mapping` (existing pipeline)
4. Update `disa_catalog_entries.matched_record_id` + clear `update_available`
5. Audit trail via `VulcanAudit.with_correlation_scope`

### Background Refresh — SolidQueue

Rails 8 ships SolidQueue. Vulcan's Puma config already has
`plugin :solid_queue if ENV['SOLID_QUEUE_IN_PUMA']` — runs inside the web process,
no separate worker needed.

```yaml
# config/recurring.yml
disa_catalog_refresh:
  class: DisaCatalogRefreshJob
  schedule: every day at 4am
```

Setup: `solid_queue` gem + one migration (SolidQueue tables) + `config/recurring.yml`.

### API Surface

```
GET  /api/disa_catalog                — list cached catalog entries (filterable by kind)
GET  /api/disa_catalog/updates        — entries with update_available=true
POST /api/disa_catalog/refresh        — trigger manual re-sync (admin)
POST /api/disa_catalog/:id/import     — download + import (admin)
GET  /api/disa_catalog/status         — last_refreshed_at, entry_count, updates_count
```

All endpoints admin-only except `status` (any authenticated user).

### Air-Gapped Deployments

- Network access to cyber.mil is **optional** — the service degrades gracefully
- If refresh fails (network error, timeout), stale cache is preserved
- Admin upload of SRGs/STIGs via file still works as the primary path
- The catalog page shows "Catalog unavailable — upload manually" when no cache exists
- `VULCAN_DISA_CATALOG_ENABLED=false` disables the service entirely (default: true)

## Alternatives Considered

### A. Keep the GitHub intermediary (`stigs.json`)

The current puller fetches from `mitre/inspec-profile-update-action/stigs.json`.
Rejected: stale intermediary, no SRGs, requires GitHub access (not DISA-direct),
doesn't support version currency comparison.

### B. Playwright browser scraping

The stig-manager project scrapes the DISA page with headless Chromium. Rejected:
unnecessary — the underlying Salesforce Apex API returns the same data in one
unauthenticated POST. Playwright adds ~500MB Chromium dependency, is slower (~30s
vs ~200ms), and is fragile to DOM changes.

### C. No background job — cron-only

Use system cron to run a rake task every 24h. Rejected: SolidQueue is Rails 8
native, runs inside Puma (no separate process), provides monitoring + retry +
recurring job config in one YAML file. The infrastructure cost is one gem + one
migration.

### D. Cache in Rails.cache instead of database

Store catalog entries in Rails.cache (memory/Redis). Rejected: not queryable
(can't JOIN against SRGs/STIGs), lost on restart, can't diff against previous
fetch, can't track `last_seen_at` for removed entries.

## Consequences

### Positive

- Users see at a glance whether their baselines are current (green/yellow/orange dots)
- One-click import from within Vulcan replaces CLI rake task + manual cyber.mil browsing
- Vulcan API exposes the catalog for automation and SPA consumption
- Direct DISA source replaces the stale GitHub intermediary
- SolidQueue infrastructure enables future background jobs (email, export generation)

### Negative

- New table + service + API endpoints — moderate implementation scope
- Salesforce Apex classname (`@udd/01pRw0000002mOj`) is org-specific and could change
  if DISA redeploys their Experience Cloud site — needs monitoring + fallback
- SolidQueue migration adds ~8 tables to the schema (one-time)

### Risks

- **DISA API stability:** The Apex endpoint is unauthenticated and undocumented.
  DISA could add auth, change the classname, or restructure the response. Mitigation:
  monitor for non-200 responses, fall back to stale cache, alert admin.
- **Download reliability:** `dl.dod.cyber.mil` may be slow or require VPN/CAC for
  some content. The existing puller already handles this; same risk profile.

## Implementation Order

### Phase 1 — VersionCurrency (local-only, epic v2-54tg)

Already carded:
1. `.1` VersionSortable `is_latest?` + `latest_for_family` concern
2. `.2` Blueprint fields + OpenAPI schemas
3. `.3` Green/yellow dots on all list pages + click-to-navigate

### Phase 2 — DISA Library Service (new epic)

1. SolidQueue setup — gem, migration, recurring.yml, Puma plugin env var
2. `disa_catalog_entries` migration + `DisaCatalogEntry` model
3. `DisaCatalogService` — HTTP client + parser + matcher + refresh logic
4. `DisaCatalogRefreshJob` — SolidQueue recurring job (24h)
5. Admin UI — catalog browser page with filter/search/import
6. API endpoints — `/api/disa_catalog/*`
7. Wire into VersionCurrency — orange dot for DISA-only updates
8. Deprecate `stig_and_srg_puller:pull` — replaced by catalog service

## References

- DISA Cyber Exchange: https://www.cyber.mil/stigs/downloads
- Salesforce Experience Cloud Apex API (undocumented, discovered 2026-06-15)
- stig-manager disaScraper.js: `/Users/alippold/github/mitre/stig-manager/api/source/utils/disaScraper.js`
- Existing puller: `lib/tasks/stig_and_srg_puller.rake`
- VersionSortable concern: `app/models/concerns/version_sortable.rb`
- SolidQueue: https://github.com/rails/solid_queue (Rails 8 default)
