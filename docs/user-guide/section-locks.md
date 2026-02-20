# Per-Section Rule Locking

## Overview

Vulcan supports two levels of rule locking:

1. **Whole-rule lock** (via Review system) — locks the entire rule, preventing any edits. Requires admin permissions and a review comment.
2. **Per-section lock** — locks individual sections of a rule while leaving other sections editable. Available to admins and reviewers.

Per-section locks enable the "book boss" workflow: a reviewer can lock policy fields (status, severity) after verification while leaving technical content (check text, fix text, vulnerability discussion) open for SME editing.

## Lockable Sections

| Section | Fields Locked |
|---------|--------------|
| Title | Title |
| Severity | Severity, Severity Override Guidance |
| Status | Status, Status Justification |
| Fix | Fix Text, Fix ID, Fix Text Reference |
| Check | Check Content, System, Reference Name, Reference Link |
| Vulnerability Discussion | Vulnerability Discussion |
| DISA Metadata | All DISA metadata fields (documentable, mitigations, etc.) |
| Vendor Comments | Vendor Comments |
| Artifact Description | Artifact Description |
| XCCDF Metadata | Version, Rule Weight, Identity, Identity System |

## Using Section Locks

### Per-Rule Section Locking

When viewing a rule in the editor, admins and reviewers see lock/unlock icons next to each section label:

- **Unlocked** (grey unlock icon) — section is editable. Click to lock.
- **Locked** (yellow lock icon) — section is read-only. Click to unlock.

Lock icons are only visible when:
- You have admin or reviewer permissions
- The rule is not whole-rule locked
- The rule is not under review

### Bulk Section Locking

From the component card, click the **Lock** button. The modal now offers two modes:

1. **Lock entire rules** — existing behavior, locks all fields on all unlocked rules
2. **Lock sections only** — select which sections to lock across all unlocked rules

This lets you lock policy fields (e.g., Status + Severity) across an entire component while keeping technical sections editable.

## Interaction with Whole-Rule Lock

- When a rule is **whole-rule locked**, all fields are disabled regardless of section lock state. Section lock icons are hidden.
- When a rule is **unlocked** from whole-rule lock, any previously set section locks resume.
- Section locks are independent of the review workflow.

## Audit Trail

Section lock changes appear in the rule's history sidebar with:
- Which sections were locked/unlocked
- Who made the change
- Optional comment explaining the reason

## Permissions

| Action | Admin | Reviewer | Author | Viewer |
|--------|-------|----------|--------|--------|
| Lock/unlock sections | Yes | Yes | No | No |
| View locked section indicators | Yes | Yes | Yes | Yes |
| Edit locked section fields | No | No | No | No |

## Cloning Rules

When a rule is cloned (duplicated), section locks are **not** carried over. The cloned rule starts with no section locks.

## Backup & Restore

Section lock state is preserved in JSON archive backups and restored on import. XCCDF exports do not include section lock state (it's a Vulcan-specific editing feature, not part of STIG content).

## Future Considerations

CSV/XLSX import/export does not currently include section lock state. This is by design — section locks are workflow metadata, not STIG content. If user feedback indicates this would be useful (e.g., setting locks via spreadsheet), it can be added in a future release.
