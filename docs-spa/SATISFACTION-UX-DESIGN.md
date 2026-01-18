# Satisfaction Relationship UX Design

**Created:** 2025-12-03 (Session 94)
**Status:** Approved for Implementation

---

## Overview

Satisfaction relationships link requirements together:
- **Parent** (satisfies): The primary rule that covers multiple related requirements
- **Child** (satisfied-by): Rules whose requirements are met by the parent

---

## Design Principles

1. **Actions near visualization** - If user sees the relationship, they can act on it
2. **Context-appropriate scale** - Table for bulk, Focus for single
3. **Progressive disclosure** - Simple first, advanced available
4. **Clear but not intrusive** - Visual cues that don't overwhelm

---

## Chosen Pattern: Hybrid B + E

### Table View - Satisfied-By Rows

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ID     │ Title               │ CAT    │ Status       │ Satisfies          │
├────────────────────────────────────────────────────────────────────────────┤
│ 000023 │ SSH Idle Timeout    │ CAT I  │ Configurable │ →2                 │
│▌000024 │ Session Lock        │ CAT II │ Configurable │ ← (clickable)      │
│▌000025 │ Idle Disconnect     │ CAT II │ Configurable │ ←                  │
│ 000026 │ Audit Logging       │ CAT II │ NYD          │ —                  │
└────────────────────────────────────────────────────────────────────────────┘
  ↑
  Subtle left border (2-3px, light blue/gray) indicates "child" status
```

### Popover on Click (← indicator)

```
┌──────────────────────────────────┐
│ Satisfied by:                    │
│ SRG-OS-000023 - SSH Idle Timeout │
│                                  │
│ [Go to Parent] [Unlink]          │
└──────────────────────────────────┘
```

### Popover on Click (→N indicator)

```
┌──────────────────────────────────┐
│ Satisfies 2 requirements:        │
│                                  │
│ • 000024 - Session Lock    [Go→] │
│ • 000025 - Idle Disconnect [Go→] │
│                                  │
│ [+ Add More]                     │
└──────────────────────────────────┘
```

---

## Bulk Actions (Table Toolbar)

When rows are selected:

```
┌────────────────────────────────────────────────────────────────────────┐
│ ☐ 5 selected                    [Set Status ▾] [Set Satisfies ▾]       │
└────────────────────────────────────────────────────────────────────────┘

[Set Satisfies ▾] dropdown:
├─ Satisfy another requirement...  (opens picker modal)
├─ Remove satisfaction            (removes selected from parent)
└─ Move to different parent...    (opens picker, relink in single action)
```

---

## Focus View - Satisfaction Panel

Satisfaction panel as first-class section in editor (above fields):

```
┌─────────────────────────────────────────────────────────────────────────┐
│ SRG-OS-000023 · SSH Idle Timeout                           [← →] [🔓] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ Status: [Configurable ▾]  CAT II                                        │
│                                                                         │
│ ┌─ Satisfies ─────────────────────────────────────────────────────────┐ │
│ │ This requirement satisfies 2 others:                    [+ Add]     │ │
│ │                                                                     │ │
│ │  • SRG-OS-000024 (Session Lock)        [Go →] [✕ Remove]            │ │
│ │  • SRG-OS-000025 (Idle Disconnect)     [Go →] [✕ Remove]            │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─ Title ─────────────────────────────────────────────────────────────┐ │
```

For satisfied-by (child) requirements:

```
│ ┌─ Satisfied By ──────────────────────────────────────────────────────┐ │
│ │ This requirement is satisfied by:                                   │ │
│ │                                                                     │ │
│ │  SRG-OS-000001 (Parent Rule)    [Go to Parent →] [Unlink] [Move to…]│ │
│ └─────────────────────────────────────────────────────────────────────┘ │
```

---

## Alternative Options (For Future Iteration)

### Option A: Inline Badge Only
```
│ 000024 │ Session Lock │ CAT II │ Configurable │ ← Satisfied │
```
- Simpler, no row styling
- Less visually distinct

### Option C: Indented with Parent Reference
```
│ 000023 │ SSH Idle Timeout    │ CAT I  │ Configurable │ →2          │
│    ↳ 000024 │ Session Lock   │ CAT II │ (Satisfied)  │             │
```
- Shows hierarchy in flat view
- Complicates sorting

### Option D: Badge After Title
```
│ 000024 │ Session Lock ← via 000023 │ CAT II │ Configurable │
```
- Context inline with title
- Makes title column messier

### Option E: Tooltip Only (Minimalist)
```
│ 000024 │ Session Lock │ CAT II │ Configurable │ ← │
                                                   ↑ hover shows details
```
- Cleanest appearance
- Lower discoverability

---

## Implementation Order

1. **SatisfiesIndicator popover** - Add click handler, popover with parent/child info
2. **Row styling** - Subtle left border for satisfied-by rows
3. **Bulk actions** - Toolbar dropdown for selected rows
4. **Focus view panel** - Refactor RuleSatisfactions.vue to Composition API

---

## Technical Notes

### Popover Component
- Use Bootstrap-Vue-Next `BPopover` or Reka UI `Popover`
- Position: bottom-start for table cells
- Close on click outside

### Row Styling
```css
.satisfied-by-row {
  border-left: 3px solid var(--bs-info);
  background-color: rgba(var(--bs-info-rgb), 0.03);
}
```

### API for Satisfaction Actions
- Existing: `POST /api/rules/:id/add_satisfied`
- Existing: `DELETE /api/rules/:id/remove_satisfied`
- Need: Bulk endpoint for multiple rules

---

*Last Updated: 2025-12-03*
