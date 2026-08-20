# Comment Provenance

Comments can move between rules in two ways: automatically (via
[Soft Redirect](./soft-redirect) on child→parent satisfies relationships)
or manually (via the admin [Move Comment](./move-comment) action). In
both cases, the original rule the commenter actually targeted is
preserved on the review row for the life of the record.

## The provenance pair

Every re-parented comment carries two parallel records of where it
originally came from:

1. **Human-readable prefix** in the comment text:
   ```
   [Re: CNTR-00-001028]
   The commenter's original text...
   ```
   or, when an admin moves the comment retroactively:
   ```
   [Moved from CNTR-00-001028: typo'd rule id]
   The original comment text...
   ```
   Triagers reading the thread see this in line; it's a prose artifact.

2. **`original_commentable_id`** — a machine-queryable column on
   `reviews` that holds the BaseRule id of the comment's *first* target.
   Set once on the first re-parenting and never overwritten, so even if
   a comment gets moved a second time the field still points at where
   the commenter originally posted.

The two channels serve different audiences:

- Triagers reading inline → the prose prefix.
- Disposition exports, audit reports, "which rules attracted comments
  on the source side" queries → the column.

## Where it gets set

- **Soft redirect** (`Review` `before_create` callback): when a comment
  on a child rule is rewritten to point at the parent control, the
  callback sets `original_commentable_id` to the child rule's id.
- **Admin move-to-rule** (`Review#move_to_rule!`): when an admin moves
  a comment from rule A to rule B, the model sets
  `original_commentable_id` to A — **but only if it isn't already set**.
  Re-moves preserve the first move's provenance so the audit trail
  always points back to the commenter's original target, not an
  intermediate stop.

## Where it shows up

- **JSON-archive export**: the export serializer carries
  `original_commentable_id` (mapped through to the destination instance's
  rule on re-import) so cross-instance backup/restore preserves the
  provenance.
- **Import**: `ReviewBuilder` remaps the field through the archive's
  `rule_id` → new local `BaseRule.id` map (`@rule_id_map`), same as
  `addressed_by_rule_id` and the parent FK refs in Pass 2.

## Why both prefix and column

The prose prefix is what a triager sees when scrolling a thread; the
column is what an export reader queries. Either alone has failure modes:

- Prose-only: queries can't reliably extract the original rule (different
  prefix formats over time, hand-edited comments, locale differences).
- Column-only: triagers reading the rendered thread see no indication
  the comment was re-parented; "[Re: …]" provides the context inline.

Together they cover both reading paths.

## Related

- [Soft Redirect](./soft-redirect) — the automatic child→parent rewrite
  that's the most common source of re-parented comments.
- [Move Comment](./move-comment) — the admin tool for retroactive moves.
