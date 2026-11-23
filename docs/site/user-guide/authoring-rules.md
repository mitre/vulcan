# Authoring Rules — Quick Reference

This page provides a local reference for common authoring tasks. For in-depth training, see the [MITRE SAF Guidance Training](https://mitre.github.io/saf-training/courses/guidance/).

## Workflow Overview

```
Create Project → Add Component (select SRG) → Author Rules → Review → Lock → Export
```

### 1. Create a Project

Projects are containers for one or more Components. From the Projects page, click **New Project**.

- **Project Title**: Organization or system name (e.g., "RHEL 9 STIG")
- **Project Description**: required, not optional
- **Visibility**: `discoverable` or `hidden`. Discoverable means non-members can see the project and request access.

### 2. Add a Component

A Component is a document in progress — either a STIG implementing an SRG's requirements, or an SRG being authored from core SRGs. The New Component form asks **What are you authoring?** first, and the choice is permanent for the component. This page describes the STIG path.

1. Open your project
2. Click **New Component** → **Create New Component**
3. Choose **STIG**, then select one or more base SRGs (e.g., "General Purpose Operating System V3R3")
4. Set the **STIG ID Prefix** (4 characters + hyphen + 2, e.g., `RHEL-09`). Every rule's STIG ID is generated from it.

The SRGs' requirements become your rule set.

::: tip Authoring an SRG instead?
Choosing **SRG** bases the component on core SRGs and switches the authoring lifecycle to three statuses — Not Yet Determined, Applicable, Not Applicable. See the [SRG Authoring Workflow](../disa-process/srg-authoring).
:::

### 3. Author Rules

Each rule maps to an SRG requirement. Click a rule in the left navigator to edit it.

#### Rule Statuses

| Status | Meaning | Required Fields |
|--------|---------|----------------|
| Not Yet Determined | Default — not started | None (placeholder) |
| Applicable - Configurable | System can be configured to comply | Title, Fix, Check, Vuln Discussion |
| Applicable - Inherently Meets | System complies out of the box | Status Justification, Artifact Description |
| Applicable - Does Not Meet | No way to achieve compliance | Status Justification, Mitigations |
| Not Applicable | Requirement doesn't apply | Status Justification |

#### Key Fields

- **Title**: One-sentence vulnerability description
- **Fix Text**: How to remediate the vulnerability
- **Check Content**: How to verify the fix was applied
- **Vulnerability Discussion**: Detailed rationale for this control
- **Severity**: CAT I (High), CAT II (Medium), CAT III (Low)
- **Vendor Comments**: Notes for reviewers (not published in final STIG)

### 4. Satisfactions

When one rule's fix also satisfies another requirement:

1. Open the satisfying rule
2. Click **Satisfies** in the toolbar to open the **Also Satisfies** picker
3. Search for and select the satisfied rule(s)

At export, a satisfied rule's Check and Fix are filled from the rule that satisfies it, so the two never disagree in the deliverable. The exception is **Applicable - Does Not Meet**: those rows export with Check and Fix blank regardless.

### 5. Review and Lock

#### Per-Rule Review
1. Click **Change Review Status** in the toolbar and pick **Request Review** in the **Complete a Review** modal
2. A reviewer examines the rule and **Approve**s it or uses **Request Changes**
3. Approved rules become locked (all fields read-only)

#### Per-Section Lock
Reviewers and admins can lock individual sections (e.g., Status, Severity) while leaving other sections editable. Look for the lock/unlock icons next to section labels.

#### Bulk Lock
From the component card, click **Lock** to lock all rules at once. Choose between:
- **Lock all rule fields** — every field locked
- **Lock selection of fields** — pick the sections to lock

### 6. Export

From the component editor or project page, click **Export** and choose:

| Mode | Purpose |
|------|---------|
| Working Copy | Internal review, sharing drafts |
| DISA Vendor Submission | Submit to DISA for review |
| STIG-Ready Publish Draft | Final publication-ready format |
| Backup | Full-fidelity JSON archive |

Available formats depend on the mode: XCCDF, InSpec, CSV, Excel, JSON Archive.

## Visual Field States

A **yellow left border** on a field group means that section is locked by
a reviewer; the rest of the form stays editable, and a legend above the
form explains the marking.

The other two lock states apply to the whole rule, so they show as a
badge above the form rather than per field: a blue **Under Review**
badge, or a grey **Rule Locked** badge, with the form disabled in both
cases. When section locks are set, the badge instead names them
("Status locked", or "3 sections locked").

## Tips

- The **Advanced Fields** toggle exposes metadata fields (rule weight, ident system, etc.). Turning it on is a component-admin action, and it asks you to confirm.
- The **Test Script** tab is where you write the InSpec control body; the **Generated Control (Read-Only)** tab beside it shows the full control Vulcan assembles from it. Both are STIG-only — SRG requirements carry no InSpec.
- **Related** shows how other components implemented the same SRG requirement
- The **Rule Changelog** panel tracks all changes, with revert from any entry
- **Clone** duplicates a rule within the same component (STIG components only)
