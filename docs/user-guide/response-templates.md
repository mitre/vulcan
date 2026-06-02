# Triage Response Templates

When triagers find themselves writing the same response to similar
comments across a STIG (e.g. "we will generalize the check and fix text"
repeated across dozens of related rules), they can save that response
as a project-scoped template and pull it into the triage form via a
dropdown — preserving the per-comment thread, attribution, and any
typed-in additions.

## Template scope

Templates are **project-scoped** — shared with every member of the
project, not user-private. Two consequences:

- Reviewers on the same project see the same library, so the same
  canned responses can be applied consistently by anyone triaging.
- Templates do not bleed across projects. Each project starts with
  zero templates; admins seed the library as patterns emerge.

## Managing templates (admin)

Project admins can create, edit, and delete templates through the
`/projects/:id/triage_response_templates` API endpoints (a UI page is
not part of this release — initial template seeding goes through
direct API calls or rails console). Each template has:

- **Name** — short label shown in the dropdown (max 200 chars,
  unique within the project, case-insensitive).
- **Body** — the response text inserted into the response field.

Viewers and authors on the project can read the template list (to
populate the dropdown); only admins can mutate.

## Using a template (any triager)

In the split-pane triage view, the **Insert template…** dropdown sits
just above the response textarea inside the "Response to commenter"
group. When you pick a template:

- If the response field is empty, the template body replaces it
  cleanly.
- If you've already typed something, the template body is **appended**
  below your draft (separated by a blank line) — your typed text is
  preserved, not clobbered.

The dropdown resets to the placeholder after each insertion, so
re-selecting the same template re-fires (handy if you accidentally
delete the inserted text).

You can always edit the inserted text before submitting — templates
are starting points, not auto-sends.

## When templates don't appear

The dropdown is hidden when the triage form doesn't have a project
context (e.g. component-scoped views that don't propagate a
`projectId`). When the project context is present and the project has
no templates yet, the dropdown still renders but shows a disabled
"No templates yet" placeholder so you know the feature is wired —
just empty.

## Related

- [Bulk Triage](./bulk-triage) — apply one decision (with one shared
  response) to many comments. The bulk-triage response field also
  benefits from templates *once* the dropdown is wired into that
  surface (not in this release).
