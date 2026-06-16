# Comment Review Statistics — Plan

**Date:** 2026-05-20
**Status:** Planned — execute after BenchmarkViewer migration (ec3)
**Scope:** Add triage progress tracking across 4 screens

---

## Context

Triagers need to see at a glance how much comment review work remains. Currently
the only indicator is the pending count badge. This plan adds progress bars and
status breakdowns to 4 screens, using data already available from the
`paginated_comments` API.

## Screens

### Screen 1: Component Triage Page — Status Bar (P1)

Location: Above the filter bar on `/components/:id/triage`

```
┌──────┬──────────┬──────────┬─────────┬────────┬─────────────┐
│  23  │ 16 Pend  │ 3 Accept │ 1 Decl  │ 1 Info │ 2 Withdrawn │
│total │ ████████ │ ███      │ █       │ █      │ ██          │
└──────┴──────────┴──────────┴─────────┴────────┴─────────────┘
```

- Horizontal stacked bar using triage-bg colors
- Counts per status, total on left
- Uses same triage-tints.css color system
- Data: computed client-side from `rows` when filter is "all", or a
  lightweight server endpoint returning just counts

### Screen 2: Project Triage Page — Per-Component Progress (P2)

Location: Above the table on `/projects/:id/triage`

```
┌───────────────────┬───────┬────────┬─────────┬──────────────┐
│ Component         │ Total │ Pending│ Triaged │ Progress     │
├───────────────────┼───────┼────────┼─────────┼──────────────┤
│ Container Platform│  23   │  16    │    7    │ ███░░░░░ 30% │
│ Web Server        │  12   │   4    │    8    │ ██████░░ 67% │
│ Database          │   8   │   0    │    8    │ ████████ 100%│
└───────────────────┴───────┴────────┴─────────┴──────────────┘
```

- Per-component row with progress bar
- Sorted by % complete ascending (most work first)
- Needs: `Component.pending_comment_counts` already exists, extend to
  return total + per-status breakdown
- Consider: new `Component.comment_status_counts(component_ids)` class method

### Screen 3: Component Editor Header — Inline Progress (P2)

Location: Next to the Triage button badge in ControlsCommandBar

```
| Triage (16) ███░░░░░ 30% |
```

- Tiny inline progress bar next to the existing pending count badge
- Width: ~80px, height: 4px, inside the button or adjacent
- Data: `pending_comment_count` already in blueprint, add `total_comment_count`

### Screen 4: Split-Pane Nav — Progress Indicator (P3)

Location: Replace "18 pending" text in TriageQueueNav

```
16 pending of 23 total  ███████░░░░░░░░ 30%
```

- Progress bar inline with the pending count text
- Shows how far through the queue the triager is
- Data: already available from `rows` array length + filter

## Implementation Notes

### Data Strategy

**Option A: Client-side only** — filter all statuses via API, count client-side.
Simple but requires loading all comments to get accurate counts.

**Option B: Server endpoint** — new lightweight endpoint or parameter on
`paginated_comments` that returns just `{ status_counts: { pending: 16,
concur: 3, ... }, total: 23 }` without loading full rows.

**Recommendation:** Option B for Screens 1-3 (count query is cheaper than
loading all rows). Option A for Screen 4 (already has the rows loaded).

### Shared Component

Create `CommentProgressBar.vue`:
- Props: `counts` (object with status keys), `total` (number)
- Renders: stacked horizontal bar with triage-bg colors
- Sizes: `size="sm"` (Screen 3/4 inline), `size="md"` (Screen 1/2 full width)
- Reusable across all 4 screens

### API Changes

Add `status_counts` to `paginated_comments` response:
```json
{
  "rows": [...],
  "pagination": { "page": 1, "total": 23, "total_comments": 23 },
  "status_counts": {
    "pending": 16,
    "concur": 3,
    "concur_with_comment": 1,
    "non_concur": 1,
    "informational": 1,
    "withdrawn": 1
  }
}
```

This piggybacks on the existing endpoint with a single GROUP BY query.

## Work Order

Execute after BenchmarkViewer migration (ec3), which changes the triage page
layout. Building stats into the new layout avoids rework.

1. Shared: CommentProgressBar component + API status_counts
2. Screen 1: Component triage status bar
3. Screen 2: Project triage per-component progress
4. Screen 3: Component editor inline progress
5. Screen 4: Split-pane nav progress
