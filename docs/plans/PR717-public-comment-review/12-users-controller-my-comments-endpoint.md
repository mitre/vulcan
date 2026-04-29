# Task 12: GET /users/:id/comments (My Comments page backing endpoint)

**Depends on:** 03, 05
**Unblocks:** 20
**Estimate:** 20 min Claude-pace
**File touches:**
- `config/routes.rb`
- `app/controllers/users_controller.rb` (or equivalent)
- `spec/requests/users_spec.rb`

Backs the "My Comments" page (§2.9). Always scoped to `current_user` (no admin override — privacy).

---

## Step 1: Locate users controller

```bash
ls app/controllers/users_controller.rb || find app/controllers -name "*user*"
```

If no `users_controller.rb` exists, check what handles `/users/:id` routes:

```bash
grep -n "users" config/routes.rb | head
```

Vulcan has Devise but typically also a `UsersController` for admin/profile views. If absent, create one.

## Step 2: Write the failing spec

Create or extend `spec/requests/users_spec.rb`:

```ruby
RSpec.describe 'GET /users/:id/comments', type: :request do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_component) { create(:component, project: other_project, based_on: srg) }

  let_it_be(:viewer) { create(:user) }
  let_it_be(:other_viewer) { create(:user) }

  before_all do
    create(:membership, user: viewer, membership: project, role: 'viewer')
    create(:membership, user: viewer, membership: other_project, role: 'viewer')
    create(:membership, user: other_viewer, membership: project, role: 'viewer')
  end

  before { Rails.application.reload_routes! }

  let!(:my_c1) { Review.create!(action: 'comment', comment: 'one', user: viewer, rule: component.rules.first, section: 'check_content') }
  let!(:my_c2) { Review.create!(action: 'comment', comment: 'two', user: viewer, rule: other_component.rules.first, section: nil) }
  let!(:other_users_c) { Review.create!(action: 'comment', comment: 'theirs', user: other_viewer, rule: component.rules.first) }
  let!(:my_reply) { Review.create!(action: 'comment', comment: 'reply', user: viewer, rule: component.rules.first, responding_to_review_id: other_users_c.id) }

  context 'as viewer requesting own comments' do
    before { sign_in viewer }

    it 'returns viewer top-level comments across all accessible projects' do
      get "/users/#{viewer.id}/comments", as: :json
      expect(response).to have_http_status(:success)
      ids = response.parsed_body['rows'].map { |r| r['id'] }
      expect(ids).to include(my_c1.id, my_c2.id)
      expect(ids).not_to include(other_users_c.id, my_reply.id)
    end

    it 'returns DISA-native triage_status + XCCDF section keys' do
      get "/users/#{viewer.id}/comments", as: :json
      first_row = response.parsed_body['rows'].find { |r| r['id'] == my_c1.id }
      expect(first_row['triage_status']).to eq('pending')
      expect(first_row['section']).to eq('check_content')
    end

    it 'filters by triage_status' do
      my_c1.update!(triage_status: 'concur', triage_set_by_id: anchor_admin.id, triage_set_at: Time.current)
      get "/users/#{viewer.id}/comments", params: { triage_status: 'concur' }, as: :json
      expect(response.parsed_body['rows'].size).to eq(1)
    end
  end

  context 'as a different user requesting another user\'s comments' do
    before { sign_in other_viewer }

    it 'returns 403 — privacy: no admin override' do
      get "/users/#{viewer.id}/comments", as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'as admin requesting another user\'s comments' do
    before { sign_in anchor_admin }

    it 'returns 403 — privacy is absolute' do
      get "/users/#{viewer.id}/comments", as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'unauthenticated' do
    it 'redirects to sign-in' do
      get "/users/#{viewer.id}/comments", as: :json
      expect(response.status).to be_in([302, 401])
    end
  end
end
```

## Step 3: Run spec to verify failure

```bash
bundle exec rspec spec/requests/users_spec.rb -e "/users/:id/comments"
```

**Expected:** FAIL with route-not-found.

## Step 4: Add route

In `config/routes.rb`:

```ruby
get '/users/:id/comments', to: 'users#comments'
```

## Step 5: Add controller action

In `app/controllers/users_controller.rb` (create if needed):

```ruby
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_self, only: %i[comments]

  def comments
    page = [params[:page].to_i, 1].max
    per_page = [[params[:per_page].to_i, 1].max, 100].min

    scope = Review.top_level_comments.where(user_id: current_user.id)
                  .includes(rule: { component: :project })

    scope = scope.where(triage_status: params[:triage_status]) if params[:triage_status].present? && params[:triage_status] != 'all'
    scope = scope.joins(rule: :component).where(components: { project_id: params[:project_id] }) if params[:project_id].present?

    total = scope.count

    rows = scope.order(created_at: :desc)
                .offset((page - 1) * per_page)
                .limit(per_page)
                .map do |r|
                  rule = r.rule
                  component = rule.component
                  project = component.project
                  {
                    id: r.id,
                    project_id: project.id,
                    project_name: project.name,
                    component_id: component.id,
                    component_name: component.name,
                    rule_id: rule.id,
                    rule_displayed_name: "#{component.prefix}-#{rule.rule_id}",
                    section: r.section,
                    comment: r.comment,
                    created_at: r.created_at,
                    triage_status: r.triage_status,
                    triage_set_at: r.triage_set_at,
                    adjudicated_at: r.adjudicated_at,
                    latest_activity_at: [r.triage_set_at, r.adjudicated_at, r.responses.maximum(:created_at)].compact.max
                  }
                end

    render json: {
      rows: rows,
      pagination: { page: page, per_page: per_page, total: total }
    }
  end

  private

  def authorize_self
    raise NotAuthorizedError unless current_user&.id == params[:id].to_i
  end
end
```

## Step 6: Run spec to verify pass

```bash
bundle exec rspec spec/requests/users_spec.rb -e "/users/:id/comments"
```

**Expected:** all PASS.

## Step 7: RuboCop + full impacted suite

```bash
bundle exec rubocop app/controllers/users_controller.rb config/routes.rb spec/requests/users_spec.rb
bundle exec rspec spec/requests/users_spec.rb
```

## Step 8: Commit

```bash
cat > /tmp/msg-12.md <<'EOF'
feat: GET /users/:id/comments — backing endpoint for "My Comments" page

Returns the current user's top-level comment Reviews across all accessible
projects. Privacy is absolute: only the user themselves can read their own
comment list — no admin override.

Filters: triage_status, project_id. Returns enriched rows with project
name, component name, rule_displayed_name, section (XCCDF key), and
latest_activity_at (max of triage_set_at / adjudicated_at / latest
response created_at) — used by the frontend "new activity since last
view" badge logic in Task 20.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/routes.rb app/controllers/users_controller.rb spec/requests/users_spec.rb
git commit -F /tmp/msg-12.md
rm /tmp/msg-12.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/12-users-controller-my-comments-endpoint.md \
       docs/plans/PR717-public-comment-review/12-users-controller-my-comments-endpoint-DONE.md
git commit -m "chore: mark plan task 12 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## Backend complete after this task

Tasks 01-12 land the entire backend layer. Tasks 13-22 are frontend work that consumes these endpoints.
