# Runbook — Public Comment Admin Actions (PR #717 phase 1)

**Audience:** project administrators handling rare exception cases during a public comment review window.

**When to use:** the standard triage workflow (CommentTriageModal → triage decision → adjudicate) covers ~99% of comments. This runbook covers the rare events that can't go through the standard UI.

**this phase's design decision (2026-04-29):** these admin actions are intentionally NOT in the UI for the first release. Console operations are auditable via VulcanAuditable + the explicit `audit_comment` setter and are documented here so admins have a clean path for incident response. Promoting any of these to UI is tracked as a follow-up phase (deferred Tasks 25 + 26 — see Task 99).

---

## 1. Force-withdraw a comment (admin override)

**When:** spam, PII leak, content that violates policy, or a commenter whose account was disabled and whose comment must be retracted.

**Authorization:** project administrator (`current_user.can_admin_project?(project)` returns true) — verify membership before acting.

```ruby
# Open Rails console:
#   bundle exec rails console
# OR for a remote/Heroku environment:
#   heroku run rails console -a <app-name>

review = Review.find(<review_id>)
admin = User.find_by(email: '<your_admin_email>')

# Verify authorization
unless admin.can_admin_project?(review.rule.component.project)
  raise "Not authorized — must be project admin"
end

# Required: audit_comment setter (VulcanAuditable persists this on the next save)
review.audit_comment = "Admin force-withdraw: <reason — required>"
review.update!(
  triage_status: 'withdrawn',
  adjudicated_at: Time.current,
  adjudicated_by_id: admin.id
)
puts "Withdrew review #{review.id}; audit log: #{review.audits.last.comment.inspect}"
```

**Verification:** the comment row in the triage queue should now show "Withdrawn" status; `review.audits.last.comment` should contain the audit reason.

---

## 2. Move a comment to a different rule (with replies)

**When:** a commenter posted on the wrong rule (confused two similar rules; meant the baseline but landed on the implementation; etc.) and the misplaced comment + its reply thread should be reassigned.

**Authorization:** project administrator.

**Important:** the model has a `responding_to_must_be_same_rule` validator that will reject if you move the parent without moving the replies. **Move children first OR run inside a transaction that defers the validator.**

```ruby
review = Review.find(<review_id>)
target_rule = Rule.find(<target_rule_id>)
admin = User.find_by(email: '<your_admin_email>')

# Validations
unless admin.can_admin_project?(review.rule.component.project)
  raise "Not authorized"
end
unless target_rule.component_id == review.rule.component_id
  raise "Target rule must be in the same component"
end
if target_rule.id == review.rule_id
  raise "Target rule is the same as source"
end

reason = "Admin move-to-rule: <reason — required>"

# Walk the reply tree CHILDREN-FIRST so the same-rule validator is satisfied.
move_subtree = lambda do |r|
  Review.where(responding_to_review_id: r.id).find_each { |child| move_subtree.call(child) }
  r.audit_comment = reason
  r.update!(rule_id: target_rule.id)
end

ActiveRecord::Base.transaction do
  move_subtree.call(review)
end

puts "Moved review #{review.id} (+ replies) to rule #{target_rule.id}"
```

**Note:** `vulcan_audited only:` (review.rb:38) does NOT currently include `:rule_id`. If audit visibility on the move is required for compliance, add `:rule_id` to the audited list temporarily, perform the move, then revert if you don't want ongoing rule_id audits. (When Task 26 ships in a follow-up phase, we'll add rule_id to the audit list permanently.)

---

## 3. Hard-delete a comment (PII / extreme cases)

**When:** a comment contains PII or sensitive content that must NOT be retained even in withdrawn form. This is rare and irreversible.

**Authorization:** project administrator + a documented compliance reason.

**Preferred approach:** force-withdraw (Section 1) first. Hard delete only when retention itself is the problem.

```ruby
review = Review.find(<review_id>)
admin = User.find_by(email: '<your_admin_email>')

# Authorization + double-check
unless admin.can_admin_project?(review.rule.component.project)
  raise "Not authorized"
end

# Capture the audit trail BEFORE deletion (the audit log persists even after
# the record is gone, but capturing the deletion event explicitly is cleaner).
audit_note = "ADMIN HARD DELETE: #{review.id} on rule #{review.rule_id}, " \
             "by #{admin.email}, reason: <documented_reason>"
Rails.logger.warn(audit_note)

# Replies cascade via dependent: :destroy (review.rb:20)
review.destroy!
puts "Hard-deleted review #{review.id} and any replies."
```

**After hard delete:**
- File the action in your compliance tracker
- Note the timestamp + reason + admin in the project's audit record
- The review's prior `audits` records remain in the audited gem's table (audited gem keeps audit records on the auditable side; deletion of the parent does NOT cascade audits by default)

---

## 4. Mark a comment as a duplicate (cross-rule consolidation)

**This IS in the UI as of this phase** (Task 24, CommentTriageModal). Use the UI:

1. Open the triage queue
2. Click the duplicate row's `[Triage]` button
3. Select "Mark as duplicate of..." decision
4. Search and select the canonical comment (must be in the same component)
5. Provide an audit comment, save

The model auto-adjudicates duplicate-status comments via
`auto_set_adjudicated_for_terminal_statuses` (review.rb:307-313), so the
duplicate row shows "Closed" without further action when the canonical
is concur'd or non-concur'd.

---

## 5. Bulk operations (none in this phase)

For bulk close, bulk withdraw, bulk re-categorize: do them one at a time
via the standard workflow. There is no bulk-action UI in this phase, and console
loops bypass the per-action audit comment requirement which is necessary
for federal compliance review. **Do not script bulk changes.**

If a genuine bulk need arises, it's a follow-up-phase ticket — file as
a follow-up plan task with the use case + numbers.

---

## 6. Recovery from accidental destructive action

If you accidentally force-withdraw the wrong comment:

```ruby
review = Review.find(<review_id>)
review.audit_comment = "Reverting accidental admin force-withdraw"
review.update!(
  triage_status: 'pending',  # or whatever the prior status was
  adjudicated_at: nil,
  adjudicated_by_id: nil
)
```

Use `review.audits.last(N)` to see the prior status before reverting.

For accidental hard-delete: there is no recovery short of a database restore. Hard delete is genuinely irreversible — that's why Section 3 says "rare and irreversible."

---

## 7. Logging this runbook's use

Anytime you use this runbook in production, add a note to the project's
operational log:

- **What:** force-withdraw / move-to-rule / hard-delete
- **Why:** documented reason
- **Who:** admin email
- **When:** timestamp
- **Affected:** review_id(s), rule(s), commenter(s)

This protects both the project and the admin against later compliance review.
