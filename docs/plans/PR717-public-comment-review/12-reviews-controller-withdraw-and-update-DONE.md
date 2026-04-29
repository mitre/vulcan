# Task 12: PATCH /reviews/:id/withdraw + PUT /reviews/:id (commenter-only edit)

**Depends on:** 04, 06
**Unblocks:** 20
**Estimate:** 30 min Claude-pace
**File touches:**
- `config/routes.rb`
- `app/controllers/reviews_controller.rb`
- `spec/requests/reviews_spec.rb`

Two commenter-self-service endpoints: withdraw your own pending comment, edit your own pending comment. Both check ownership; neither requires author+.

---

## Step 1: Write the failing spec

Append to `spec/requests/reviews_spec.rb`:

```ruby
describe 'PATCH /reviews/:id/withdraw' do
  let_it_be(:viewer_user) { create(:user) }
  let_it_be(:other_viewer) { create(:user) }
  before do
    create(:membership, user: viewer_user, membership: project, role: 'viewer') unless
      Membership.exists?(user: viewer_user, membership: project)
    create(:membership, user: other_viewer, membership: project, role: 'viewer') unless
      Membership.exists?(user: other_viewer, membership: project)
  end

  let!(:my_comment) {
    sign_in viewer_user
    post "/rules/#{rule.id}/reviews",
         params: { review: { action: 'comment', comment: 'my idea', component_id: component.id } },
         as: :json
    Review.last
  }

  context 'as the original commenter, comment is pending' do
    it 'sets triage_status=withdrawn + auto-sets adjudicated_at + adjudicated_by_id=self' do
      patch "/reviews/#{my_comment.id}/withdraw", as: :json
      expect(response).to have_http_status(:ok)
      my_comment.reload
      expect(my_comment.triage_status).to eq('withdrawn')
      expect(my_comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
      expect(my_comment.adjudicated_by_id).to eq(viewer_user.id) # commenter is the adjudicator on withdraw
    end
  end

  context 'as a different user (not the original commenter)' do
    before do
      sign_out viewer_user
      sign_in other_viewer
    end

    it 'returns 403' do
      patch "/reviews/#{my_comment.id}/withdraw", as: :json
      expect(response).to have_http_status(:forbidden)
      expect(my_comment.reload.triage_status).to eq('pending')
    end
  end

  context 'when comment is already triaged' do
    before do
      author = create(:user)
      create(:membership, user: author, membership: project, role: 'author')
      sign_out viewer_user
      sign_in author
      patch "/reviews/#{my_comment.id}/triage", params: { triage_status: 'concur', response_comment: 'thanks' }, as: :json
      sign_out author
      sign_in viewer_user
    end

    it 'rejects withdraw on a triaged comment' do
      patch "/reviews/#{my_comment.id}/withdraw", as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(my_comment.reload.triage_status).to eq('concur')
    end
  end
end

describe 'PUT /reviews/:id (commenter edit own pending comment)' do
  let_it_be(:viewer_user) { create(:user) }
  before do
    create(:membership, user: viewer_user, membership: project, role: 'viewer') unless
      Membership.exists?(user: viewer_user, membership: project)
  end

  let!(:my_comment) {
    sign_in viewer_user
    post "/rules/#{rule.id}/reviews",
         params: { review: { action: 'comment', comment: 'original text', component_id: component.id } },
         as: :json
    Review.last
  }

  it 'updates the comment text while pending' do
    put "/reviews/#{my_comment.id}", params: { review: { comment: 'edited text' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(my_comment.reload.comment).to eq('edited text')
  end

  it 'audits the edit' do
    expect {
      put "/reviews/#{my_comment.id}", params: { review: { comment: 'edited' } }, as: :json
    }.to change(my_comment.audits, :count).by(1)
  end

  it 'rejects edit by a different user' do
    other = create(:user)
    create(:membership, user: other, membership: project, role: 'viewer')
    sign_out viewer_user
    sign_in other

    put "/reviews/#{my_comment.id}", params: { review: { comment: 'sneaky edit' } }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(my_comment.reload.comment).to eq('original text')
  end

  it 'rejects edit after comment has been triaged' do
    author = create(:user)
    create(:membership, user: author, membership: project, role: 'author')
    sign_out viewer_user
    sign_in author
    patch "/reviews/#{my_comment.id}/triage", params: { triage_status: 'concur', response_comment: 'thanks' }, as: :json
    sign_out author
    sign_in viewer_user

    put "/reviews/#{my_comment.id}", params: { review: { comment: 'too late' } }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(my_comment.reload.comment).to eq('original text')
  end
end
```

## Step 2: Run the spec to verify it fails

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "withdraw"
bundle exec rspec spec/requests/reviews_spec.rb -e "commenter edit"
```

**Expected:** all FAIL with route-not-found.

## Step 3: Add routes

In `config/routes.rb`:

```ruby
patch '/reviews/:id/withdraw', to: 'reviews#withdraw'
put   '/reviews/:id',          to: 'reviews#update'
```

## Step 4: Add filter for ownership-based actions

In `app/controllers/reviews_controller.rb`:

```ruby
before_action :set_review,                  only: %i[triage adjudicate withdraw update]
before_action :set_project_from_review,     only: %i[triage adjudicate update]
before_action :authorize_author_project,    only: %i[triage adjudicate]
before_action :authorize_review_owner,      only: %i[withdraw update]
```

## Step 5: Add the controller actions

After `def adjudicate`:

```ruby
def withdraw
  unless %w[pending needs_clarification].include?(@review.triage_status)
    return render json: { toast: { title: 'Cannot withdraw.',
                                    message: [I18n.t('vulcan.triage.errors.cannot_withdraw_already_triaged')],
                                    variant: 'warning' } },
                  status: :unprocessable_entity
  end

  @review.update!(triage_status: 'withdrawn')
  # auto_set_adjudicated_for_terminal_statuses callback handles adjudicated_at/by from Task 06

  render json: { review: ReviewBlueprint.render_as_hash(@review) }
rescue ActiveRecord::RecordInvalid => e
  render json: { toast: { title: 'Could not withdraw.', message: e.record.errors.full_messages, variant: 'danger' } },
         status: :unprocessable_entity
end

def update
  unless @review.triage_status == 'pending'
    return render json: { toast: { title: 'Cannot edit.',
                                    message: [I18n.t('vulcan.triage.errors.cannot_edit_after_triage')],
                                    variant: 'warning' } },
                  status: :unprocessable_entity
  end

  @review.update!(review_update_params)
  render json: { review: ReviewBlueprint.render_as_hash(@review) }
rescue ActiveRecord::RecordInvalid => e
  render json: { toast: { title: 'Could not save edit.', message: e.record.errors.full_messages, variant: 'danger' } },
         status: :unprocessable_entity
end
```

Add the helpers (private):

```ruby
def authorize_review_owner
  return if @review && @review.user_id == current_user&.id
  raise NotAuthorizedError
end

def review_update_params
  params.require(:review).permit(:comment)
end
```

The `authorize_review_owner` filter raises `NotAuthorizedError`, which the existing `rescue_from` from PR #717 catches and renders the structured 403 — same UX as other denial paths.

## Step 6: Run specs to verify they pass

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "withdraw"
bundle exec rspec spec/requests/reviews_spec.rb -e "commenter edit"
```

**Expected:** all PASS.

## Step 7: Lint + full suite

```bash
bundle exec rubocop app/controllers/reviews_controller.rb config/routes.rb spec/requests/reviews_spec.rb
bundle exec rspec spec/requests/reviews_spec.rb
```

## Step 8: Commit

```bash
cat > /tmp/msg-10.md <<'EOF'
feat: PATCH /reviews/:id/withdraw + PUT /reviews/:id (commenter self-service)

Two commenter-only endpoints, both gated by authorize_review_owner
(current_user.id == review.user_id):

- PATCH /reviews/:id/withdraw — sets triage_status='withdrawn'; the
  auto_set_adjudicated_for_terminal_statuses model callback (Task 06)
  fills in adjudicated_at + adjudicated_by_id (= the commenter
  themselves). Allowed only when triage_status is 'pending' or
  'needs_clarification'. Rejected once a triager has acted.

- PUT /reviews/:id — edit own comment text. Allowed only while
  triage_status='pending'. Audited gem (Task 06) captures the prior text
  for the tamper-evident trail.

Both back the "My Comments" page actions in Task 20.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/routes.rb app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb
git commit -F /tmp/msg-10.md
rm /tmp/msg-10.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/10-reviews-controller-withdraw-and-update.md \
       docs/plans/PR717-public-comment-review/10-reviews-controller-withdraw-and-update-DONE.md
git commit -m "chore: mark plan task 10 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
