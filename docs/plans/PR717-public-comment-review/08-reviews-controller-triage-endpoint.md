# Task 08: PATCH /reviews/:id/triage endpoint

**Depends on:** 03, 05, 06, 07
**Unblocks:** 09, 15
**Estimate:** 30 min Claude-pace
**File touches:**
- `config/routes.rb` (new route)
- `app/controllers/reviews_controller.rb` (new `triage` action + IDOR-safe filters)
- `spec/requests/reviews_spec.rb`

Adds the triage endpoint per design §3.5. Uses an explicit `set_review` → `set_project_from_review` → `authorize_author_project` chain so cross-project IDOR is blocked.

---

## Step 1: Write the failing request spec

Append to `spec/requests/reviews_spec.rb`:

```ruby
describe 'PATCH /reviews/:id/triage' do
  let_it_be(:author_user) { create(:user) }
  let_it_be(:viewer_user) { create(:user) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_component) { create(:component, project: other_project, based_on: srg) }
  let(:other_rule) { other_component.rules.first }

  before do
    create(:membership, user: author_user, membership: project, role: 'author') unless
      Membership.exists?(user: author_user, membership: project)
    create(:membership, user: viewer_user, membership: project, role: 'viewer') unless
      Membership.exists?(user: viewer_user, membership: project)
  end

  let!(:comment) {
    sign_in viewer_user
    post "/rules/#{rule.id}/reviews",
         params: { review: { action: 'comment', comment: 'check text issue', section: 'check_content', component_id: component.id } },
         as: :json
    Review.last
  }

  context 'as an author' do
    before do
      sign_out viewer_user
      sign_in author_user
    end

    it 'sets triage_status and creates response Review' do
      patch "/reviews/#{comment.id}/triage", params: {
        triage_status: 'concur_with_comment',
        response_comment: "Thanks — we'll adopt with stricter regex.",
      }, as: :json

      expect(response).to have_http_status(:ok)
      comment.reload
      expect(comment.triage_status).to eq('concur_with_comment')
      expect(comment.triage_set_by_id).to eq(author_user.id)
      expect(comment.triage_set_at).to be_within(5.seconds).of(Time.current)

      response_review = Review.find_by(responding_to_review_id: comment.id)
      expect(response_review).to be_present
      expect(response_review.action).to eq('comment')
      expect(response_review.section).to eq('check_content') # inherited
      expect(response_review.user_id).to eq(author_user.id)
      expect(response_review.comment).to match(/stricter regex/)
    end

    it 'rejects triage_status non_concur without response_comment (validation error)' do
      patch "/reviews/#{comment.id}/triage", params: {
        triage_status: 'non_concur',
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message').join).to match(/decline requires a response/i)
      expect(comment.reload.triage_status).to eq('pending') # unchanged
    end

    it 'requires duplicate_of_review_id when triage_status is duplicate' do
      patch "/reviews/#{comment.id}/triage", params: {
        triage_status: 'duplicate',
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message').join).to match(/canonical comment/i)
    end

    it 'allows informational without response_comment + auto-sets adjudicated_at' do
      patch "/reviews/#{comment.id}/triage", params: {
        triage_status: 'informational',
      }, as: :json

      expect(response).to have_http_status(:ok)
      comment.reload
      expect(comment.triage_status).to eq('informational')
      expect(comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
    end

    it 'is idempotent on re-triage (overwrites + audits)' do
      patch "/reviews/#{comment.id}/triage", params: { triage_status: 'concur', response_comment: 'first call' }, as: :json
      expect(comment.reload.triage_status).to eq('concur')

      patch "/reviews/#{comment.id}/triage", params: { triage_status: 'non_concur', response_comment: 'changed our mind' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(comment.reload.triage_status).to eq('non_concur')
      # Audit captures both changes
      expect(comment.audits.where("audited_changes->>'triage_status' IS NOT NULL").count).to be >= 2
    end
  end

  context 'IDOR — author of project A cannot triage Review in project B' do
    before do
      sign_in author_user # author of `project`, NOT `other_project`
    end

    let!(:other_comment) {
      Review.create!(action: 'comment', comment: 'in other project', user: create(:user), rule: other_rule)
    }

    it 'returns 403 with structured permission denied' do
      patch "/reviews/#{other_comment.id}/triage", params: { triage_status: 'concur' }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to eq('permission_denied')
    end
  end

  context 'as a viewer (not authorized to triage)' do
    before do
      sign_in viewer_user
    end

    it 'returns 403' do
      patch "/reviews/#{comment.id}/triage", params: { triage_status: 'concur' }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(comment.reload.triage_status).to eq('pending')
    end
  end
end
```

## Step 2: Run the spec to verify it fails

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "triage"
```

**Expected:** all FAIL with route-not-found errors.

## Step 3: Add the route

In `config/routes.rb`, locate the existing `resources :reviews` (or whatever pattern reviews uses; check for `post 'reviews'` etc.). Add a flat custom route matching the existing pattern:

```ruby
patch '/reviews/:id/triage', to: 'reviews#triage'
```

If reviews are under a `resources :reviews` block, add as a member action:

```ruby
resources :reviews, only: [...] do
  member do
    patch :triage
  end
end
```

Inspect `routes.rb` to match the existing convention. The flat pattern matches `routes.rb:67-90`'s style for components.

## Step 4: Add the controller action with IDOR-safe filter chain

In `app/controllers/reviews_controller.rb`, add to the `before_action` declarations near the top:

```ruby
before_action :set_review,             only: %i[triage adjudicate withdraw update]
before_action :set_project_from_review, only: %i[triage adjudicate update]
before_action :authorize_author_project, only: %i[triage adjudicate]
```

Add the action body:

```ruby
def triage
  return render_terminal_status_error if Review::TERMINAL_AUTO_ADJUDICATE_STATUSES.exclude?(params[:triage_status]) &&
                                          @review.adjudicated_at.present?

  validation_error = validate_triage_params
  return render json: { toast: { title: 'Could not save triage.', message: [validation_error], variant: 'danger' } },
                status: :unprocessable_entity if validation_error

  Review.transaction do
    @review.assign_attributes(
      triage_status: params[:triage_status],
      triage_set_by_id: current_user.id,
      triage_set_at: Time.current,
      duplicate_of_review_id: params[:duplicate_of_review_id]
    )
    @review.save!

    response_review = nil
    if params[:response_comment].present?
      response_review = Review.create!(
        action: 'comment',
        comment: params[:response_comment],
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
  render json: { toast: { title: 'Could not save triage.', message: e.record.errors.full_messages, variant: 'danger' } },
         status: :unprocessable_entity
end
```

Add the private helper methods:

```ruby
def set_review
  @review = Review.find(params[:id])
rescue ActiveRecord::RecordNotFound
  head :not_found
end

def set_project_from_review
  return unless @review
  @project = @review.rule&.component&.project
end

def validate_triage_params
  status = params[:triage_status]
  return I18n.t('vulcan.triage.errors.cannot_edit_after_triage') unless Review::TRIAGE_STATUSES.include?(status)

  if status == 'non_concur' && params[:response_comment].blank?
    return I18n.t('vulcan.triage.errors.decline_requires_response')
  end

  if status == 'duplicate' && params[:duplicate_of_review_id].blank?
    return I18n.t('vulcan.triage.errors.duplicate_requires_target')
  end

  nil
end

def render_terminal_status_error
  render json: { toast: { title: 'Cannot re-triage.', message: ['This comment is already closed.'], variant: 'warning' } },
         status: :unprocessable_entity
end
```

## Step 5: Run the spec to verify it passes

```bash
bundle exec rspec spec/requests/reviews_spec.rb -e "triage"
```

**Expected:** all 7 examples PASS.

## Step 6: Run RuboCop + vocabulary checks

```bash
bundle exec rubocop app/controllers/reviews_controller.rb config/routes.rb spec/requests/reviews_spec.rb
grep -rnE "\"(accept|decline|closed)\"" app/controllers
```

**Expected:** 0 offenses, 0 vocab leaks (DISA-native everywhere on the wire).

## Step 7: Run the full reviews spec suite to confirm no regressions

```bash
bundle exec rspec spec/requests/reviews_spec.rb spec/models/reviews_spec.rb
```

**Expected:** all PASS.

## Step 8: Commit

```bash
cat > /tmp/msg-08.md <<'EOF'
feat: PATCH /reviews/:id/triage endpoint

Implements the triage endpoint described in DESIGN §3.5. Author+ updates
a top-level comment Review's triage_status + triage_set_by_id +
triage_set_at; if response_comment is supplied, atomically creates a
child Review (action='comment', responding_to_review_id, inherited
section) so the response shows in the rule's existing thread.

IDOR protection via explicit set_review → set_project_from_review →
authorize_author_project chain. Cross-project triage attempts return 403
(structured permission_denied body), not 404.

Validation:
- triage_status must be in TRIAGE_STATUSES
- non_concur requires response_comment ("Decline requires a response —
  explain why so the commenter understands.")
- duplicate requires duplicate_of_review_id
- terminal statuses (duplicate / informational / withdrawn) auto-set
  adjudicated_at via the model callback from Task 05

Idempotent re-triage allowed; audited gem captures prior state via the
config from Task 05.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/routes.rb app/controllers/reviews_controller.rb spec/requests/reviews_spec.rb
git commit -F /tmp/msg-08.md
rm /tmp/msg-08.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/08-reviews-controller-triage-endpoint.md \
       docs/plans/PR717-public-comment-review/08-reviews-controller-triage-endpoint-DONE.md
git commit -m "chore: mark plan task 08 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- `PATCH /reviews/:id/triage` accepts triage decisions, creates response Reviews when text is supplied
- IDOR-blocked filter chain pattern established for Tasks 09, 10
- Decline-requires-response validation enforced
- Auto-adjudicate for terminal statuses works end-to-end
- Audit trail captures triage transitions
