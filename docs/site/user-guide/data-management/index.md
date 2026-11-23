# Data Management

Vulcan has two distinct systems for moving data in and out. They serve different purposes and understanding the difference helps you pick the right tool for the job.

## Two Systems, Two Goals

### Import & Export — Format Conversion

**Question you're answering:** "I need my data in a different format."

Import/Export converts your Vulcan data to and from external formats that other tools understand. Each format serves a specific audience:

| Format | Who It's For | What It Does |
|--------|-------------|--------------|
| **XCCDF** | DISA, SCAP scanners, STIG Viewer | Standard DISA XML — the format STIGs are published in |
| **Excel** | DISA reviewers, team leads | Spreadsheet for submission or offline review |
| **CSV** | Data analysts, scripting | Flat file for bulk processing |
| **InSpec** | DevSecOps engineers | Automated compliance scanning profiles |

Every export format is **lossy** by design. A STIG's XCCDF only includes "Applicable - Configurable" rules (an SRG's includes only "Applicable" ones). DISA Excel blanks out fields that DISA fills in during finalization. CSV flattens hierarchical data. Each format gives the consumer exactly what they need — nothing more.

**Use Import/Export when you need to:**
- Submit to DISA for STIG publication
- Share with tools that consume XCCDF or InSpec
- Review data in a spreadsheet
- Load SRGs and STIGs from DISA XML files
- Create a component from a spreadsheet

→ [Import & Export Reference](./import-export)

### Backup & Restore — Full-Fidelity Preservation

**Question you're answering:** "I need to save, move, or clone my project."

Backup/Restore creates a complete snapshot of a project — every field, every status, every relationship — in a ZIP archive. Nothing is filtered, converted, or lost.

| What's Preserved | Details |
|-----------------|---------|
| All rule statuses | Including "Not Yet Determined" and "Not Applicable" |
| All rule fields | InSpec code, vendor comments, descriptions, everything |
| Satisfaction relationships | Which rules satisfy which other rules |
| Reviews | Full review history with comments and timestamps |
| Memberships | User roles (matched by email on restore) |

**Use Backup/Restore when you need to:**
- Move a project to another Vulcan instance
- Create a copy of a project to start a new version
- Recover from data loss
- Share a complete project with another team
- Import specific components from one project into another

→ [Backup & Restore Reference](./backup-restore)

## Decision Guide

| I want to... | Use |
|--------------|-----|
| Submit my component to DISA | Download → DISA Vendor Submission |
| Share progress with my team in a spreadsheet | Download → Working Copy (Excel/CSV) |
| Generate an InSpec profile for scanning | Download → STIG-Ready Publish Draft (InSpec) |
| Move my project to a new server | Backup → Restore on new instance |
| Clone a project to start v2 | Backup → Create New Project from Backup |
| Recover a deleted component | Backup → Restore into existing project |
| Load a new SRG from DISA | Import → SRG XML upload |
| Create a component from someone's spreadsheet | Import → Spreadsheet import |
| Send my project to a colleague running Vulcan | Backup → Send ZIP, they restore |

## Project Export Modes

When exporting from a Project, Vulcan asks you to pick a **purpose** first, then a format. This ensures the right rules and fields are included for your audience:

```
Purpose                    → Format        → What's Included
─────────────────────────────────────────────────────────────
Working Copy               → CSV, Excel,   → All rules, all fields, as-authored
                             InSpec
DISA Vendor Submission     → Excel         → Non-NYD rules, DISA 17-column strict
STIG-Ready Publish Draft   → XCCDF, InSpec → AC rules only, no satisfied-by
Backup                     → JSON Archive  → Everything — full fidelity
```

A single component offers the same four purposes. Published STIGs and SRGs
are the ones with the simpler format-only picker (XCCDF or CSV): there is
no purpose to choose for a document that is already published.

## Database vs Application Backup

Vulcan's backup system operates at the **application level** — it exports project data as structured JSON. This is different from a **database backup** (`pg_dump`), which copies the entire PostgreSQL database.

| | Application Backup (JSON Archive) | Database Backup (pg_dump) |
|---|---|---|
| **Scope** | One project at a time | Entire database |
| **Portability** | Works across Vulcan instances | Same PostgreSQL version required |
| **Selectivity** | Choose which components | All or nothing |
| **User-accessible** | Yes, from the UI — any project member with read access | Admin/ops only |
| **Cross-version** | Tolerant of schema changes | Exact schema match needed |
| **Use case** | Project migration, sharing, cloning | Disaster recovery, server migration |

For server-level disaster recovery, use `pg_dump` (see the [Docker](/deployment/docker), bare-metal and Kubernetes deployment guides). For project-level work, use the in-app backup.
