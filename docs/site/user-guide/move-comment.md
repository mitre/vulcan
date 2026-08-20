# Move Comment

Project admins can retroactively move a comment from one requirement to
another within the same component. The original target is preserved as
[provenance](./comment-provenance), the comment text is annotated with a
visible marker, and an audit trail entry is recorded — so the move is
both legible to triagers reading the thread and traceable through the
audit log.

This is the general-purpose admin tool for fixing comments that landed
on the wrong rule (e.g. before [Soft Redirect](./soft-redirect) existed,
or for one-off corrections). It's also the foundation that batch
re-parenting tools build on.

## When to use

- A commenter posted on the wrong requirement and the right one is in
  the same component.
- Cleaning up legacy comments that pre-date Soft Redirect.
- Consolidating comments that should have landed on a different rule
  for triage workflow reasons.

For cross-component moves: not supported (and intentionally so —
component-scoped triage workflows depend on the within-component
invariant).

## How to use

1. Open the comment in the triage UI (split-pane view or single-comment
   modal).
2. Open the admin actions disclosure and click **Move to rule…**.
3. The Move Comment modal asks for:
   - **Target rule** — picker scoped to the current component.
   - **Reason** — required; written into the audit row and visible in
     the comment's prepended marker.
4. Confirm. The move happens in one transaction.

## What happens on the server

`Review#move_to_rule!(target_rule, reason:, moved_by:)`:

- Updates `rule_id` and the polymorphic `commentable_id`/`commentable_type`
  to the target rule (dual-write).
- Sets `original_commentable_id` if it isn't already set — preserves the
  commenter's *first* target across multiple moves (see
  [Comment Provenance](./comment-provenance)).
- Prepends a visible marker to the comment text:
  ```
  [Moved from CNTR-00-001028: typo'd rule id]
  The original comment body...
  ```
- Writes a `vulcan_audited` audit row capturing the `rule_id` /
  `commentable_id` change with the operator's reason in `audit_comment`.
- **Cascades to the reply subtree** — every reply nested under the
  moved comment (recursively) also gets its `rule_id`/`commentable_*`
  rewritten to the target rule so the whole thread stays attached. The
  cascade uses the same depth-N walk as `admin_destroy`.

## Permissions and gating

- **Admin-only** on the project.
- **Audit comment required** (the reason field) — enforced before the
  action runs; blank reasons are rejected with a 422 toast.
- **Component-scoped** — target rule must be in the same component as
  the source. Cross-component moves are rejected.
- **Frozen components** are blocked alongside every other triage write.

## What the reader sees

A comment that has been moved shows:

- The `[Moved from PREFIX-RULE_ID: reason]` line at the top of the
  comment text.
- The reply thread (if any) attached to it at the new location.
- An audit row in the admin trail naming the operator, the time, the
  old and new rule_ids, and the reason.

Replies stay with the parent — readers don't see partial threads at the
old rule.

## Related

- [Soft Redirect](./soft-redirect) — automatic child→parent rewrite for
  *new* comments on satisfied requirements.
- [Comment Provenance](./comment-provenance) — the
  `original_commentable_id` column that survives multiple moves.
