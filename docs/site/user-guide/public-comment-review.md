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

The triage workflow has four roles, each touching comments
differently:

- **Reviewers** post comments during the open comment period. In
  Vulcan they hold the *reviewer* membership role on the project.
  They can also respond to author replies in a thread.
- **Authors** triage and respond to comments on the component(s)
  they own. They hold *author* or higher on the project. Authors do
  most of the day-to-day triage work — the bulk of this section is
  about their tools.
- **Admins** can do everything an author can plus the admin-only
  operations: merging duplicate comments, moving misposted comments
  between rules, managing the response-template library, force-
  withdrawing comments, and hard-deleting (rare). They hold the
  *admin* role on the project.
- **Adjudicators** are the role responsible for finalizing decisions.
  In practice the author role often does both the triage and the
  adjudication; the distinction matters for audit purposes more than
  for the day-to-day workflow.

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
4. **Adjudicate** — a final decision closes the comment. Reviewers
   can still see it; new replies are blocked.

Comments that get `needs_clarification` loop back to the commenter
for more information and re-enter the triage queue when the commenter
responds.

## Triage statuses

The status is the primary lever an author uses. Pick one per comment:

| Status | Meaning | Terminal? |
|---|---|---|
| **Pending** | Not yet reviewed — the default for new comments. | No |
| **Concur** | Accepted — change will be made to the requirement. | Yes |
| **Concur with Comment** | Accepted with modifications spelled out in the response. | Yes |
| **Non-concur** | Declined — no change. Response should justify. | Yes |
| **Informational** | Noted, no action required. | Yes (auto-adjudicates) |
| **Needs Clarification** | More info needed from commenter — they get a notification. | No |
| **Withdrawn** | Commenter retracted (or admin force-withdrew). | Yes (auto-adjudicates) |
| **Duplicate** | Same issue as another comment in this component — linked to the survivor. See [Merge Comments](./merge-comments). | Yes (auto-adjudicates) |
| **Addressed By** | Already mitigated by a parent rule (per DISA V4R3 §4.1.15). A rule picker appears at triage time so you can select the covering parent rule. | Yes (auto-adjudicates) |

## The three triage views

The triage page (`/components/:id/triage`) offers three ways of
seeing the same comment set — pick whichever fits the task at hand:

- **Table view** — every comment as a sortable, filterable row.
  Filter by triage status, section, or text search. Best for
  bulk operations (select many rows, apply one decision) and for
  scanning everything at a glance.
- **By-Rule view** — comments grouped under their target
  requirement. Expandable accordion with a comment-count badge per
  rule. Best for working a requirement at a time.
- **Split-Pane view** — the rule's content on the left, the active
  comment + decision form on the right. Prev/next arrows to walk
  the queue. Best for focused, one-at-a-time triage with the full
  rule context visible. The split-pane view is where the response-
  template dropdown and most per-comment admin actions live.

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
- **[Commenter Email](./commenter-email)** — how Vulcan handles
  commenter email visibility and the privacy boundary between
  reviewers and authors.

## Comment period management

Administrators control the comment period via the Component Settings
page:

- **Open** — comments can be submitted.
- **Closed** — new comments are rejected; existing comments can
  still be triaged and responded to.
- **Final** — content is frozen; no comment or rule edits at all.
  Use this once the disposition matrix is final.

Set the comment period dates (`comment_period_starts_at`,
`comment_period_ends_at`) and phase (`comment_phase`) from the
settings page.

## Disposition export

After adjudication, export a **disposition matrix** showing every
comment and how it was resolved. This is the artifact DISA expects as
the closing record of a comment period.

- **CSV** — included automatically in Working Copy exports for
  components with comments.
- **Excel** — added as a separate sheet in the workbook export.

The export includes: rule ID, section, commenter, comment text,
triage status, response, adjudication date. The active filter on the
triage page passes through to the export, so you can export just
non-concurs (for example) when preparing a sub-report.
