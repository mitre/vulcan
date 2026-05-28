# Vulcan Import/Export Workflows - User Stories

**Created:** 2025-11-26
**Purpose:** Document real-world user workflows for import/export functionality

---

## Core User Workflows

### Workflow 1: Create New Component from Scratch

**User Story:** "As a STIG author, I want to create a new component based on an SRG template so I can start authoring security controls."

**Steps:**
1. Click "Create a New Component"
2. Select SRG (e.g., "Operating System Core SRG")
3. Set name, prefix, version
4. Component created with 263 template requirements
5. User authors controls in Vulcan UI

**Current Status:** ✅ Works perfectly

---

### Workflow 2: Import Existing STIG/Component (XCCDF)

**User Story:** "As a STIG author, I exported my work from another Vulcan instance as XCCDF. I want to import it into this instance."

**Steps:**
1. Click "Import Component from File"
2. Select SRG (must match the original SRG)
3. Upload XCCDF XML file
4. System should:
   - Import all SRG requirements (263 template rules)
   - Overlay authored content from XCCDF (13 authored controls)
   - Parse "Satisfies:" relationships
   - Set admin name/email
   - Result: 13 primary + 250 inherited

**Current Status:** ✅ Works (just fixed)
**Issue:** User must manually select SRG (should auto-detect)

---

### Workflow 3: Import Existing Spreadsheet

**User Story:** "As a STIG author, I have a filled-out SRG spreadsheet. I want to import it into Vulcan."

**Steps:**
1. Click "Import Component from File"
2. Select SRG
3. Upload XLSX/CSV file
4. System should:
   - Parse spreadsheet headers (format-agnostic)
   - Import requirements
   - Parse "Satisfied By:" from vendor_comments
   - Create satisfaction relationships
   - Extract prefix from STIG ID column

**Current Status:** ✅ Works
**Formats:** .xlsx, .xls, .csv, .ods

---

### Workflow 4: Export → Edit → Re-import (UPDATE existing component)

**User Story:** "I exported my component to Excel, made edits offline, and now want to RE-IMPORT to UPDATE the existing component."

**THIS IS THE KEY WORKFLOW WE'RE MISSING!**

**What user wants:**
1. Export component to XLSX/XCCDF
2. Edit in Excel/external tool
3. Re-import to UPDATE same component (not create new)
4. Preserve:
   - Component ID
   - History/audits
   - Review status
   - Locked controls
   - Member assignments
5. Update:
   - Control content (titles, vuln_discussion, fix text, etc.)
   - Satisfaction relationships
   - Statuses

**Current Status:** ❌ NOT SUPPORTED
**Problem:** Import always creates NEW component, doesn't update existing

**Needed:**
- "Update Component from File" button
- Detects component by prefix or lets user select
- Updates existing rules instead of creating new
- Preserves metadata and history

---

### Workflow 5: Export for Collaboration

**User Story:** "I want to export my component so a colleague can work on it offline, then I'll import their changes back."

**Scenarios:**

**A) Simple handoff (one person at a time):**
1. Person A exports XCCDF
2. Person B imports, edits, exports
3. Person A re-imports updates
4. Need: Merge/conflict detection?

**B) Parallel work (multiple people):**
1. Person A and B both export
2. Both edit different controls
3. Both try to import
4. Need: Merge capability or "last write wins" warning

**Current Status:** ❌ Partial
**Works:** Export and import
**Missing:** Update existing, conflict detection, merge

---

### Workflow 6: Backup and Restore

**User Story:** "I want to backup my entire project (all components, members, history) and restore it later or on another instance."

**What to backup:**
- Project metadata (name, description, visibility)
- All components
- All authored controls
- Satisfaction relationships
- Member assignments and roles
- Review history
- Audit history
- Slack channel mappings

**Format Options:**
- **Option A:** Single ZIP with multiple XCCDF files + metadata JSON
- **Option B:** PostgreSQL dump (database-level)
- **Option C:** Custom JSON format with everything

**Current Status:** ❌ NOT SUPPORTED

---

## Current Import/Export Matrix

| Format | Import New | Export | Update Existing | Preserves Satisfactions | Notes |
|--------|-----------|--------|-----------------|------------------------|-------|
| **XLSX** | ✅ | ✅ | ❌ | ✅ (via vendor_comments) | Header-based, format-agnostic |
| **CSV** | ✅ | ✅ | ❌ | ✅ (via vendor_comments) | Same as XLSX |
| **XCCDF** | ✅ | ✅ | ❌ | ✅ (via Satisfies:) | Just fixed today |
| **DISA XLSX** | ✅ | ✅ | ❌ | ✅ (filtered export) | Special DISA format |
| **InSpec** | ❌ | ✅ | ❌ | N/A | Code export only |

---

## Satisfaction Relationship Formats

### Spreadsheet Format (Vendor Comments)
```
vendor_comments: "Satisfied By: CTRL-1, CTRL-2, CTRL-3"
```

**Meaning:** This SRG requirement is satisfied by those component controls

**Direction:** `srg_requirement.satisfied_by << control`

**Parsing:** `create_rule_satisfactions` method

---

### XCCDF Format (VulnDiscussion)
```xml
<VulnDiscussion>
Control description...

Satisfies: SRG-OS-000024, SRG-OS-000027, SRG-OS-000031
</VulnDiscussion>
```

**Meaning:** This component control satisfies those SRG requirements

**Direction:** `control.satisfies << srg_requirement`

**Parsing:** `create_rule_satisfactions_from_xccdf` method

---

### Both formats are valid and used!

**Spreadsheet:** User lists controls that satisfy requirements
**XCCDF:** User lists requirements that a control satisfies

**System must handle BOTH directions!**

---

## Critical Missing Features

### 1. Update Existing Component from File (HIGH PRIORITY)

**User wants:**
- Export component XCCDF
- Edit offline
- Re-import to UPDATE same component

**Implementation needed:**
- New controller action: `update_from_file`
- UI: "Update from File" button on component page
- Logic:
  - Match rules by version or rule_id
  - Update existing rules (don't create new)
  - Add new rules if not found
  - Remove rules not in file (with confirmation?)
  - Preserve history/reviews/locks

---

### 2. Project-Level Backup/Restore (MEDIUM PRIORITY)

**User wants:**
- Backup entire project
- Restore on different instance
- Include members, history, everything

**Implementation needed:**
- Export: ZIP with all components + metadata JSON
- Import: Create project + components + members
- Format: Custom JSON with schema version

---

### 3. Conflict Detection and Merge (LOW PRIORITY)

**User wants:**
- Warning if importing outdated version
- Merge capability for parallel edits

**Implementation needed:**
- Version tracking (last_exported_at?)
- Diff view before import
- Merge UI

---

## Questions for User

1. **Update vs Create:** When importing XCCDF/XLSX, should Vulcan:
   - **A)** Always create new component (current behavior)
   - **B)** Detect existing by prefix and ASK to update or create new
   - **C)** Separate buttons: "Import New" vs "Update from File"

2. **Satisfaction conflicts:** If importing sets "Control A satisfies Req-1" but Req-1 is already satisfied by Control B, should we:
   - **A)** Replace (Control A now satisfies, B doesn't)
   - **B)** Add (both A and B satisfy it)
   - **C)** Warn user and ask

3. **Missing controls on re-import:** If exporting 50 controls but re-importing only 45, should we:
   - **A)** Keep the 5 missing ones
   - **B)** Delete the 5 (assume intentional removal)
   - **C)** Ask user

4. **Project backup scope:** Should project backup include:
   - All components? (even released/locked ones?)
   - Member assignments?
   - Audit history?
   - Review comments?

5. **SRG auto-detection:** Should XCCDF import auto-detect which SRG to use based on SRG IDs in the file?

---

## Recommendations

### Immediate (v2.3.0):
1. ✅ Fix XCCDF import (DONE)
2. ✅ Support both "Satisfies:" and "Satisfied By:" (DONE)
3. ✅ Set admin_name/email on import (DONE)
4. Test and commit

### Next (v2.3.1):
1. **Add "Update from File" functionality**
   - Most requested feature
   - Critical for edit → export → import workflow
2. Auto-detect SRG from XCCDF content
3. Better error messages on import failures

### Future (v2.4.0):
1. Project-level backup/restore
2. Conflict detection and merge
3. Import history/diff view

---

**Status:** Ready for user feedback on workflows and priorities
