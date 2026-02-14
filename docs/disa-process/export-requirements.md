# Export Requirements and Architecture

Analysis of Vulcan's export system against DISA requirements, with known gaps and planned improvements.

## Export Formats

### DISA Spreadsheet (Primary Deliverable)

The DISA Vendor STIG Process Guide specifies that vendors submit a **spreadsheet** — not XCCDF XML. DISA converts the spreadsheet to XCCDF internally during finalization.

Vulcan offers two Excel export modes:
- **DISA Excel** — DoD-specific format with status-based content modification
- **Standard Excel** — Unmodified content for all rules

### XCCDF XML (Value-Add)

XCCDF export is NOT a DISA vendor submission requirement. It is a Vulcan value-add for downstream consumers (STIG Viewer, automated scanning tools). The public STIG published by DISA on Cyber Exchange is in XCCDF format.

### InSpec (Value-Add)

InSpec export generates Chef InSpec profiles for automated compliance testing. This is not part of the DISA process.

### CSV (Value-Add)

CSV export provides spreadsheet data with selectable columns. Not part of the DISA process.

## Publication Model

DISA publishes STIGs in two tiers:

| Tier | Content | Distribution | Classification |
|------|---------|-------------|----------------|
| **Public STIG** | AC rules only | Cyber Exchange (public) | Unclassified |
| **Confidential Package** | NA, AIM, ADNM rules + compliance report | Authorizing Officials upon request | CUI |

This means:
- **XCCDF exports** should contain only AC rules (excluding satisfied_by) — matches public STIG
- **DISA Excel exports** should contain ALL rules regardless of status — matches vendor submission
- A future "Confidential/CUI" export could include non-AC rules in XCCDF format

## Current Filtering Matrix

| Format | Status Filter | Satisfaction Filter | Content Modification |
|--------|:---:|:---:|:---:|
| XCCDF | AC only | Skip satisfied_by | None |
| InSpec | AC only | Skip satisfied_by | None |
| DISA Excel | All statuses | None | Replaces check/fix per status |
| Standard Excel | All statuses | None | None |
| CSV (component) | All statuses | None | None |
| CSV (STIG/SRG) | All statuses | None | None |

## Known Gaps

### Gap 1: Extra Columns in DISA Export

DISA's template has exactly 17 columns (Section 8, Table 8-1). Vulcan's DISA Excel export adds two extra columns:
- Column 18: "Vendor Comments"
- Column 19: "Satisfies"

**Impact:** DISA may reject spreadsheets with extra columns.

**Fix:** Offer a "strict DISA template" mode with exactly 17 columns. Move Satisfies data into VulnDiscussion (as already done for XCCDF). Vendor Comments could be a separate document or omitted from strict mode.

### Gap 2: Check/Fix Boilerplate for Non-AC Statuses

The Process Guide says Check and Fix should be **blank** for non-AC statuses in vendor submissions (Sections 4.1.11, 4.1.13). Vulcan fills them with boilerplate text that matches what DISA adds during finalization.

**Impact:** Vendor submission doesn't match DISA's expected format.

**Fix:** Two export modes:
- "Vendor Submission" — Check/Fix blank for non-AC (per guide)
- "Published STIG Format" — with DISA boilerplate (current behavior)

### Gap 3: NYD Rules in DISA Export

"Not Yet Determined" is NOT a DISA-recognized status. NYD rules are included in exports with no warning.

**Impact:** DISA will reject submissions with NYD rules.

**Fix:** Either exclude NYD rules from DISA exports, or warn the user that the export is not submission-ready if NYD rules exist.

### Gap 4: Severity and VulnDiscussion for NA

The Process Guide says NA requirements do not require a VulnDiscussion (Section 4.1.8) or a Severity (Section 4.1.14). Vulcan does not clear these fields for NA rules in DISA exports.

**Fix:** Blank severity and VulnDiscussion for NA rules in DISA export.

### Gap 5: STIGID Field

The STIGID is populated by DISA during finalization (Section 4.1.4). Vulcan populates it with `prefix-rule_id`. Vendor submissions should leave STIGID blank.

**Fix:** In "Vendor Submission" mode, leave STIGID blank. In "Published STIG Format" mode, populate as currently done.

### Gap 6: CSV Not Available at Project Level

The project export controller does not include `:csv` in its format allowlist. Users see the CSV option but get "Unsupported export type: csv".

**Fix:** Add `:csv` to the project controller's format allowlist and implement project-level CSV export.

### Gap 7: ProjectComponents Export Routing

ProjectComponents page sends `/components/export/${type}?component_ids=...` but the route expects `/components/:id/export/:type`. Rails interprets "export" as the `:id` parameter, causing "Control not found".

**Fix:** Route through the project export endpoint instead: `/projects/${projectId}/export/${type}?component_ids=...`

### Gap 8: Excel/CSV Don't Filter Satisfied-By Rules

XCCDF and InSpec exports skip `satisfied_by` rules. Excel and CSV exports include all rules, which means a component with 264 SRG requirements but only 25 active rules will export 264 rows.

**Fix:** Add optional satisfaction filter. User chooses between "All rules" and "Active rules only" (excludes satisfied_by). Default to "All rules" for DISA Excel (DISA wants complete picture), allow filtering for other formats.

## Current Backend Architecture

### Routes

```
GET /components/:id/export/:type    -> components#export   (csv, inspec, xccdf)
GET /stigs/:id/export/:type         -> stigs#export        (xccdf, csv)
GET /srgs/:id/export/:type          -> srgs#export         (xccdf, csv)
GET /projects/:id/export/:type      -> projects#export     (disa_excel, excel, xccdf, inspec)
```

### Key Backend Files

| File | Purpose |
|------|---------|
| `app/helpers/export_helper.rb` | Core export logic: export_excel, XCCDF/InSpec helpers |
| `app/models/rule.rb` | csv_attributes (19 fields), satisfaction_text |
| `app/models/component.rb` | csv_export method |
| `app/models/concerns/benchmark_csv_export.rb` | Shared STIG/SRG CSV export |
| `app/constants/export_constants.rb` | DISA_EXPORT_HEADERS, BENCHMARK_CSV_COLUMNS |
| `app/constants/import_constants.rb` | IMPORT_MAPPING with satisfies column |

### Key Frontend Files

| File | Purpose |
|------|---------|
| `app/javascript/components/shared/ExportModal.vue` | DRY modal (shared by 5 pages) |
| `app/javascript/components/project/Project.vue` | Project export handler |
| `app/javascript/components/components/ProjectComponents.vue` | Released components export (BROKEN) |
| `app/javascript/components/shared/BenchmarkViewer.vue` | STIG/SRG/Component viewer export |
| `app/javascript/constants/csvColumns.js` | STIG/SRG CSV column definitions |

### Frontend Consumer Matrix

| Consumer | Formats Shown | URL Pattern | Status |
|----------|--------------|-------------|--------|
| Project.vue | All (no prop) | `/projects/{id}/export/{type}` | Partial (no csv) |
| ProjectComponents.vue | All (no prop) | `/components/export/{type}` | **BROKEN** |
| BenchmarkViewer (component) | xccdf, csv | `/components/{id}/export/{type}` | Working |
| BenchmarkViewer (stig) | xccdf, csv | `/stigs/{id}/export/{type}` | Working |
| BenchmarkViewer (srg) | xccdf, csv | `/srgs/{id}/export/{type}` | Working |

## Planned Export Modes

Based on DISA Process Guide analysis, Vulcan should support these export modes:

### Vendor Submission Mode
- **Format:** Excel (17 columns, strict DISA template)
- **Content:** All rules, all statuses
- **Check/Fix:** Blank for non-AC
- **VulnDiscussion:** Blank for NA
- **Severity:** Blank for NA
- **STIGID:** Blank (DISA fills)
- **Satisfies:** In VulnDiscussion text, not separate column

### Published STIG Mode (XCCDF)
- **Format:** XCCDF XML
- **Content:** AC rules only, satisfied_by excluded
- **Check/Fix:** Required for all included rules
- **Satisfies:** In VulnDiscussion text

### Confidential/CUI Mode (Future)
- **Format:** XCCDF or Excel
- **Content:** NA, AIM, ADNM rules
- **Use case:** Authorizing Official risk assessment

### Working Export
- **Format:** Excel, CSV
- **Content:** Configurable (all rules or active only)
- **Check/Fix:** As authored
- **Use case:** Internal review, InSpec development, team collaboration
