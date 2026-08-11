# Soft Redirect

When a commenter posts on a **child** requirement (one that is satisfied
by a parent control via the satisfies/satisfied-by relationship), the
comment is automatically saved on the **parent control** instead — with
the original rule preserved in both the visible text and a machine-queryable
column.

This prevents the comment-fragmentation problem where 93 of 116 Container
SRG comments landed on children instead of parents and were invisible from
the parent-control view.

## What the commenter sees

When the active requirement in the comment composer is satisfied-by a
parent, an InfoNotice appears above the textarea:

> This requirement is satisfied by **CNTR-00-000010**. Your comment will
> be posted there.

After submit, a success toast confirms where the comment landed:

> Comment posted on parent control CNTR-00-000010.

The toast names the actual parent, not a generic message.

## What lands in the database

Server-side, a `before_create` callback rewrites the new review's
`rule_id` and `commentable_id` to point at the parent rule. The original
text gets a human-readable prefix:

```
[Re: CNTR-00-001028]
The original comment body here...
```

And the original rule is captured machine-readably on
`original_commentable_id` (see [Comment Provenance](./comment-provenance))
so exports, reports, and queries can recover the original target without
parsing prose.

## When this doesn't apply

- The active requirement isn't satisfied-by anything (no parent control)
  — comment posts on the active rule as expected.
- The active requirement **is** the parent — already at the right level,
  no redirect.
- Replies (a reply to a comment that's already on the parent) — replies
  stay attached to their parent comment and don't re-redirect.

## Related

- [Comment Provenance](./comment-provenance) — the `original_commentable_id`
  column that machine-readably preserves the original target.
- [Move Comment](./move-comment) — admin tool to retroactively move
  existing comments between rules (also writes `original_commentable_id`).
