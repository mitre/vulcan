# Task 09: PATCH /reviews/:id/adjudicate endpoint

**Depends on:** 08
**Unblocks:** 15
**Estimate:** 20 min Claude-pace
**File touches:**
- `config/routes.rb`
- `app/controllers/reviews_controller.rb`
- `spec/requests/reviews_spec.rb`

Mirrors Task 08's pattern. Author+ marks an already-triaged comment as adjudicated (closed). Idempotent re-adjudicate is a no-op.

---

## Step 1: Write the failing spec

Append to `spec/requests/reviews_spec.rb`:

```ruby
describe 'PATCH /reviews/:id/adjudicate' do
  let_it_be(:author_user) { create(:user) }
  let_it_be(:viewer_user) { create(:user) }

  before do
    create(:membership, user: author_user, membership: project, role: 'author') unless
      Membership.exists?(user: author_user, membership: project)
    create(:membership, user: viewer_user, membership: project, role: 'viewer') unless
      Membership.exists?(user: viewer_user, membership: project)
  end

  let!(:triaged_comment) {
    sign_in viewer_user
    post "/rules/#{rule.id}/reviews",
         params: { review: { action: 'comment', comment: 'check issue', section: 'check_content', component_id: component.id } },
         as: :json
    review = Review.last
    sign_out viewer_user

    sign_in author_user
    patch "/reviews/#{review.id}/triage", params: {
      triage_status: 'concur_with_comment', response_comment: 'Will adopt'
    }, as: :json
    review.reload
  }

  context 'as an author' do
    it 'sets adjudicated_at and adjudicated_by_id' do
      patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json

      expect(response).to have_http_status(:ok)
      triaged_comment.reload
      expect(triaged_comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
      expect(triaged_comment.adjudicated_by_id).to eq(author_user.id)
    end

    it 'creates a final response Review when resolution_comment is supplied' do
      expect {
        patch "/reviews/#{triaged_comment.id}/adjudicate",
              params: { resolution_comment: 'Updated rule in commit abc123' },
              as: :json
      }.to change(Review, :count).by(1)

      response_review = Review.find_by(responding_to_review_id: triaged_comment.id, comment: 'Updated rule in commit abc123')
      expect(response_review).to be_present
      expect(response_review.user_id).to eq(author_user.id)
      expect(response_review.section).to eq(triaged_comment.section)  # inherited
    end

    it 'is idempotent on re-adjudicate (no-op, returns 200)' do
      patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
      original_at = triaged_comment.reload.adjudicated_at

      sleep 0.1
      patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
      expect(response).to have_http_status(:ok)
      expect(triaged_comment.reload.adjudicated_at).to eq(original_at)  # unchanged
    end

    it 'rejects adjudicating a still-pending comment' do
      pending_comment = Review.create!(action: 'comment', comment: 'still pending', user: viewer_user, rule: rule)
      patch "/reviews/#{pending_comment.id}/adjudicate", params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message').join).to match(/triaged before/i)
      expect(pending_comment.reload.adjudicated_at).to be_nil
    end
  end

  context 'as a viewer' do
    before { sign_in viewer_user }

    it 'returns 403' do
      patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

## Step 2: Run the spec to verify it fails

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "adjudicate"
```

**Expected:** all FAIL with route-not-found.

## Step 3: Add the route

In `config/routes.rb`, mirror the triage route:

```ruby
patch '/reviews/:id/adjudicate', to: 'reviews#adjudicate'
```

(Or member action if using `resources :reviews` block.)

## Step 4: Add the controller action

In `app/controllers/reviews_controller.rb`, add to the `before_action :authorize_author_project` line:

```ruby
before_action :authorize_author_project, only: %i[triage adjudicate]
```

(Already there from Task 08 if you used the `%i[triage adjudicate]` array.)

Add the action body after `def triage`:

```ruby
def adjudicate
  # Idempotent: re-adjudicate is a no-op
  if @review.adjudicated_at.present?
    return render json: { review: ReviewBlueprint.render_as_hash(@review), response_review: nil }
  end

  # Cannot adjudicate a still-pending comment — must triage first
  if @review.triage_status == 'pending'
    return render json: { toast: { title: 'Cannot close yet.', message: ['Comment must be triaged before it can be closed.'], variant: 'warning' } },
                  status: :unprocessable_entity
  end

  Review.transaction do
    @review.update!(adjudicated_at: Time.current, adjudicated_by_id: current_user.id)

    response_review = nil
    if params[:resolution_comment].present?
      response_review = Review.create!(
        action: 'comment',
        comment: params[:resolution_comment],
        user: current_user,
        rule: @review.rule,
        responding_to_review_id: @review.id,
        section: @review.section
      )
    end

    render json: {
      review: ReviewBlueprint.render_as_hash(@review),
      response_review: response_review ? ReviewBlueprint.render_as_hash(response_review) : nil
    }
  end
rescue ActiveRecord::RecordInvalid => e
  render json: { toast: { title: 'Could not close.', message: e.record.errors.full_messages, variant: 'danger' } },
         status: :unprocessable_entity
end
```

## Step 5: Run the spec to verify it passes

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "adjudicate"
```

**Expected:** all PASS.

## Step 6: Run impacted suite + RuboCop

```bash
bundle exec rspec spec/requests/reviews_spec.rb
bundle exec rubocop app/controllers/reviews_controller.rb config/routes.rb spec/requests/reviews_spec.rb
```

## Step 7: Commit

```bash
cat > /tmp/msg-09.md <<'EOF'
feat: PATCH /reviews/:id/adjudicate endpoint

Sets adjudicated_at + adjudicated_by_id on a triaged comment Review.
Idempotent: re-adjudicate is a no-op returning current state.
Rejects adjudicating a still-pending comment (must triage first).

If resolution_comment is supplied, creates a child Review with
responding_to_review_id + inherited section so the response appears in
the rule's existing thread.

Author+ via the same IDOR-safe filter chain as Task 08.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/routes.rb app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb
git commit -F /tmp/msg-09.md
rm /tmp/msg-09.md
```

## Step 8: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/09-reviews-controller-adjudicate-endpoint.md \
       docs/plans/PR717-public-comment-review/09-reviews-controller-adjudicate-endpoint-DONE.md
git commit -m "chore: mark plan task 09 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
