# Bulk Triage

When the same concern lands as many separate comments (e.g. a single
commenter posts "logging not applicable" on 20 different rules in a STIG),
the triager can apply one decision to all of them in a single action
rather than working each comment individually.

## When to use

- A commenter has filed many near-identical comments and they all warrant
  the same triage decision (Accepted / Accepted with Changes / Declined /
  Informational / Needs Clarification).
- You want every original comment thread to receive its own response — bulk
  triage **copies** the response per comment so each thread stays
  self-contained.

If you want to *consolidate* duplicates into one canonical comment instead
of triaging each one, see [Merge Comments](./merge-comments).

## How to use

Bulk triage is available in both **table view** and **by-requirement
(accordion) view** on a component's comment-triage page.

1. **Select** the comments you want to triage together. In table view,
   click the checkbox at the left of each row, or use the header checkbox
   to select all visible rows on the current page. In accordion view, click
   the checkbox on each comment entry.
2. The **bulk-triage bar** appears at the bottom of the list when one or
   more comments are selected. It shows the count, a status dropdown, an
   optional response textarea, an **Apply** button, and **Clear**.
3. Pick a triage status from the dropdown.
4. (Optional, **required for Declined**) Type a response in the textarea.
   The same text is copied into each selected thread as a new reply from
   you.
5. Click **Apply to N**. On success, the list refreshes and the bar
   clears.

## What happens on the server

For each selected comment, in one transaction:

- `triage_status`, `triage_set_by_id`, and `triage_set_at` are updated.
- A response comment is created on the same rule with the same text
  (one copy per original, not a shared reference).
- All per-row audit rows share the request's `request_uuid`, so the bulk
  action is recoverable as a single correlated group from the audit trail.

Terminal statuses (Duplicate, Informational, Withdrawn, Addressed By)
auto-adjudicate via the `auto_set_adjudicated_for_terminal_statuses`
callback — same behavior as the single-comment triage form.

## Permissions

Author tier or higher on the project. The endpoint also enforces the
project's `frozen_for_writes?` gate, so once the component's
public-comment phase is final, bulk triage is blocked alongside every
other write.

## Constraints

- **Within a single component only.** Selecting comments across multiple
  components is rejected with a 422; the bulk-triage bar reads
  `selectedIds` from the currently-loaded component only, so this is
  difficult to hit through the UI but is enforced server-side regardless.
- **Status restrictions.** The dropdown excludes statuses that need a
  per-comment target — `Duplicate` (needs a canonical pointer per comment)
  and `Addressed By` (needs a specific rule per comment). Use single
  triage for those.
- **Page-scoped selection.** In the table view, *Select All* covers the
  visible page (25 rows by default); the by-rule accordion loads all
  comments for the component so its select-all spans everything in that
  view. A future enhancement (filter-scoped select-all across pages) is
  tracked separately.

## Related

- [Merge Comments](./merge-comments) — consolidate same-author duplicates
  into a single survivor instead of triaging each independently.
