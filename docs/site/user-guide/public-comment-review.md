# Public Comment Review

This page is the starting point for the **Comment Triage** section. If
you've never used Vulcan's comment workflow before, read this first —
the pages that follow it dive into specific features that only make
sense in context.

## What is a public comment period?

When a draft Security Technical Implementation Guide (STIG) is ready
for outside review, its authors open a **public comment period**:
a fixed window during which authorized reviewers (DoD operators,
implementers, vendors, subject-matter experts) read the draft
requirements and submit feedback. Feedback ranges from objections
("this check won't work on RHEL 9") to suggested edits ("the fix text
should reference SELinux") to clarifying questions to confirmations
that a requirement is already correct.

The authors then **triage** every comment — decide whether to accept
the feedback as written, accept it with modifications, decline it, ask
for clarification, or note that another requirement already covers
the issue. Each triage decision is recorded with an optional response
to the commenter and an audit trail so the resolution can be defended
later.

This workflow exists because security guidance is too consequential
to publish without scrutiny from the people who will operate under it.
Vulcan implements the workflow per the DISA Vendor STIG Process Guide
(V4R3).

## Who participates?

Vulcan's project roles form a ladder — *viewer*, *author*,
*reviewer*, *admin* — and the comment workflow draws three tiers out
of it:

- **Commenters** post comments during the open comment period. Any
  project member can — posting a comment needs only *viewer*. The role
  named *reviewer* is not the "person who comments" role; in Vulcan it
  is the rule-review and section-locking tier, above *author*.
  Replying inside an existing thread stays available while triage is
  active, even after the comment window closes.
- **Authors** triage, respond to and adjudicate comments. They hold
  *author* or higher on the project. Authors do most of the
  day-to-day triage work — the bulk of this section is about their
  tools.
- **Admins** can do everything an author can plus the admin-only
  operations: merging duplicate comments, moving misposted comments
  between rules, managing the response-template library, force-
  withdrawing comments, and hard-deleting (rare). They hold the
  *admin* role on the project.

There is no separate "adjudicator" role. Adjudication is an
author-or-higher action, and the record keeps who triaged and who
adjudicated as separate attributions.

## The lifecycle of a single comment

```
   submit ──▶ triage ──▶ (respond) ──▶ adjudicate ──▶ closed
              │                                          ▲
              └──── needs_clarification ──── reply ──────┘
```

1. **Submit** — a reviewer posts a comment on a specific rule
   section (the check text, fix text, discussion, etc.) during an
   open comment period.
2. **Triage** — an author assigns a triage status (see the table
   below). Some statuses (informational, withdrawn, duplicate,
   addressed_by) auto-adjudicate; others wait for the author to
   write a response and explicitly adjudicate.
3. **Respond** (optional but recommended) — the author writes a
   reply to the commenter explaining the decision. The reply is
   visible in the comment thread and on the commenter's "My
   Comments" page.
4. **Adjudicate** — a final decision closes the comment. It stays
   visible, and the thread can still take replies; what ends replying
   for good is finalizing the component's comment phase.

A comment left at `needs_clarification` stays open, waiting on the
commenter: it is not adjudicated, so it keeps showing up in the
triage queue until the author records a decision.

## Triage statuses

The status is the primary lever an author uses. The decision form
offers six of them; *Pending* is the starting state and *Withdrawn*
belongs to the commenter.

The decision form shows a plain-English label with the DISA matrix
term in brackets, so you can work the form and still speak DISA's
vocabulary in the disposition.

| Status | Meaning | Terminal? |
|---|---|---|
| **Pending** | Not yet reviewed — the default for new comments. Not selectable. | No |
| **Accept (Concur)** | Accepted — change will be made to the requirement. | No — adjudicate to close |
| **Accept with changes (Concur with comment)** | Accepted with modifications spelled out in the response. | No — adjudicate to close |
| **Decline (Non-concur)** | Declined — no change. A response is required. | No — adjudicate to close |
| **Informational** | Noted, no action required. | Yes (auto-adjudicates) |
| **Needs clarification** | More info needed from the commenter; the comment stays in the queue. | No |
| **Withdrawn** | Commenter retracted (or admin force-withdrew). Not selectable by the author. | Yes (auto-adjudicates) |
| **Duplicate** | Same issue as another comment in this component — linked to the survivor. A comment picker appears at triage time. See [Merge Comments](./merge-comments). | Yes (auto-adjudicates) |
| **Addressed by** | Covered by another requirement (per DISA V4R3 §4.1.15). A requirement picker appears at triage time; it offers any other requirement in the component. | Yes (auto-adjudicates) |

## The three triage views

The triage page (`/components/:id/triage`) shows the same comment set
three ways. Two are a toggle in the page header; the third you enter
from a row.

- **Table view** — every comment as a sortable row. Filter by triage
  status, section, or text search. Best for bulk operations (select
  many rows, apply one decision) and for scanning everything at a
  glance.
- **Group by rule** — comments grouped under their target
  requirement. Expandable accordion with an **Expand All** switch.
  Best for working a requirement at a time.
- **Split-pane** — reached by clicking **Triage** on a comment in
  either of the other two views. The rule's content on one side, the
  active comment and decision form on the other, with prev/next
  arrows to walk the queue. Best for focused, one-at-a-time triage
  with the full rule context visible. The split-pane view is where
  the response-template dropdown and the per-comment admin actions
  live.

## Feature reference

Each of the following has its own page in this section — this list is
a map for which page solves which problem:

- **[Comment Provenance](./comment-provenance)** — how Vulcan tracks
  where a comment originally landed even when the requirement is
  later reorganized or the comment is moved.
- **[Soft Redirect](./soft-redirect)** — comments posted on a child
  rule that's satisfied-by a parent are auto-routed to the parent
  where they can be acted on, with the original child preserved for
  provenance and disposition export.
- **[Move Comment](./move-comment)** — admin tool for relocating a
  misposted comment from one rule to another.
- **[Bulk Triage](./bulk-triage)** — select multiple comments and
  apply one decision (with a shared response) to all of them.
- **[Merge Comments](./merge-comments)** — admin consolidation of
  near-duplicate comments into one survivor.
- **[Response Templates](./response-templates)** — project-scoped
  reusable canned responses, surfaced in a dropdown above the
  response textarea.
- **[Commenter Email](./commenter-email)** — where a commenter's email
  shows up in the triage UI, and the admin gate on the export column.

## Comment period management

Component admins control the comment period from the component's
**Settings** page. The phase is either **Open** or **Closed**, and a
closed component can carry a reason that says how far the workflow has
got:

- **Open** — comments can be submitted. An end date is optional; set
  one and the component shows a countdown banner.
- **Closed** — commenting is paused without committing to a workflow
  stage.
- **Closed (Adjudicating)** — the window is closed, but triage and
  responses continue.
- **Closed (Finalized)** — the disposition is published and the
  component is frozen for writes: no comments, no replies, no triage,
  no rule edits.

The comment-period start and end dates are set on the same page.

## Disposition export

After adjudication, export a **disposition matrix** showing every
comment and how it was resolved. This is the artifact DISA expects as
the closing record of a comment period.

- **Export CSV** on the triage page itself, for author tier and above.
- **CSV** — a CSV export of a component with comments carries a second
  disposition CSV alongside the rule CSV.
- **Excel** — the workbook export gains a disposition sheet.

Each row is one top-level comment: where it landed, who posted it, the
text, the triage decision and its attribution, the adjudication, and
the reply thread collapsed into a single cell. Commenter email is an
extra column only project admins get. The active status filter on the
triage page passes through to the page's export button, so you can
export just the declines (for example) when preparing a sub-report.
