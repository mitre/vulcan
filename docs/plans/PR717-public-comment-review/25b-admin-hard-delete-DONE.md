# Task 25b: Admin hard-delete UI — DONE

**Shipped in:** commit referenced in this PR.

## What ships

A new admin-only **Hard-delete** action on the comment-triage modal,
peer to Force-withdraw and Restore (Task 25). Permits a project admin
to irreversibly destroy a comment + its reply subtree when the standard
withdraw + restore flow is insufficient (PII / legal hold / sensitive
content that must not be retained even in withdrawn form).

## Backend

`DELETE /reviews/:id/admin_destroy`
- `before_action :authorize_admin_project` — admin-only.
- `audit_comment` parameter required (422 if blank).
- Destroys the review; `Review#responses dependent: :destroy` cascades
  to the reply subtree.
- Federal-compliance audit entry created on the **component** (parent
  of the destroyed review) BEFORE the destroy so the audit trail
  survives the cascade. Captures: actor user_id, action
  `admin_destroy_review`, audit comment text, structured payload
  (review_id, rule_id, original author_id, reply_count).
- Phase enforcement does NOT apply — admin override must work even
  after the component is `final` / frozen_for_writes.

## Frontend

CommentTriageModal "Admin actions" disclosure gains a third button:
**Hard-delete** (red `outline-danger`).

Clicking it reveals a typed-confirmation safeguard:
- Audit-comment textarea (required).
- Explicit warning: "This permanently deletes the comment AND ALL
  REPLIES. It cannot be undone."
- Confirmation-id input: admin must type the review's numeric ID
  exactly to enable the Confirm button (typo-resistant compared to
  console).

`canSubmitAdminAction` returns true only when:
- audit_comment is non-blank, AND
- adminConfirmationId equals `String(review.id)`.

On confirm:
- `axios.delete('/reviews/:id/admin_destroy', { data: { audit_comment } })`
- Emits `destroyed` event with the review id so the parent
  (`ComponentComments.vue`) can refresh the queue.
- Modal closes; admin-action state resets.

## Why hard-delete in UI (not Rails console)

The original PR-717 phase-1 design deferred admin actions to a Rails
console runbook. Yesterday Aaron decided that approach was the wrong
shape — admin actions belong in UI with proper safeguards, not in
ad-hoc procedures.

For an irreversible operation, UI is **safer than console**, not
riskier:
- Console: one wrong ID destroys data; `Rails.logger.warn` audit is
  brittle and easy to forget.
- UI: typed-confirmation forces explicit attention to the target ID;
  audit entry is created automatically by the controller before the
  destroy; admin-only authorization is server-enforced.

## Tests

- 4 new request specs in `spec/requests/reviews_spec.rb`
  (admin-cascade, audit-comment-required, audit-on-component-survives,
  non-admin-403).
- 4 new modal specs in
  `spec/javascript/components/components/CommentTriageModal.spec.js`
  (button renders in disclosure, typed-confirmation gating,
  delete request shape, destroyed event emission).

## Visual verification

Logged in as admin@example.com, opened triage queue, clicked Triage on
the pending review, expanded "Admin actions" disclosure. Confirmed
Force-withdraw + Hard-delete buttons render (Restore correctly hidden
on a non-adjudicated review). Clicked Hard-delete; warning copy
("cannot be undone"), audit textarea, and confirmation-id input all
rendered correctly with Confirm button disabled until both fields
are filled correctly.
