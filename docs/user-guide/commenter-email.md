# Commenter Email Visibility

Triagers need to understand *who* is commenting — which organization a
commenter represents (RedHat, RapidFort, DISA, MITRE, …) is often the
key context for evaluating a comment. The triage UI surfaces commenter
email in two places: a hover tooltip on the name, and a dedicated
column in the table view.

## In the comments table

The component triage page's table view includes a **Commenter** column
showing the commenter's email next to the name. Sortable and filterable
like every other column.

## In split-pane and other views

Hovering over a commenter's name anywhere in the triage UI (split-pane,
accordion, individual comment cards, response threads) surfaces a
tooltip with their email address.

## Attribution sources

The email shown is the commenter's *most authoritative* attribution
available:

- **Direct user attribution** — when the commenter resolves to a `User`
  on this instance (most common), the email comes from
  `commenter.email`.
- **Imported attribution** — for comments imported from another Vulcan
  instance where the commenter doesn't exist locally, the email is read
  from `commenter_imported_email` on the review row. These are flagged
  with an "imported" badge so triagers know the address is preserved
  from the source archive and can't be used to look up a local user.

Both paths use the same display treatment (hover tooltip + table
column); the difference is the source field, not the UI.

## Permissions

Email is visible to anyone with read access to the comments — same
permission as reading the comment text itself. No additional gate.
