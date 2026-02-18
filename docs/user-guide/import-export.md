# Import & Export

Vulcan supports importing and exporting security guidance in multiple formats. This page covers all import and export functionality.

### Format Summary

| Format | Import | Export |
|--------|--------|--------|
| **XCCDF XML** | SRGs, STIGs | Components, Projects, STIGs, SRGs |
| **XLSX / CSV** | Components (spreadsheet import) | Components, STIGs, SRGs (CSV); Projects (XLSX) |
| **InSpec** | — | Components, Projects |
| **JSON Archive** | Backup restore (Projects) | Backup (Projects) |

::: tip Backup & Restore
For full-fidelity project backup, restore, and migration, see [Backup & Restore](./backup-restore).
:::

## Import

### SRG / STIG XML Upload

Upload DISA XCCDF XML files to create SRG or STIG records in Vulcan.

1. Navigate to **SRGs** or **STIGs** in the top navigation
2. Click the **Upload** button
3. Select an XCCDF XML file (`.xml`)
4. Vulcan parses the XML and creates the record with all rules

::: tip
SRGs and STIGs can also be synced automatically from DISA's published library using:
```bash
bundle exec rails stig_and_srg_puller:pull
```
:::

### Component from SRG

When you create a new Component and select a base SRG, Vulcan automatically clones every SRG requirement as a rule in the new component. Each rule gets a sequential rule ID (000001, 000002, ...) prefixed with the component's prefix.

### Component from Spreadsheet

Components can be imported from spreadsheets (`.xlsx` or `.csv`):

1. Navigate to a Project
2. Click **New Component** and select the spreadsheet import option
3. Select the base SRG and upload the spreadsheet

**Required columns:** SRG ID, STIG ID, Severity, Title, Vuln Discussion, Status, Check Content, Fix Text, Status Justification, Artifact Description

**Optional columns:** Vendor Comments, Mitigation, InSpec Control Body, CCI (Ident)

The spreadsheet importer maps column headers to fields, validates SRG IDs against the selected SRG, and converts severity values (`CAT I/II/III` to `high/medium/low`).

### Satisfaction Relationships

When a component is created or imported, Vulcan parses `vendor_comments` on each rule to detect satisfaction relationships between rules.

**Supported keywords:**
- `Satisfied By:` — this rule is satisfied by the listed rules
- `Satisfies:` — this rule satisfies the listed rules

**Parsing follows [Postel's Law](https://en.wikipedia.org/wiki/Robustness_principle)** — liberal in what it accepts:

| Input Variation | Accepted? |
|----------------|-----------|
| `Satisfied By: PHOS-03-000001, PHOS-03-000002.` | Yes (canonical) |
| `satisfied by: PHOS-03-000001, PHOS-03-000002` | Yes (lowercase, no period) |
| `SATISFIED BY: PHOS-03-000001; PHOS-03-000002.` | Yes (uppercase, semicolons) |
| `Satisfies: PHOS-03-000001` | Yes (reverse direction) |
| `Some other text. Satisfied By: PHOS-03-000001.` | Yes (text before keyword) |
| `Satisfied By: PHOS-03-000001   .` | Yes (extra whitespace) |

When a rule has `satisfied_by` relationships, Vulcan automatically:
- Sets its status to **Applicable - Configurable**
- Inherits fix text and check content from the satisfying rule

---

## Export

### Export Formats

| Format | Available For | Description |
|--------|--------------|-------------|
| **XCCDF** | Components, Projects, STIGs, SRGs | DISA SCAP XML format |
| **CSV** | Components, STIGs, SRGs | Spreadsheet with selectable columns |
| **InSpec** | Components, Projects | Chef InSpec profile (ZIP) |
| **Excel** | Projects | Standard `.xlsx` spreadsheet |
| **DISA Excel** | Projects | DoD/DISA-specific format |

### Exporting a STIG or SRG

1. Navigate to the STIG or SRG detail page
2. Click the **Export** button
3. Select the format:
   - **XCCDF-Benchmark** — full XCCDF XML
   - **CSV** — spreadsheet with column picker

For CSV exports, you can select which columns to include. Default columns cover the most common fields (Rule ID, STIG/SRG ID, Severity, Title, Discussion, Check, Fix, CCI, NIST, Legacy IDs).

::: info SRG vs STIG column differences
SRG CSV exports label the `version` column as **SRG ID** (instead of STIG ID) and exclude SRG-specific reference fields that are redundant in the SRG context.
:::

### Exporting a Component

1. Navigate to the Component page
2. Click the **Export** button
3. Select the format:
   - **XCCDF** — DISA SCAP XML
   - **CSV** — spreadsheet
   - **InSpec** — Chef InSpec profile (ZIP)

### Exporting a Project

Projects use a **purpose-first** export workflow with four modes:

1. Navigate to the Project page
2. Click the **Export** button
3. Select the **Purpose** (mode):

| Purpose | Formats | Description |
|---------|---------|-------------|
| **Working Copy** | CSV, Excel | Internal review and editing |
| **DISA Vendor Submission** | Excel | 17-column strict DISA template |
| **STIG-Ready Publish Draft** | XCCDF, InSpec | Draft content for DISA review |
| **Backup** | JSON Archive | Full-fidelity archive (see [Backup & Restore](./backup-restore)) |

4. Select which components to include (or select all)
5. Click **Export**

::: warning NYD Components
When exporting in DISA modes, components with only "Not Yet Determined" rules show a warning icon — these will produce empty output since NYD is not a DISA-accepted status.
:::

### Satisfaction Export

When a rule has `satisfied_by` relationships, the export includes the satisfaction information in the `vendor_comments` field using the canonical format:

```
Satisfied By: PREFIX-RULEID, PREFIX-RULEID.
```

This format is designed to be re-importable — the same text will be correctly parsed on import.

### XCCDF Export Details

XCCDF exports produce valid DISA XCCDF-Benchmark XML with:
- Standard XCCDF namespaces (dc, xsi, cpe, xhtml, dsig)
- Benchmark metadata (status, title, description, version)
- Group/Rule structure for each rule
- Structured descriptions (VulnDiscussion, FalsePositives, FalseNegatives, Mitigations, etc.)
- Check content with OVAL references
- CCI and NIST control mapping

::: tip
Only rules with status **Applicable - Configurable** (without `satisfied_by` relationships) are included in XCCDF and InSpec exports. Rules satisfied by other rules are excluded since their requirements are met elsewhere.
:::

### InSpec Export Details

InSpec exports create a ZIP archive containing:
- `inspec.yml` — profile metadata (name, title, maintainer, summary)
- `controls/` — one `.rb` file per applicable rule, named `PREFIX-RULEID.rb`

---

## CSV Column Reference

### STIG Columns (18 available)

| Column | Header | Example |
|--------|--------|---------|
| `rule_id` | Rule ID | `SV-203591r557031_rule` |
| `version` | STIG ID | `RHEL-09-000001` |
| `srg_id` | SRG ID | `SRG-OS-000001-GPOS-00001` |
| `vuln_id` | Vuln ID | `V-203591` |
| `rule_severity` | Severity | `medium` |
| `title` | Title | `The system must...` |
| `vuln_discussion` | Vuln Discussion | `Without authentication...` |
| `check_content` | Check Content | `Verify the system...` |
| `fixtext` | Fix Text | `Configure the system...` |
| `ident` | CCI | `CCI-000068` |
| `nist_control_family` | NIST Control Family | `AC-17 (2)` |
| `legacy_ids` | Legacy IDs | `V-56571, SV-70831` |
| `status` | Status | `Applicable - Configurable` |
| `rule_weight` | Rule Weight | `10.0` |
| `mitigations` | Mitigations | |
| `severity_override_guidance` | Severity Override Guidance | |
| `false_positives` | False Positives | |
| `false_negatives` | False Negatives | |

### SRG Columns (16 available)

SRG exports use the same columns but exclude `vuln_id` and `srg_id` (which are STIG-specific), and relabel the `version` header as **SRG ID**.
