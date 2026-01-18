# Requirements Editor - Final Design Specification

**Version:** 1.0
**Created:** 2025-12-02 (Sessions 83-84)
**Status:** Approved for Implementation

---

## Executive Summary

The Requirements Editor is the core authoring interface for Vulcan. This document specifies a complete redesign based on:
- Deep analysis of author workflows (STIG and SRG authoring)
- Industry UX patterns (Linear, GitHub Projects, VS Code, Notion)
- Field-level locking for iterative review workflows
- Adaptive layouts for different screen sizes and work modes

**Core Principle**: "It's the Author's world - everyone else just lives in it."

---

## Design Overview

### Two Views, One Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         REQUIREMENTS EDITOR                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐                    ┌─────────────────────────────────┐ │
│  │ TABLE VIEW  │ ◄───── toggle ────►│          FOCUS VIEW             │ │
│  │             │                    │                                 │ │
│  │ • Overview  │                    │  ┌─────────┐    ┌─────────────┐ │ │
│  │ • Triage    │                    │  │Reference│    │  Reference  │ │ │
│  │ • Progress  │                    │  │  Open   │ OR │  Collapsed  │ │ │
│  │ • Bulk ops  │                    │  │ (50/50) │    │(full width) │ │ │
│  │ • Filter    │                    │  └────┬────┘    └──────┬──────┘ │ │
│  │             │                    │       │                │        │ │
│  └─────────────┘                    │       └───── [Cmd+R] ──┘        │ │
│                                     │                                 │ │
│                                     │  ┌─────────────────────────────┐│ │
│                                     │  │   Field Expanded (Modal)    ││ │
│                                     │  │        [Cmd+E] / [⤢]        ││ │
│                                     │  └─────────────────────────────┘│ │
│                                     └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Table View Specification

### Purpose
- See all requirements at once (the "map")
- Triage new components (bulk status changes)
- Track progress across the component
- Quick access to workflow items (pending reviews, recent changes)

### Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ RHEL 9 STIG v1.0          ████████░░ 198/251            [Table● │ Focus]│
├─────────────────────────────────────────────────────────────────────────┤
│ [Filter▾] [Search...] [Group: Status ▾]           [☐ 3 selected → Set▾] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌─ Summary Cards ─────────────────────────────────────────────────────┐ │
│ │ 📋 Pending Review: 12  │ 📝 Recently Changed: 8  │ 🔒 Locked: 186    │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ▼ Not Yet Determined (53)                                     [Collapse]│
│ ├─ ☐ │ 000023 │ SSH Idle Timeout     │ CAT II │ [NYD ▾] │ 🔒🔒🔓🔓      │
│ ├─ ☐ │ 000024 │ Session Lock         │ CAT II │ [NYD ▾] │ 🔓🔓🔓🔓      │
│                                                                         │
│ ▼ Applicable - Configurable (147)                                       │
│ ├─ ☐ │ 000001 │ Account Lockout      │ CAT I  │ Config  │ 🔒🔒🔒🔒 ✓ 💬2│
│ ├─ ☐ │ 000002 │ Password Length      │ CAT II │ Config  │ 🔒🔒🔓🔓      │
│                                                                         │
│ ▶ Inherently Meets (24)                                                 │
│ ▶ Does Not Meet (3)                                                     │
│ ▶ Not Applicable (24)                                                   │
│                                                                         │
│ Double-click → Focus view │ [j/k] navigate │ [Enter] edit               │
└─────────────────────────────────────────────────────────────────────────┘
```

### Table View Features

| Feature | Description |
|---------|-------------|
| **Header** | Component name, progress bar, view toggle |
| **Summary Cards** | Quick stats with click-to-filter |
| **Filter Dropdown** | Status, Severity, Lock Status, Has Comments |
| **Search** | Full-text search across titles |
| **Group By** | Status (default), Severity, Lock Status |
| **Bulk Selection** | Checkbox column, select all in group |
| **Bulk Actions** | Change status of selected |
| **Status Dropdown** | Inline status change per row |
| **Lock Progress** | Visual indicator (🔒🔒🔓🔓 = 2/4 locked) |
| **Comment Badge** | 💬2 = has pending comments |
| **Collapsible Groups** | Expand/collapse status sections |

### Table View Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `j` | Next row |
| `k` | Previous row |
| `Enter` | Open Focus view for selected |
| `Space` | Toggle checkbox |
| `/` | Focus search |
| `Cmd+A` | Select all visible |

---

## Focus View Specification

### Purpose
- Deep authoring work on one requirement
- Side-by-side reference to other STIGs
- Field-level editing with expand option
- Automation scripts (InSpec, Ansible, etc.)

### Layout: Reference Panel Open (Default for empty fields)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ RHEL 9 STIG │ ████░░░░ 45/251 │ [Filter▾] │ SRG-OS-000023 │ [← →] [🔓] │
├─────────────────────────────────┬───────────────────────────────────────┤
│ YOUR CONTENT                    │ REFERENCE              [RHEL 8│Win22] │
│                                 │                                       │
│ Status: [Configurable ▾] CAT II │ ┌─ Vuln Discussion ────────────[●]─┐  │
│                                 │ │ Terminating idle sessions limits │  │
│ ┌─ Title ────────[🔒 Locked]─┐  │ │ exposure window for attackers... │  │
│ │ SSH Idle Timeout Config    │  │ │                       [📋 Copy]  │  │
│ └────────────────────────────┘  │ └───────────────────────────────────┘ │
│                                 │                                       │
│ ┌─ Vuln Discussion ──[🔒]─[⤢]─┐ │ ┌─ Check ───────────────────────────┐ │
│ │ Terminating an idle        │◀─│ │ Verify SSH ClientAliveInterval   │ │
│ │ session reduces the        │  │ │ is set to 600 or less:           │ │
│ │ window of opportunity...   │  │ │                       [📋 Copy]  │ │
│ └────────────────────────────┘  │ └───────────────────────────────────┘ │
│                                 │                                       │
│ ┌─ Check ────────[🔓]─────[⤢]─┐ │ ┌─ Fix ─────────────────────────────┐ │
│ │ Verify the SSH daemon      │  │ │ Configure SSH daemon:            │ │
│ │ is configured to           │  │ │ ClientAliveInterval 600          │ │
│ │ terminate idle sessions    │  │ │                       [📋 Copy]  │ │
│ │ $ grep -i clientalive \    │  │ └───────────────────────────────────┘ │
│ │   /etc/ssh/sshd_config     │  │                                       │
│ │                    [Lock🔒]│  │ [More references →]                   │
│ └────────────────────────────┘  │                                       │
│                                 └───────────────────────────────────────┤
│ ┌─ Fix ──────────[🔓]─────[⤢]─┐                                         │
│ │ Configure the SSH daemon   │                                          │
│ │ $ sudo vi /etc/ssh/...     │                                          │
│ │                    [Lock🔒]│                                          │
│ └────────────────────────────┘                                          │
│                                                                         │
│ ┌─ Automation ──────────────────────────────────────────────────────┐   │
│ │ [InSpec ●] [Ansible] [Chef] [Shell]                        [+ Add]│   │
│ │ ```ruby                                                           │   │
│ │ control 'SRG-OS-000023' do                                        │   │
│ │   describe sshd_config do                                         │   │
│ │     its('ClientAliveInterval') { should cmp <= 600 }              │   │
│ │   end                                                             │   │
│ │ end                                                    [⤢] [Copy] │   │
│ └───────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│ [💬 Reviews 2] [📜 History 5]         [Lock Remaining] [Request Review] │
└─────────────────────────────────────────────────────────────────────────┘
```

### Layout: Reference Panel Collapsed (Full-width focus)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ RHEL 9 STIG │ ████░░░░ 45/251 │ [Filter▾] │ SRG-OS-000023 │ [← →] [🔓] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ Status: [Configurable ▾]  CAT II                         [📚 Reference] │
│                                                                         │
│ ┌─ Title ─────────────────────────────────────────────────[🔒 Locked]─┐ │
│ │ SSH Idle Timeout Configuration                                      │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─ Vuln Discussion ──────────────────────────────────[🔒 Locked]──[⤢]─┐ │
│ │ Terminating an idle session within a short time period reduces the  │ │
│ │ window of opportunity for unauthorized personnel to take control... │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─ Check ──────────────────────────────────────────────────[🔓]───[⤢]─┐ │
│ │ Verify the SSH daemon is configured to terminate idle sessions      │ │
│ │ after 15 minutes of inactivity:                                     │ │
│ │                                                                     │ │
│ │ $ grep -i clientalive /etc/ssh/sshd_config                          │ │
│ │ ClientAliveInterval 600                                             │ │
│ │ ClientAliveCountMax 0                                               │ │
│ │                                                             [Lock🔒]│ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─ Fix ────────────────────────────────────────────────────[🔓]───[⤢]─┐ │
│ │ Configure the SSH daemon to terminate idle sessions:                │ │
│ │ $ sudo vi /etc/ssh/sshd_config                                      │ │
│ │ ClientAliveInterval 600                                             │ │
│ │                                                             [Lock🔒]│ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─ Automation ──────────────────────────────────────────────────────┐   │
│ │ [InSpec ●] [Ansible] [Chef] [Shell]                        [+ Add]│   │
│ │ ```ruby                                                           │   │
│ │ control 'SRG-OS-000023' do                                        │   │
│ │   describe sshd_config do                                         │   │
│ │     its('ClientAliveInterval') { should cmp <= 600 }              │   │
│ │   end                                                  [⤢] [Copy] │   │
│ └───────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│ [💬 Reviews 2] [📜 History 5]         [Lock Remaining] [Request Review] │
└─────────────────────────────────────────────────────────────────────────┘
```

### Layout: Field Expanded (Full-screen modal)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Check Content                                           [Done (Cmd+E)] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ Verify the SSH daemon is configured to terminate idle sessions      │ │
│ │ after 15 minutes of inactivity:                                     │ │
│ │                                                                     │ │
│ │ $ grep -i clientalive /etc/ssh/sshd_config                          │ │
│ │                                                                     │ │
│ │ ClientAliveInterval 600                                             │ │
│ │ ClientAliveCountMax 0                                               │ │
│ │                                                                     │ │
│ │ If "ClientAliveInterval" is not set to "600" or less, or is         │ │
│ │ commented out, this is a finding.                                   │ │
│ │                                                                     │ │
│ │ If "ClientAliveCountMax" is not set to "0", this is a finding.      │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ Characters: 487                                        Auto-saved ✓     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Focus View Features

| Feature | Description |
|---------|-------------|
| **Smart Header** | Progress, filter, current rule, nav arrows |
| **Status Dropdown** | Change requirement status inline |
| **Editor Fields** | Title, Vuln Discussion, Check, Fix |
| **Field Expand** | [⤢] opens full-screen editor |
| **Field Lock** | Lock individual fields, shows who/when |
| **Reference Panel** | Side-by-side with scroll-spy sync |
| **Reference Tabs** | Switch between 1-2 primary reference STIGs |
| **More References** | Slideout with all related STIGs/Components |
| **Copy Button** | Copy from reference to editor field |
| **Automation Panel** | InSpec, Ansible, Chef, Shell tabs |
| **Reviews Button** | Opens reviews slideout |
| **History Button** | Opens history slideout |
| **Lock Actions** | Lock field, Lock remaining, Lock all |

### Focus View Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `j` | Next rule |
| `k` | Previous rule |
| `Cmd+S` | Save |
| `Cmd+E` | Expand/collapse current field |
| `Cmd+R` | Toggle reference panel |
| `Cmd+J` | Command palette (jump to rule) |
| `Cmd+B` | Back to Table view |
| `Tab` | Next field |
| `Shift+Tab` | Previous field |
| `Esc` | Close modal/slideout |

---

## Reference Panel Specification

### Scroll-Spy Behavior

The reference panel stays synchronized with the editor:

```
EDITING:                          REFERENCE HIGHLIGHTS:
┌─ Title ────────────────────┐    ┌─ Title ─────────────────[●]─┐
│ SSH Idle Timeout Config█   │    │ SSH Idle Timeout            │
└────────────────────────────┘    └─────────────────────────────┘

EDITING:                          REFERENCE HIGHLIGHTS:
┌─ Check ────────────────────┐    ┌─ Check ─────────────────[●]─┐
│ Verify the SSH daemon█     │    │ Verify SSH ClientAlive...   │
└────────────────────────────┘    └─────────────────────────────┘
```

### Primary Reference STIGs

Component can have 1-2 "primary reference STIGs" pinned:

```
Reference Header:
┌────────────────────────────────────────────────────────────────┐
│ REFERENCE                               [RHEL 8 ●] [Win 2022]  │
│                                          ↑ Tab to switch       │
└────────────────────────────────────────────────────────────────┘
```

### More References Slideout

```
                                    ┌─────────────────────────────────────┐
                                    │ All Related Rules            [Close]│
                                    │ SRG-OS-000023 (8 found)             │
                                    ├─────────────────────────────────────┤
                                    │ Filter: [STIGs ✓] [Components ✓]    │
                                    │ Search: [___________________]       │
                                    │                                     │
                                    │ ★ RHEL 8 STIG V1R12 (primary)       │
                                    │   V-230296                          │
                                    │   ▶ Check                           │
                                    │   ▶ Fix                             │
                                    │                                     │
                                    │ ★ Windows Server 2022 (primary)     │
                                    │   V-254239                          │
                                    │   ▶ Check                           │
                                    │   ▶ Fix                             │
                                    │                                     │
                                    │ ─────────────────────────────────── │
                                    │                                     │
                                    │ ▶ Ubuntu 22.04 STIG                 │
                                    │ ▶ CentOS 9 Component                │
                                    │                                     │
                                    │ [Set as Primary Reference]          │
                                    └─────────────────────────────────────┘
```

### Copy Behavior

| Source State | Target State | Action |
|--------------|--------------|--------|
| Reference has content | Target field empty | **Replace** |
| Reference has content | Target field has content | **Append** with separator |

Append format:
```
[Existing content]

--- Copied from RHEL 8 STIG V-230296 ---

[Copied content]
```

---

## Field-Level Locking Specification

### Why Field-Level Locking?

SRG authoring workflow is iterative by field:
1. Week 1: Agree on all Titles → Lock titles
2. Week 2: Agree on all Vuln Discussions → Lock vuln discussions
3. Week 3-4: Agree on Check/Fix → Lock remaining → Release

### Lock States

| State | Icon | Description |
|-------|------|-------------|
| Unlocked | 🔓 | Field can be edited |
| Locked | 🔒 | Field is locked, shows who/when |
| Fully Locked | 🔒🔒🔒🔒 ✓ | All 4 fields locked, ready for release |

### Lock Progress in Table View

```
│ ID     │ Title              │ Lock Status     │
│────────┼────────────────────┼─────────────────│
│ 000023 │ SSH Idle Timeout   │ 🔒🔒🔓🔓 (2/4)   │
│ 000024 │ Session Lock       │ 🔒🔒🔒🔒 ✓       │
│ 000025 │ Password Complex   │ 🔓🔓🔓🔓 (0/4)   │
```

### Lock Metadata

Each lock stores:
- `locked_at`: timestamp
- `locked_by`: user reference
- Display: "Locked by Jane Smith · Nov 15, 2025"

### Lock Actions

| Action | Location | Description |
|--------|----------|-------------|
| Lock Field | Field header [Lock🔒] | Lock individual field |
| Unlock Field | Field header [Unlock] | Unlock (with permission) |
| Lock Remaining | Footer | Lock all unlocked fields |
| Lock All | Footer | Lock all fields (if any unlocked) |

### Filter by Lock Status

```
Filter dropdown:
├─ Lock Status
│   ├─ All
│   ├─ Fully Locked
│   ├─ Partially Locked
│   ├─ Not Locked
│   ├─ Title Unlocked
│   ├─ Vuln Discussion Unlocked
│   ├─ Check Unlocked
│   └─ Fix Unlocked
```

---

## Automation Panel Specification

### Purpose

Store automation artifacts alongside requirement content:
- InSpec controls (validation/testing)
- Ansible tasks (hardening/remediation)
- Chef recipes (hardening/remediation)
- Shell scripts (hardening/remediation)

### Layout

```
┌─ Automation ──────────────────────────────────────────────────────┐
│ [InSpec ●] [Ansible] [Chef] [Shell]                        [+ Add]│
├───────────────────────────────────────────────────────────────────┤
│ ```ruby                                                           │
│ control 'SRG-OS-000023' do                                        │
│   title 'SSH Idle Timeout'                                        │
│   desc 'Verify SSH terminates idle sessions'                      │
│                                                                   │
│   describe sshd_config do                                         │
│     its('ClientAliveInterval') { should cmp <= 600 }              │
│     its('ClientAliveCountMax') { should cmp 0 }                   │
│   end                                                             │
│ end                                                               │
│ ```                                                               │
│                                                    [⤢ Expand] [Copy]│
└───────────────────────────────────────────────────────────────────┘
```

### Features

- Tabbed interface for different automation types
- Syntax highlighting per type (Ruby, YAML, Bash)
- Expand to full-screen editor
- Copy to clipboard
- [+ Add] to create new automation script

---

## Review Workflow Specification

### Review States (Existing Model)

The review system already exists with these states:

| State | `review_requestor_id` | `locked` | `changes_requested` | Description |
|-------|----------------------|----------|---------------------|-------------|
| **Draft** | null | false | false | Normal editing state |
| **Under Review** | user_id | false | false | Awaiting reviewer action |
| **Changes Requested** | null | false | true | Reviewer asked for changes |
| **Approved/Locked** | null | true | false | Approved, no more edits |

### Review Actions

| Action | Who Can Do | Effect |
|--------|------------|--------|
| `request_review` | Author | Sets `review_requestor_id`, notifies reviewers |
| `revoke_review_request` | Original requestor or Admin | Cancels review request |
| `request_changes` | Reviewer or Admin (not requestor) | Clears request, sets `changes_requested` |
| `approve` | Reviewer or Admin (not requestor) | Locks the rule |
| `lock_control` | Admin only | Direct lock without review |
| `unlock_control` | Admin only | Unlocks for further editing |

### Review Workflow in UI

```
AUTHOR VIEW:
┌─────────────────────────────────────────────────────────────────────────┐
│ SRG-OS-000023 · SSH Idle Timeout                                        │
│                                                                         │
│ Status: Under Review                              [Revoke Review Request]│
│ Requested by: You · 2 hours ago                                         │
│ Waiting for: Jane Smith, Bob Jones (reviewers)                          │
│                                                                         │
│ [Fields shown as read-only while under review]                          │
└─────────────────────────────────────────────────────────────────────────┘

REVIEWER VIEW:
┌─────────────────────────────────────────────────────────────────────────┐
│ SRG-OS-000023 · SSH Idle Timeout                         [Review Actions]│
│                                                                         │
│ Status: Pending Your Review                                             │
│ Requested by: Alice · 2 hours ago                                       │
│                                                                         │
│ [Fields shown for review - read-only]                                   │
│                                                                         │
│ Add Review Comment:                                                     │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                                                                     │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ [Comment Only]  [Request Changes]  [✓ Approve]                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Integration with Table View

Summary card shows pending reviews:
```
┌─ Summary Cards ─────────────────────────────────────────────────────────┐
│ 📋 Pending Review: 12  │ 🔄 Changes Requested: 3  │ ✓ My Reviews: 5     │
└─────────────────────────────────────────────────────────────────────────┘
     ↑ Click to filter        ↑ Items needing author attention
```

Table shows review status:
```
│ ID     │ Title            │ Status    │ Review Status        │ Lock     │
│────────┼──────────────────┼───────────┼──────────────────────┼──────────│
│ 000023 │ SSH Idle Timeout │ Config    │ 📋 Pending (Alice)   │ 🔓🔓🔓🔓  │
│ 000024 │ Session Lock     │ Config    │ 🔄 Changes Requested │ 🔓🔓🔓🔓  │
│ 000025 │ Password Complex │ Config    │ ✓ Approved           │ 🔒🔒🔒🔒  │
│ 000026 │ Audit Logging    │ Config    │ —                    │ 🔓🔓🔓🔓  │
```

### Filter by Review Status

```
Filter dropdown:
├─ Review Status
│   ├─ All
│   ├─ Pending Review (awaiting action)
│   ├─ Changes Requested (needs author attention)
│   ├─ My Review Requests (I requested)
│   ├─ Needs My Review (I'm a reviewer)
│   └─ No Review Activity
```

### Review + Field Lock Interaction

With field-level locking, the review workflow becomes:

**Option A: Review locks entire rule (current behavior)**
- Request review → all fields read-only
- Approve → all fields locked

**Option B: Review locks per-field (future enhancement)**
- Request review for specific field(s)
- Approve specific field(s)
- More granular but more complex

**Recommendation**: Keep Option A for v1, consider Option B for future.

---

## Slideout Panels

### Reviews Slideout

```
                                    ┌─────────────────────────────────────┐
                                    │ Reviews                      [Close]│
                                    │ SRG-OS-000023                       │
                                    ├─────────────────────────────────────┤
                                    │                                     │
                                    │ ✓ Approved                          │
                                    │   Jane Smith · 2 days ago           │
                                    │   "Looks good, tested on RHEL 9.2"  │
                                    │                                     │
                                    │ ─────────────────────────────────── │
                                    │                                     │
                                    │ 💬 Comment                          │
                                    │   Bob Jones · 3 days ago            │
                                    │   "Should we add the InSpec ctrl?"  │
                                    │                                     │
                                    │   ↳ Reply from Jane:                │
                                    │     "Yes, I'll add it"              │
                                    │                                     │
                                    │ ─────────────────────────────────── │
                                    │                                     │
                                    │ Add Comment:                        │
                                    │ ┌─────────────────────────────────┐ │
                                    │ │                                 │ │
                                    │ └─────────────────────────────────┘ │
                                    │                                     │
                                    │ [Comment] [Request Changes] [Approve│
                                    └─────────────────────────────────────┘
```

### History Slideout

```
                                    ┌─────────────────────────────────────┐
                                    │ History                      [Close]│
                                    │ SRG-OS-000023                       │
                                    ├─────────────────────────────────────┤
                                    │                                     │
                                    │ Today                               │
                                    │ ├─ Check locked by Jane             │
                                    │ │   2:34 PM                         │
                                    │ │                                   │
                                    │ ├─ Check updated by Alice           │
                                    │ │   2:30 PM                         │
                                    │ │   "Added ClientAliveCountMax"     │
                                    │ │                        [View Diff]│
                                    │                                     │
                                    │ Yesterday                           │
                                    │ ├─ Fix updated by Alice             │
                                    │ │   4:15 PM                         │
                                    │ │                        [View Diff]│
                                    │ │                          [Revert] │
                                    │                                     │
                                    │ Nov 28                              │
                                    │ ├─ Title locked by Jane             │
                                    │ ├─ Vuln Discussion locked by Jane   │
                                    │                                     │
                                    └─────────────────────────────────────┘
```

---

## Navigation

### Command Palette (Cmd+J)

Already implemented. Used for:
- Jump to specific rule by ID or title
- Filter rules by status/severity
- Quick actions

### Progress Dots

```
Header:
┌─────────────────────────────────────────────────────────────────────────┐
│ RHEL 9 STIG │ ████░░░░ 45/251 │ [Filter▾] │ SRG-OS-000023 │ [← →] [🔓] │
└─────────────────────────────────────────────────────────────────────────┘
                    ↑
           Progress bar (click to see breakdown)
```

### Arrow Navigation

`[← →]` buttons in header for sequential navigation (same as j/k keys).

---

## Responsive Behavior

| Screen Width | Table View | Focus View |
|--------------|------------|------------|
| Wide (1400px+) | Full table with all columns | Editor + Reference side-by-side |
| Medium (1024-1400px) | Compact table (fewer columns) | Editor full, Reference as slideout |
| Narrow (<1024px) | Card-based list | Editor full, Reference as modal |

---

## Data Model Changes

### Field-Level Locks

```ruby
# Option A: Columns on Rule
class Rule
  # Existing fields...

  # Lock columns per field
  title_locked_at: datetime
  title_locked_by_id: bigint (references users)

  vuln_discussion_locked_at: datetime
  vuln_discussion_locked_by_id: bigint

  check_locked_at: datetime
  check_locked_by_id: bigint

  fix_locked_at: datetime
  fix_locked_by_id: bigint

  # Helper methods
  def title_locked?
    title_locked_at.present?
  end

  def fully_locked?
    title_locked? && vuln_discussion_locked? && check_locked? && fix_locked?
  end

  def lock_progress
    [title_locked?, vuln_discussion_locked?, check_locked?, fix_locked?].count(true)
  end
end
```

### Primary Reference STIGs

```ruby
class Component
  # Existing...

  # Store up to 2 primary reference STIG IDs
  primary_reference_stig_ids: jsonb  # [123, 456]

  def primary_reference_stigs
    Stig.where(id: primary_reference_stig_ids)
  end
end
```

### Automation Scripts

```ruby
class AutomationScript
  belongs_to :rule

  script_type: string  # 'inspec', 'ansible', 'chef', 'shell'
  content: text

  timestamps
end
```

---

## API Changes

### Field Lock Endpoints

```
POST   /api/rules/:id/lock_field
       { field: 'title' | 'vuln_discussion' | 'check' | 'fix' }

POST   /api/rules/:id/unlock_field
       { field: 'title' | 'vuln_discussion' | 'check' | 'fix' }

POST   /api/rules/:id/lock_all
```

### Primary Reference STIGs

```
GET    /api/components/:id/primary_references
PUT    /api/components/:id/primary_references
       { stig_ids: [123, 456] }
```

### Automation Scripts

```
GET    /api/rules/:id/automation_scripts
POST   /api/rules/:id/automation_scripts
       { script_type: 'inspec', content: '...' }
PUT    /api/automation_scripts/:id
DELETE /api/automation_scripts/:id
```

---

## Component Summary

### New Components to Build

```
app/javascript/
├── components/requirements/
│   ├── TableView/
│   │   ├── SummaryCards.vue          # Quick stats cards
│   │   ├── StatusGroup.vue           # Collapsible status group
│   │   ├── LockProgress.vue          # 🔒🔒🔓🔓 indicator
│   │   └── BulkActions.vue           # Bulk status change
│   │
│   ├── FocusView/
│   │   ├── EditorField.vue           # Title/Vuln/Check/Fix field
│   │   ├── FieldLock.vue             # Lock button + metadata
│   │   ├── FieldExpand.vue           # Full-screen modal
│   │   ├── AutomationPanel.vue       # InSpec/Ansible/Chef/Shell
│   │   └── FocusHeader.vue           # Rule nav + progress
│   │
│   ├── ReferencePanel/
│   │   ├── ReferencePanel.vue        # Main container
│   │   ├── ReferenceTabs.vue         # RHEL 8 | Win 2022 tabs
│   │   ├── ReferenceContent.vue      # Scroll-spy synced content
│   │   └── CopyButton.vue            # Copy to editor
│   │
│   └── Slideouts/
│       ├── RelatedRulesPanel.vue     # All related STIGs
│       ├── ReviewsPanel.vue          # Comments/approvals
│       └── HistoryPanel.vue          # Audit log with revert
```

### Modified Components

```
app/javascript/
├── pages/components/ControlsPage.vue  # Add view toggle, new layout
├── components/requirements/
│   ├── RequirementsTable.vue          # Add summary cards, lock progress
│   ├── RequirementsFocus.vue          # Major refactor for new design
│   └── RequirementsToolbar.vue        # Add filter by lock status
```

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Time to triage 250 rules | ~4 hours | ~2 hours |
| Time to author one rule | ~15 min | ~8 min |
| Reference lookups per rule | 3-5 clicks | 0-1 clicks |
| Keyboard-only workflow | Not possible | Fully supported |

---

## Appendix: Research Sources

- [Linear](https://linear.app) - Triage workflow, keyboard navigation
- [GitHub Projects](https://github.com/features/issues) - Table vs Board views
- [VS Code](https://code.visualstudio.com) - Panel layouts, keyboard shortcuts
- [Notion](https://notion.so) - Adaptive layouts, blocks
- [Figma](https://figma.com) - Right panel patterns

---

*Document Version: 1.0*
*Last Updated: 2025-12-02*
