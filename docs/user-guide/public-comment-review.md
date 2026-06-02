# Public Comment Review

Vulcan supports a structured public comment review workflow for STIG development, following the DISA Vendor STIG Process Guide. Authorized reviewers submit comments on draft security requirements, and component authors triage, respond to, and adjudicate those comments.

## Comment Lifecycle

1. **Submit** — a reviewer posts a comment on a specific rule section (check, fix, discussion, etc.)
2. **Triage** — an author reviews the comment and assigns a triage status
3. **Respond** (optional) — the author posts a reply explaining their decision
4. **Adjudicate** — a reviewer or admin finalizes the decision, closing the comment

## Triage Statuses

| Status | Meaning | Terminal? |
|--------|---------|-----------|
| **Pending** | Not yet reviewed | No |
| **Concur** | Accepted — change will be made | Yes |
| **Concur with Comment** | Accepted with modifications | Yes |
| **Non-concur** | Declined — no change | Yes |
| **Informational** | Noted, no action required | Yes (auto-adjudicates) |
| **Needs Clarification** | More information needed from commenter | No |
| **Withdrawn** | Commenter retracted | Yes (auto-adjudicates) |
| **Duplicate** | Same issue as another comment (linked) | Yes (auto-adjudicates) |
| **Addressed By** | Covered by a parent rule's resolution | Yes (auto-adjudicates) |

## Triage Views

The triage page (`/components/:id/triage`) offers three views:

### Table View
All comments in a sortable, filterable table. Filter by triage status, section, or text search. Bulk select comments for batch operations.

### By-Rule View
Comments grouped by requirement. Expandable accordion shows all comments for each rule. Comment count badges indicate pending items per rule.

### Split-Pane View
Rule content on the left, comment stream on the right. Navigate between rules with prev/next arrows. Triage decisions are made inline without leaving the context.

## Bulk Triage

Select multiple comments and apply one triage decision to all of them at once.

1. Check the selection boxes on comments you want to triage
2. The **Bulk Triage Bar** appears at the bottom with the count of selected comments
3. Choose a triage status from the dropdown
4. Optionally add a response comment (copied to each selected comment)
5. Click **Apply** — all selected comments receive the same triage status

::: tip
Bulk triage is available in Table view and By-Rule view. The split-pane view handles one comment at a time.
:::

::: warning
Bulk triage cannot be used for `duplicate` or `addressed_by` statuses — those require per-comment target selection.
:::

## Merge Comments (Admin)

When multiple commenters submit essentially the same feedback, an administrator can consolidate them into a single survivor comment.

1. Select the duplicate comments (same author, same component)
2. Choose which comment survives (becomes the canonical one)
3. The other comments are marked as `duplicate` with `duplicate_of_review_id` pointing to the survivor
4. All attributions are preserved in the survivor's audit trail

This is an admin-only action that requires an audit comment explaining the merge.

## Addressed By

The `addressed_by` triage status links a comment to a **parent rule** that already addresses the issue. This is common when a child rule inherits requirements from a parent via the satisfies relationship.

1. During triage, select **Addressed By** as the status
2. A rule picker appears — select the parent rule that covers this comment
3. The comment is auto-adjudicated and marked terminal

This follows DISA V4R1 §4.1.15: a requirement fully mitigated by another STIG is encoded with a reference to the parent.

## Soft Redirect Comments

When a rule is satisfied by a parent rule (via the satisfies relationship), comments posted on the child rule are automatically redirected to the parent:

- The comment is saved on the **parent** rule (where the actual content lives)
- The original child rule is recorded in `original_commentable_id` for provenance
- The comment text is prefixed with `[Re: PREFIX-RULE_ID]` to identify the source
- Disposition exports map the comment back to the original requirement

This happens transparently — the commenter sees their comment posted, and the author sees it on the rule where it can be acted on.

## Comment Period Management

Administrators control the comment period via the Component Settings page:

- **Open** — comments can be submitted
- **Closed** — new comments are rejected; existing comments can still be triaged
- **Final** — content is frozen; no writes at all (review or rule edits)

Set the comment period dates (`comment_period_starts_at`, `comment_period_ends_at`) and phase (`comment_phase`) from the settings page.

## Disposition Export

After adjudication, export a disposition matrix showing all comments and their resolutions:

- **CSV** — included automatically in Working Copy exports for components with comments
- **Excel** — added as a separate sheet in the workbook export

The export includes: rule ID, section, commenter, comment text, triage status, response, adjudication date.
