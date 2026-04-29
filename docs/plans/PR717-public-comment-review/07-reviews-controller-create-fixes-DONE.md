# Task 07: Reviews controller transaction discipline + strong-params extension

**Depends on:** 02, 04
**Unblocks:** 10
**Estimate:** 15 min Claude-pace
**File touches:**
- `app/controllers/reviews_controller.rb` (transaction wrap on create + extend strong params)
- `spec/requests/reviews_spec.rb`

**Scope note (post-Will's `71726fa`):** the original Task 07 was meant to close Copilot #2, #3, #4. Will's commit `71726fa` already did that — added `component_id` to the request specs and interpolated the role in the failure message. **The only remaining work in this task is:**

1. Wrap `Review.create` + `take_review_action`'s `rule.save!` in an explicit `Review.transaction` so a Review save failure rolls back the rule mutation. This was a quiet bug in master pre-existing the PR.
2. Extend `review_params` to permit `:section` and `:responding_to_review_id` (the new columns added by Task 05). Lifecycle fields (`triage_status`, `triage_set_by_id`, `adjudicated_at`, `adjudicated_by_id`, `duplicate_of_review_id`) are NEVER user-controllable — they're set by Tasks 10/11/12's dedicated PATCH endpoints.

---

## Step 1: Read the existing create-action

Confirm current state:

```bash
grep -n "def create" app/controllers/reviews_controller.rb
grep -n "review_params" app/controllers/reviews_controller.rb
```

You should see `def create` ~line 14 and `review_params` returning `params.expect(review: %i[component_id action comment])`.

The Copilot #2/#3/#4 spec polish (component_id in request specs + interpolated role in failure message) was **already done by Will's `71726fa`**. This task only adds the transaction wrap and extends `review_params` for the new lifecycle columns.

## Step 2: Write the failing request spec for transaction integrity

Append to `spec/requests/reviews_spec.rb`, inside the existing `RSpec.describe 'Reviews'`:

```ruby
describe 'POST /rules/:rule_id/reviews — transaction integrity' do
  let_it_be(:author_user) { create(:user) }
  before do
    create(:membership, user: author_user, membership: project, role: 'author') unless
      Membership.exists?(user: author_user, membership: project)
    sign_in author_user
  end

  it 'rolls back rule mutation when Review save fails' do
    # Force a Review save failure AFTER take_review_action would have run.
    # Rails runs validations BEFORE before_create, so a validation failure
    # would short-circuit too early. We need a post-validation failure to
    # exercise the bug — stub :save to raise StatementInvalid.
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

## Step 3: Run the spec to verify it FAILS (red)

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "transaction integrity"
```

**Expected:** FAILS — `take_review_action`'s `rule.save!` runs BEFORE the Review insert, mutating the rule. Without a transaction wrap, the mutation persists despite the Review save failure.

If the spec passes immediately, STOP — the bug may already be fixed by an unrelated change since this plan was written.

## Step 4: Wrap `create` in a transaction

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

## Step 5: Update `review_params` to be explicit about strong params

Replace `review_params`:

```ruby
def review_params
  params.expect(review: %i[component_id action comment section responding_to_review_id])
end
```

Adds `section` (XCCDF element key) and `responding_to_review_id` (for replies via the per-section dedup banner) to the permitted list. Lifecycle fields (triage_status, adjudicated_at, etc.) are **explicitly excluded** — the controller never accepts those from user input. They're set by Tasks 08-12's dedicated PATCH endpoints.

## Step 6: Run the specs to verify they pass

```bash
bundle exec rspec spec/requests/reviews_spec.rb spec/models/reviews_spec.rb
```

**Expected:** all PASS, including the transaction integrity spec.

## Step 7: Run vocabulary grep + RuboCop

```bash
bundle exec rubocop app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb
grep -rnE "\"(accept|decline|closed)\"" app/controllers
```

**Expected:** 0 offenses, 0 vocabulary leaks.

## Step 8: Commit

```bash
cat > /tmp/msg-07.md <<'EOF'
fix: transaction integrity on review create + strong-params extension

- Wrap Review.create + rule.save! in an explicit Review.transaction so
  take_review_action's rule mutation rolls back if the Review save fails.
  Closes a quiet bug pre-existing in master where a post-validation
  failure on Review.save left the rule already mutated by the
  before_create callback.

- Extend strong-params permit list to [:component_id, :action, :comment,
  :section, :responding_to_review_id]. The new :section (XCCDF element
  key) and :responding_to_review_id (for thread replies) are user-
  controllable. Lifecycle fields (triage_status, triage_set_by_id,
  triage_set_at, adjudicated_at, adjudicated_by_id, duplicate_of_review_id)
  are explicitly NOT permitted — they're set only by the dedicated PATCH
  endpoints in Tasks 10/11/12.

(Copilot #2/#3/#4 were already addressed by Will's 71726fa; not
re-done here.)

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb
git commit -F /tmp/msg-07.md
rm /tmp/msg-07.md
```

## Step 9: Mark done

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
