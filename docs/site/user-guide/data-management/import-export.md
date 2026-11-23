# Import & Export

Vulcan supports importing and exporting security guidance in multiple formats. This page covers all import and export functionality.

### Format Summary

| Format | Import | Export |
|--------|--------|--------|
| **XCCDF XML** | SRGs, STIGs | Components, Projects, STIGs, SRGs |
| **XLSX / CSV** | Components (spreadsheet import) | Components and Projects (both); STIGs and SRGs (CSV) |
| **InSpec** | — | Components, Projects |
| **JSON Archive** | Backup restore (Projects) | Backup (Projects) |

::: tip Backup & Restore
For full-fidelity project backup, restore, and migration, see [Backup & Restore](./backup-restore).
:::

## Import

### SRG / STIG XML Upload

Upload DISA XCCDF XML files to create SRG or STIG records in Vulcan.

1. Navigate to **SRGs** or **STIGs** in the top navigation
2. Click **Upload SRG** / **Upload STIG** — the button only appears for Vulcan admins
3. Select an XCCDF XML file (`.xml`)
4. Vulcan parses the XML and creates the record with all rules

::: tip
SRGs and STIGs can also be synced automatically from DISA's published library using:
```bash
bundle exec rails stig_and_srg_puller:pull
```
:::

### Component from SRG

When you create a new Component and select its base SRGs, Vulcan automatically clones every requirement from every selected source into the new component. Each rule gets a sequential rule ID (000001, 000002, ...) prefixed with the component's prefix.

This works the same for both document kinds: a STIG component imports from derived SRGs in the catalog, and an SRG component imports from core SRGs (see the [SRG Authoring Workflow](../../disa-process/srg-authoring)). A released SRG component joins the SRG catalog just like an uploaded one, ready to serve as a STIG base.

### Component from Spreadsheet

Components can be imported from spreadsheets (`.xlsx` or `.csv`):

1. Navigate to a Project
2. Click **New Component** and select the spreadsheet import option
3. Select the base SRG and upload the spreadsheet

**Required columns:** SRG ID, STIG ID, Severity, Title, Vuln Discussion, Status, Check Content, Fix Text, Status Justification, Artifact Description

**Optional columns:** Vendor Comments, Mitigation, InSpec Control Body, CCI (Ident), Satisfies

The spreadsheet importer maps column headers to fields, validates SRG IDs against the selected SRG, and converts severity values (`CAT I/II/III` to `high/medium/low`).

### Update from Spreadsheet (Round-Trip Editing)

Existing components can be bulk-edited via spreadsheet round-trip:

1. **Export** the component as CSV or Excel (Working Copy mode)
2. **Edit** rules in Excel or Google Sheets
3. **Re-import** the edited spreadsheet to update the component

**How to use:**

1. Navigate to the Component page
2. Open the three-dots overflow menu in the command bar and click **Update from Spreadsheet**
3. Upload the edited `.xlsx` or `.csv` file
4. Review the **word-diff preview** showing exactly what changed per rule
5. Click **Apply Changes** to save, or **Cancel** to discard

**Behavior:**

- Rules are matched by STIG ID first (the numeric tail of the `STIG ID` column, which is unique per rule), falling back to SRG ID — which can be shared by several rules
- Only **editable fields** are updated — section-locked fields are skipped
- A word-level diff is shown for each changed field before applying
- Satisfaction relationships are re-parsed from `vendor_comments` after update
- Rules not found in the spreadsheet are left unchanged (no deletions)

::: warning Section Locks
If a rule has locked sections (e.g., check content locked by a reviewer), those fields will be skipped during import even if the spreadsheet contains different values. The preview collects them under **Protected Rules (Skipped)**, annotated `— locked` or `— section locked: <sections>`.
:::

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

Marking a rule satisfied-by another **in the UI** applies DISA's nesting
convention: Vulcan sets the satisfied rule to **Applicable - Does Not
Meet** and generates a Status Justification and Mitigation naming the
covering rule. Because the rule is then Does Not Meet, its Check and Fix
export blank — the covering rule carries the procedure.

Relationships discovered by *parsing* `vendor_comments` on import do not
change any rule's status; they only record the relationship.

---

## Export

### Export Formats

| Format | Available For | Description |
|--------|--------------|-------------|
| **XCCDF** | Components, Projects, STIGs, SRGs | DISA SCAP XML format |
| **CSV** | Components, STIGs, SRGs | Spreadsheet with selectable columns |
| **InSpec** | Components, Projects | Chef InSpec profile (ZIP) |
| **Excel** | Components, Projects | Standard `.xlsx` spreadsheet |
| **JSON Archive** | Projects | Full-fidelity backup (ZIP) |

### Exporting a STIG or SRG

1. Navigate to the STIG or SRG detail page
2. Click the **Download** button
3. Select the format:
   - **XCCDF-Benchmark** — full XCCDF XML
   - **CSV** — spreadsheet with column picker

For CSV exports, you can select which columns to include. The twelve default columns are Rule ID, STIG ID, SRG ID, Vuln ID, Severity, Title, Description, Check, Fix, CCI, 800-53 Controls and Legacy IDs.

::: info SRG vs STIG column differences
SRG CSV exports label the `version` column as **SRG ID** (instead of STIG ID) and drop the two STIG-specific columns, `Vuln ID` and `SRG ID`, which have no meaning in the SRG context.
:::

### Exporting a Component

1. Navigate to the Component page
2. Open the three-dots overflow menu and click **Download**
3. Pick a **Purpose** — a component offers the same four purposes a project does — then a format. Across all four that means XCCDF, CSV, Excel, InSpec and JSON Archive.

### Exporting a Project

Projects use a **purpose-first** export workflow with four modes:

1. Navigate to the Project page
2. Click the **Download** button
3. Select the **Purpose** (mode):

| Purpose | Formats | Description |
|---------|---------|-------------|
| **Working Copy** | CSV, Excel, InSpec | Internal review and editing |
| **DISA Vendor Submission** | Excel | 17-column strict DISA template |
| **STIG-Ready Publish Draft** | XCCDF, InSpec | Draft content for DISA review |
| **Backup** | JSON Archive | Full-fidelity archive (see [Backup & Restore](./backup-restore)) |

4. Select which components to include (or select all)
5. Click **Export**

::: warning NYD Components
When exporting in DISA modes, components with only "Not Yet Determined" rules show a warning icon — these will produce empty output since NYD is not a DISA-accepted status.
:::

### Satisfaction Export

Satisfaction relationships are regenerated into the `vendor_comments`
field on export. Stale text is stripped first, then one line per
direction the rule actually has:

```
Satisfied By: PREFIX-RULEID, PREFIX-RULEID
```

```
Satisfies: PREFIX-RULEID, PREFIX-RULEID
```

A rule with both gets both, joined by `. `. The format is designed to be
re-importable — the same text is parsed back on import.

### XCCDF Export Details

XCCDF exports produce valid DISA XCCDF-Benchmark XML with:
- Standard XCCDF namespaces (dc, xsi, cpe, xhtml, dsig)
- Benchmark metadata (status, title, description, version)
- Group/Rule structure for each rule
- Structured descriptions (VulnDiscussion, FalsePositives, FalseNegatives, Mitigations, etc.)
- A `check` element carrying the check content. A STIG's check has no
  content reference (`system="N/A"`); a published SRG's points at the SRG
  document itself.
- A CCI `ident` element. 800-53 control mapping is a CSV column only — it
  is not emitted in XCCDF.

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

| Column | Header | Default | Example |
|--------|--------|:-------:|---------|
| `rule_id` | Rule ID | ✅ | `SV-203591r557031_rule` |
| `version` | STIG ID | ✅ | `RHEL-09-000001` |
| `srg_id` | SRG ID | ✅ | `SRG-OS-000001-GPOS-00001` |
| `vuln_id` | Vuln ID | ✅ | `V-203591` |
| `rule_severity` | Severity | ✅ | `medium` |
| `title` | Title | ✅ | `The operating system must…` |
| `vuln_discussion` | Description | ✅ | `Without verification of the…` |
| `check_content` | Check | ✅ | `Verify the operating system…` |
| `fixtext` | Fix | ✅ | `Configure the operating sys…` |
| `ident` | CCI | ✅ | `CCI-000366` |
| `nist_control_family` | 800-53 Controls | ✅ | `CM-6 b` |
| `legacy_ids` | Legacy IDs | ✅ | `V-56571, SV-70831` |
| `status` | Status | | `Applicable - Configurable` |
| `rule_weight` | Weight | | `10.0` |
| `mitigations` | Mitigations | | |
| `severity_override_guidance` | Severity Override | | |
| `false_positives` | False Positives | | |
| `false_negatives` | False Negatives | | |

### SRG Columns (16 available)

SRG exports use the same columns but exclude `vuln_id` and `srg_id` (which are STIG-specific), and relabel the `version` header as **SRG ID**.
