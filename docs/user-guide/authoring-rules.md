# Authoring Rules — Quick Reference

This page provides a local reference for common authoring tasks. For in-depth training, see the [MITRE SAF Guidance Training](https://mitre.github.io/saf-training/courses/guidance/).

## Workflow Overview

```
Create Project → Add Component (select SRG) → Author Rules → Review → Lock → Export
```

### 1. Create a Project

Projects are containers for one or more Components. From the Projects page, click **New Project**.

- **Name**: Organization or system name (e.g., "RHEL 9 STIG")
- **Visibility**: Controls who can see the project in search results

### 2. Add a Component

A Component is a STIG-in-progress. Each Component is based on an SRG (Security Requirements Guide).

1. Open your project
2. Click **New Component**
3. Select the base SRG (e.g., "General Purpose Operating System V3R3")
4. Set a **prefix** (4 chars + hyphen + 2 chars, e.g., `RHEL-09`)

The SRG's requirements become your rule set.

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
2. Click **Satisfies** in the toolbar
3. Search for and select the satisfied rule(s)

Satisfied rules automatically inherit the satisfying rule's check and fix text.

### 5. Review and Lock

#### Per-Rule Review
1. Click **Request Review** in the toolbar
2. A reviewer examines the rule and approves or requests changes
3. Approved rules become locked (all fields read-only)

#### Per-Section Lock
Reviewers and admins can lock individual sections (e.g., Status, Severity) while leaving other sections editable. Look for the lock/unlock icons next to section labels.

#### Bulk Lock
From the component card, click **Lock** to lock all rules at once. Choose between:
- **Lock entire rules** — all fields locked
- **Lock sections only** — select which sections to lock

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

When editing rules, colored left borders indicate field state:

- **Yellow border** — section locked by a reviewer
- **Blue border** — rule is under review
- **Grey border** — entire rule is locked

A badge above the form shows the overall lock status. A legend explains active states.

## Tips

- Use **Advanced Fields** toggle for metadata fields (rule weight, ident system, etc.)
- The **InSpec Control Body** tab lets you add custom InSpec test code
- **Related Rules** shows how other components implemented the same SRG requirement
- **History** sidebar tracks all changes with revert capability
- **Clone** duplicates a rule within the same component
