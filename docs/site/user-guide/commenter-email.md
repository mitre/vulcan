# Commenter Email Visibility

Triagers need to understand *who* is commenting — which organization a
commenter represents (RedHat, RapidFort, DISA, MITRE, …) is often the
key context for evaluating a comment. Wherever the triage UI names a
commenter, it renders their name as an avatar badge whose hover card
carries their email address.

## In the comments table

The component triage page's table view has an **Author** column showing
the commenter's avatar and name. The column sorts; hover the name to see
the email. There is no separate email column — the page's filters are
status, section and free-text search, not per-column filters.

## In split-pane and other views

Hovering over a commenter's name anywhere in the triage UI (split-pane,
by-rule view, individual comment cards, response threads) surfaces a
card with their email address.

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

Both paths use the same display treatment (the hover card on the name
badge); the difference is the source field, not the UI.

## Permissions

In the triage UI, email is visible to anyone with read access to the
comments — same permission as reading the comment text itself. No
additional gate.

The disposition-matrix export is stricter: its optional email column is
only emitted for project admins, so a non-admin's export carries the
commenter name without the address.
