# Export Requirements

How Vulcan's exports map to what DISA actually requires from a vendor STIG submission.

## What DISA Requires

The DISA Vendor STIG Process Guide specifies that vendors submit a **spreadsheet** — not
XCCDF XML. DISA converts the spreadsheet to XCCDF internally during finalization. The
per-field rules for that spreadsheet (which fields are required, blank, or conditional for
each status) are catalogued in [Field Requirements](./field-requirements).

## Publication Model

DISA publishes STIGs in two tiers:

| Tier | Content | Distribution | Classification |
|------|---------|-------------|----------------|
| **Public STIG** | AC rules only | Cyber Exchange (public) | Unclassified |
| **Confidential Package** | NA, AIM, ADNM rules + compliance report | Authorizing Officials upon request | CUI |

## SRG Publication Model

SRG components (see the [SRG Authoring Workflow](./srg-authoring)) publish differently from STIGs:

- **The published document is XCCDF, not a spreadsheet** — there is no spreadsheet intermediary and no two-tier public/CUI split. The SRG XCCDF is the single published artifact.
- **Only Applicable requirements publish.** Not Applicable requirements and their justifications stay on the component as the working record; Not Yet Determined requirements block release entirely.
- **Releasing an SRG component** generates its XCCDF and stores it in Vulcan's SRG catalog, where it becomes a base for STIG components. An SRG component's XCCDF export produces the same published-SRG shape.

## How Vulcan's Export Purposes Map to the Process

Project exports are **purpose-first**: you pick why you are exporting, and the mode
applies the matching rules. The how-to lives in
[Import & Export](../user-guide/data-management/import-export#exporting-a-project); this
table maps each purpose to its place in the DISA process:

| Purpose | DISA role | What the mode enforces |
|---------|-----------|------------------------|
| **DISA Vendor Submission** | The vendor deliverable | Exactly the 17 DISA template columns; STIGID blank (DISA fills it during finalization); Check/Fix blank for non-AC statuses; VulnDiscussion and Severity blank for NA; NYD rules excluded (not a DISA-recognized status) |
| **STIG-Ready Publish Draft** | Matches the public STIG tier | AC rules only, rules satisfied by other rules excluded — the shape DISA publishes on Cyber Exchange (XCCDF, InSpec) |
| **Working Copy** | Not a DISA artifact | Everything as authored, for internal review and round-trip editing (CSV, Excel) |
| **Backup** | Not a DISA artifact | Full-fidelity archive for restore and migration (JSON) |

::: tip Submission readiness
Components containing only "Not Yet Determined" rules show a warning in DISA modes —
they produce empty output, because NYD is not a status DISA accepts.
:::

## Reference

- [Field Requirements](./field-requirements) — the per-status field matrix the Vendor
  Submission mode enforces
- [Vendor STIG Process Guide](./vendor-stig-process-guide) — the process the deliverable
  feeds into
- [Import & Export](../user-guide/data-management/import-export) — step-by-step export
  instructions for every format
