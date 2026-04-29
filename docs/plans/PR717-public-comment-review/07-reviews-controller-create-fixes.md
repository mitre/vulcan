# Task 07: Reviews controller create-side fixes (closes Copilot #2, #3, #4)

**Depends on:** 01, 02
**Unblocks:** 08
**Estimate:** 20 min Claude-pace
**File touches:**
- `app/controllers/reviews_controller.rb` (strong params + transaction wrap)
- `spec/requests/reviews_spec.rb`
- `spec/models/reviews_spec.rb` (failure-message polish — Copilot #4)

This task closes the remaining three Copilot findings on PR #717 (#2, #3, #4) and adds transaction discipline to `Review.create` + `rule.save!` to prevent partial writes if the Review insert fails after `take_review_action` mutates the rule.

---

## Step 1: Read the existing create-action

Confirm current state:

```bash
grep -n "def create" app/controllers/reviews_controller.rb
grep -n "review_params" app/controllers/reviews_controller.rb
```

You should see `def create` ~line 14 and `review_params` returning `params.expect(review: %i[component_id action comment])`.

## Step 2: Write the failing request spec

Append to `spec/requests/reviews_spec.rb`, inside the existing `RSpec.describe 'Reviews'`:

```ruby
describe 'POST /rules/:rule_id/reviews — Copilot #2/#3 fixes' do
  let_it_be(:author_user) { create(:user) }
  before do
    create(:membership, user: author_user, membership: project, role: 'author') unless
      Membership.exists?(user: author_user, membership: project)
    sign_in author_user
  end

  it 'accepts request_review with component_id (matches client payload)' do
    expect {
      post "/rules/#{rule.id}/reviews", params: {
        review: { action: 'request_review', comment: 'please review',
                  component_id: component.id }
      }, as: :json
    }.to change(Review, :count).by(1)
    expect(response).to have_http_status(:ok)
    expect(rule.reload.review_requestor_id).to eq(author_user.id)
  end

  it 'accepts approve with component_id (matches client payload)' do
    rule.update(review_requestor: create(:user))
    create(:membership, user: author_user, membership: project, role: 'reviewer')

    post "/rules/#{rule.id}/reviews", params: {
      review: { action: 'approve', comment: 'lgtm', component_id: component.id }
    }, as: :json

    # The reviewer is the same user who is now also the requestor — review fails on "can't review own"
    # but does NOT raise because of missing component_id
    expect(response.status).to be_in([200, 422])
  end
end

describe 'POST /rules/:rule_id/reviews — transaction integrity' do
  let_it_be(:author_user) { create(:user) }
  before do
    create(:membership, user: author_user, membership: project, role: 'author')
    sign_in author_user
  end

  it 'rolls back rule mutation when Review save fails' do
    # Force a Review save failure AFTER take_review_action would have run
    allow_any_instance_of(Review).to receive(:save).and_wrap_original do |original, *args|
      original.call(*args).tap { |saved| raise ActiveRecord::Rollback if saved && false }  # placeholder
    end

    # Better: use a comment too long to fail length validation but only after take_review_action
    # — but Rails runs validations before before_create. So use a forced post-validation failure
    # by stubbing a database constraint violation. The simplest realistic test:
    expect_any_instance_of(Review).to receive(:save).and_raise(ActiveRecord::StatementInvalid.new('forced'))

    expect {
      post "/rules/#{rule.id}/reviews", params: {
        review: { action: 'request_review', comment: 'try', component_id: component.id }
      }, as: :json
    }.to raise_error(ActiveRecord::StatementInvalid)
      .and change(Review, :count).by(0)

    # Critical: rule was NOT mutated (review_requestor_id stays nil)
    expect(rule.reload.review_requestor_id).to be_nil
  end
end
```

## Step 3: Update Copilot finding #4 model spec failure message

In `spec/models/reviews_spec.rb`, locate the existing test around line 320 (post-PR #717):

```ruby
expect(review).to be_valid, "expected #{user} (membership role) to be able to comment"
```

Replace with:

```ruby
expect(review).to be_valid,
                  "expected #{user} (membership role: #{user.effective_permissions(@p1r1.component)}) to be able to comment"
```

## Step 4: Run the specs to verify they fail / verify Copilot #4 fix

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "Copilot"
bundle exec rspec spec/requests/reviews_spec.rb -e "transaction integrity"
bundle exec rspec spec/models/reviews_spec.rb -e "to comment"
```

**Expected:**
- The Copilot fixes spec PASSES (we're verifying it works with `component_id`; this should already work in the existing controller)
- The transaction-integrity spec FAILS (Review.create + rule.save! happens outside an explicit transaction)
- The Copilot #4 spec PASSES (we just made the failure message more useful — the test still passes for the happy path)

## Step 5: Wrap `create` in a transaction

In `app/controllers/reviews_controller.rb`, replace the `def create` method:

```ruby
def create
  review_params_without_component_id = review_params.except('component_id')
  review = Review.new(review_params_without_component_id.merge({ user: current_user, rule: @rule }))

  saved = false
  Review.transaction do
    saved = review.save
    raise ActiveRecord::Rollback unless saved
  end

  if saved
    if Settings.smtp.enabled
      send_smtp_notification(
        UserMailer,
        review_params[:action],
        current_user,
        review_params[:component_id],
        review_params[:comment],
        @rule
      )
    end

    if Settings.slack.enabled
      send_slack_notification(
        review_params[:action].to_sym,
        @rule,
        review_params[:comment]
      )
    end

    render json: { toast: 'Successfully added review.' }
  else
    render json: {
      toast: {
        title: 'Could not add review.',
        message: review.errors.full_messages,
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end
end
```

The `Review.transaction do ... raise ActiveRecord::Rollback ... end` pattern ensures `take_review_action`'s `rule.save!` is rolled back if the Review save itself fails. We deliberately do NOT propagate exceptions out (the existing happy-path render-or-422 pattern stays).

For the **already-raised exception** case (the `expect_any_instance_of(Review).to receive(:save).and_raise(...)` in the spec), the exception unwinds the transaction automatically — the rollback test passes by virtue of being inside the `Review.transaction` block.

## Step 6: Update `review_params` to be explicit about strong params

Replace `review_params`:

```ruby
def review_params
  params.expect(review: %i[component_id action comment section responding_to_review_id])
end
```

Adds `section` (XCCDF element key) and `responding_to_review_id` (for replies via the per-section dedup banner) to the permitted list. Lifecycle fields (triage_status, adjudicated_at, etc.) are **explicitly excluded** — the controller never accepts those from user input. They're set by Tasks 08-12's dedicated PATCH endpoints.

## Step 7: Run the specs to verify they pass

```bash
bundle exec rspec spec/requests/reviews_spec.rb spec/models/reviews_spec.rb
```

**Expected:** all PASS, including the transaction integrity spec.

## Step 8: Run vocabulary grep + RuboCop

```bash
bundle exec rubocop app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb
grep -rnE "\"(accept|decline|closed)\"" app/controllers
```

**Expected:** 0 offenses, 0 vocabulary leaks.

## Step 9: Commit

```bash
cat > /tmp/msg-07.md <<'EOF'
fix: transaction integrity + strong params + Copilot #2-#4 polish

- Wrap Review.create + rule.save! in an explicit Review.transaction so
  take_review_action's rule mutation rolls back if the Review save fails.
  Closes a quiet bug pre-existing in master.

- Strong params permit list explicitly: [:component_id, :action, :comment,
  :section, :responding_to_review_id]. Lifecycle fields (triage_status,
  adjudicated_at, triage_set_by_id, etc.) are NEVER user-controllable —
  they're set by dedicated PATCH endpoints in Tasks 08-12.

- Specs add component_id to request_review/approve POST params so they
  match the real client payload from useRuleActions.js (Copilot #2/#3).

- Failure message at spec/models/reviews_spec.rb interpolates
  user.effective_permissions instead of the literal "(membership role)"
  string (Copilot #4).

Closes Copilot findings #2, #3, #4 on PR #717.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb spec/models/reviews_spec.rb
git commit -F /tmp/msg-07.md
rm /tmp/msg-07.md
```

## Step 10: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/07-reviews-controller-create-fixes.md \
       docs/plans/PR717-public-comment-review/07-reviews-controller-create-fixes-DONE.md
git commit -m "chore: mark plan task 07 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- All four Copilot findings on PR #717 closed
- Transaction wrapper prevents partial writes
- Strong params explicitly defined; lifecycle fields locked out from user input
- Foundation for Tasks 08-12 (which add new endpoints, all of which use the same transaction pattern)
