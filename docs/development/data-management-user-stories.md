# Data Management User Stories

Complete set of user stories for Vulcan's data management system — exports,
imports, backup, restore, and DISA submission workflows. These define what
the finished system supports once all current work is complete.

## References

- `docs/disa-process/export-requirements.md` — Gap analysis and export architecture
- `docs/disa-process/field-requirements.md` — DISA field matrix by status
- `docs/disa-process/overview.md` — DISA vendor process overview
- `docs/disa-process/intent-form.md` — DISA Intent Form requirements

---

## Export Stories

### 1. Vendor Submission (DISA Excel)

**Card:** vulcan-clean-sy4

> As a vendor security engineer, I need to export my completed Component as a
> strict 17-column DISA spreadsheet so I can submit it to DISA for STIG
> publication.

**Acceptance criteria:**
- Exactly 17 columns per DISA Table 8-1
- Check/Fix blank for non-AC statuses (DISA adds boilerplate during finalization)
- VulnDiscussion and Severity blank for NA
- STIGID blank (DISA assigns during finalization)
- Satisfies text folded into VulnDiscussion (not a separate column)
- Warning if any rules are still NYD (DISA rejects NYD)

### 2. Working Copy (Excel / CSV)

**Cards:** vulcan-clean-271 (routing), vulcan-clean-yuu (filter toggle)

> As a team lead, I need to export my Component as-is so I can share progress
> with my team, do offline review, or import into another Vulcan instance.

**Acceptance criteria:**
- All fields exactly as authored — no blanking, no content modification
- All statuses included (including NYD)
- Optional toggle: include or exclude satisfied-by rules
- Available at Component level AND Project level
- CSV format works (not just Excel)
- ProjectComponents page export URL works correctly

### 3. Published STIG (XCCDF)

> As a compliance engineer, I need to export a finalized Component as XCCDF XML
> so downstream tools (STIG Viewer, SCAP scanners) can consume it.

**Acceptance criteria:**
- AC rules only (matches what DISA publishes on Cyber Exchange)
- Satisfied-by rules excluded
- Satisfies text in VulnDiscussion
- Valid XCCDF schema

### 4. InSpec Profile

> As a DevSecOps engineer, I need to export my Component as an InSpec profile
> so I can automate compliance scanning.

**Acceptance criteria:**
- AC rules only, satisfied-by excluded
- Maps rule fields to InSpec control structure (title, desc, impact, tags, check/fix)

### 5. Backup XCCDF (Full-Fidelity)

**Card:** vulcan-clean-bjy

> As a Vulcan administrator, I need to export a Component as full-fidelity
> XCCDF XML (all rules, all statuses, all metadata) and re-import it into the
> same or different Vulcan instance for backup, migration, or disaster recovery.

**Acceptance criteria:**
- ALL rules, ALL statuses, ALL metadata — nothing filtered
- Includes NYD, NA, AIM, ADNM
- Preserves satisfaction relationships, vendor comments, InSpec control body
- Re-import creates a new Component (or updates existing)
- Round-trip: export then import produces identical data
- Works across Vulcan instances

**Why XCCDF over CSV/Excel:**
- Well-defined NIST schema — less fragile than CSV column ordering
- Native data format for STIGs/SRGs — mature parsers already exist
- Preserves hierarchical structure that flat formats lose
- Schema-validatable — can verify export integrity before import

---

## Import Stories

### 6. Spreadsheet Import (Round-Trip)

> As a security engineer, I need to import a spreadsheet (XLSX or CSV) to
> create or update a Component, including re-importing data I previously
> exported.

**Acceptance criteria:**
- Accepts DISA headers AND benchmark CSV headers (Postel's Law — DONE via header aliases)
- CSV file format accepted in UI (DONE — vulcan-clean-8et)
- InSpec Control Body column imported if present
- Satisfaction keywords parsed from VulnDiscussion

### 7. SRG/STIG XCCDF Import

> As a security engineer, I need to import SRG and STIG XML files from DISA
> Cyber Exchange so I can use them as baselines for new Components.

**Status:** Working. This is the core import path and has been functional.

### 8. Backup XCCDF Import

**Card:** vulcan-clean-bjy (same as story 5)

> As a Vulcan administrator, I need to re-import a backup XCCDF to restore
> a Component from a previous export.

**Acceptance criteria:**
- Accepts backup XCCDF exported from story 5
- Creates new Component with all fields preserved
- Works across Vulcan instances (export from A, import to B)

### 9. InSpec Profile Import (Future)

**Card:** vulcan-clean-9du

> As a team inheriting an existing InSpec profile, I need to import it into
> Vulcan so I can manage it alongside our other STIGs.

**Acceptance criteria:**
- Parse InSpec control files from ZIP or directory
- Extract control ID, title, desc, impact, tags (check, fix, cci, nist)
- Map to Vulcan rule fields
- Requires a base SRG (same as spreadsheet import)

**Approach:** Use `inspec json` CLI to convert profile to JSON, then parse
structured JSON rather than writing a Ruby DSL parser.

---

## Infrastructure Stories

### 10. Database Backup and Restore

**Card:** vulcan-clean-tnf

> As a Vulcan administrator, I need to backup and restore the entire database
> so I can recover from failures, migrate between servers, or clone
> environments.

**Acceptance criteria:**
- Backup: pg_dump to compressed file with timestamp naming
- Restore: pg_restore from backup file with safety confirmations
- Access: Available via rake task and optionally via admin UI
- Safety: Restore requires confirmation, warns about data loss
- Scheduling: Document cron-based automated backup pattern
- Storage: Configurable backup directory
- Document backup strategy per deployment type (Docker, Heroku, bare metal)

---

## Execution Order

The export system has 8 known gaps. Implementation must follow this order:

### Phase A: Export Implementation (parallel, no deps between them)
1. **sy4** — Vendor Submission mode (strict DISA 17-column template)
2. **271** — Fix export routing (project CSV + ProjectComponents URL)
3. **yuu** — Satisfied-by filter toggle for Excel/CSV

### Phase B: Round-Trip Testing (blocked by ALL of Phase A)
4. **dzg** — Export/import round-trip fidelity tests

### Phase C: Documentation (blocked by Phase A)
5. **r4d** — Sync VitePress docs with finalized export system

### Independent (no blockers, can be done anytime)
6. **bjy** — XCCDF backup/restore
7. **tnf** — Database backup/restore
8. **9du** — InSpec import (P2, future session)

### Already Complete
- **8et** — File picker fix (CLOSED)
- **bru** — CSV header alignment (CLOSED)
