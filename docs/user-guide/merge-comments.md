# Merge Comments

When the same commenter has filed the same concern across many
requirements (e.g. 20 identical "logging not applicable" comments from
one person), an admin can **merge** them into a single canonical comment
without losing the originating context.

This is different from [Bulk Triage](./bulk-triage):

- **Bulk triage** applies one decision to many comments and gives each
  one its own response — every original thread stays self-contained.
- **Merge** consolidates many into one: one comment becomes the
  *survivor* and carries the discussion forward; the others are marked
  `duplicate` of the survivor (not deleted) and adjudicated automatically.

## When to use

- After bulk-triaging a duplicate cluster, you want a single canonical
  thread to carry the conversation rather than N parallel threads.
- A commenter has filed the same concern across multiple rules and the
  reply traffic should land on one comment.

## How to use

Merge is admin-only. The button appears in the bulk-triage bar when an
admin selects two or more comments.

1. **Select 2+ comments by the same commenter** in either the table view
   or the by-requirement accordion (same component, same author).
2. In the bulk-triage bar, click **Merge…**. The Merge Comments modal
   opens with a side-by-side preview of every selected comment showing
   rule, author, posted date, and a preview of the body.
3. **Pick the survivor.** The radio button defaults to the
   oldest-posted comment (Zendesk convention). Pick any of the listed
   comments to make it the survivor instead.
4. Click **Merge** to confirm.

## What happens on the server

In one transaction:

- The **survivor's** comment text is prepended with a marker naming the
  originating rule labels, for example:

  ```
  [Merged: originally posted on CNTR-00-001049, CNTR-00-001054, CNTR-00-001346]

  …survivor's original text…
  ```

- Each **secondary** gets `triage_status = duplicate` and
  `duplicate_of_review_id = survivor.id`. Because `duplicate` is a
  terminal status, the `adjudicated_at` callback fires automatically, so
  the secondaries are also closed as part of the same operation.
- Secondaries are **not deleted** — they remain visible on their original
  rules with a link back to the survivor, preserving the audit trail.
- Audit rows on every row share the request's `request_uuid`, so the
  full merge is recoverable as one correlated group.

## Permissions

Project admin only. Authors and viewers cannot see or trigger the Merge
button.

## Constraints

The merge is rejected (422) and **no rows change** if:

- The selected comments span more than one component.
- The selected comments are not all from the same commenter (different
  people having the same opinion are different feedback items —
  preserved separately).
- The survivor isn't one of the selected comments.
- Fewer than one secondary remains after de-duplicating the survivor
  from the duplicates list.

## Related

- [Bulk Triage](./bulk-triage) — apply one decision per comment without
  consolidating.
