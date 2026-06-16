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

Project admins manage templates from inside the split-pane triage
view. Open the **Insert template…** dropdown above the response
textarea — admins see a **⚙ Manage templates…** entry at the bottom of
the dropdown that opens the **Response Templates** modal.

Inside the modal:

- **Create** — fill in a name and body (markdown supported, rendered
  via the EasyMDE editor) and click **Save Template**. The new
  template appears immediately in the dropdown for all project
  members.
- **Edit** — click the pencil icon next to any existing template to
  edit its name and body inline. Click **Save** to commit.
- **Delete** — click the trash icon to remove a template. Existing
  responses that were inserted from a template are not affected
  (templates are starting points, not live references).

Each template has:

- **Name** — short label shown in the dropdown (max 200 chars,
  unique within the project, case-insensitive).
- **Body** — the response text inserted into the response field
  (markdown supported).

Viewers and authors on the project can read the template list (to
populate the dropdown); only admins see the **Manage templates…**
entry and can mutate. The REST API at
`/projects/:id/triage_response_templates` is also available for
programmatic seeding (admin-write, viewer-read).

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
