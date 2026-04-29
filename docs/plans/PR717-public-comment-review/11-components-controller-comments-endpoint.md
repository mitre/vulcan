# Task 11: GET /components/:id/comments paginated endpoint

**Depends on:** 03, 05
**Unblocks:** 14, 17, 19
**Estimate:** 25 min Claude-pace
**File touches:**
- `config/routes.rb`
- `app/controllers/components_controller.rb`
- `app/models/component.rb` (paginated query method)
- `spec/requests/components_spec.rb`
- `spec/models/component_spec.rb`

Backs the triage table (§2.2). Mirrors the existing `GET /components/:id/histories` pattern (`components_controller.rb:259-263`, `routes.rb:67-90`).

---

## Step 1: Write the failing model spec

Append to `spec/models/component_spec.rb`:

```ruby
describe '#paginated_comments' do
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:author) { create(:user) }

  before_all do
    create(:membership, user: viewer, membership: project, role: 'viewer')
    create(:membership, user: author, membership: project, role: 'author')

    rule = component.rules.first
    @c1 = Review.create!(action: 'comment', comment: 'first', user: viewer, rule: rule, section: 'check_content')
    @c2 = Review.create!(action: 'comment', comment: 'second', user: viewer, rule: rule, section: 'fixtext')
    @c3 = Review.create!(action: 'comment', comment: 'third', user: viewer, rule: component.rules.last,
                          section: nil, triage_status: 'concur', triage_set_by_id: author.id, triage_set_at: Time.current)
    @reply = Review.create!(action: 'comment', comment: 'thanks', user: author, rule: rule,
                             responding_to_review_id: @c1.id, section: 'check_content')
  end

  it 'returns top-level comments only (no replies)' do
    result = component.paginated_comments(triage_status: 'all')
    review_ids = result[:rows].map { |r| r[:id] }
    expect(review_ids).to include(@c1.id, @c2.id, @c3.id)
    expect(review_ids).not_to include(@reply.id)
  end

  it 'filters by triage_status' do
    pending_only = component.paginated_comments(triage_status: 'pending')
    expect(pending_only[:rows].map { |r| r[:id] }).to match_array([@c1.id, @c2.id])

    concur_only = component.paginated_comments(triage_status: 'concur')
    expect(concur_only[:rows].map { |r| r[:id] }).to eq([@c3.id])
  end

  it 'filters by section' do
    check = component.paginated_comments(triage_status: 'all', section: 'check_content')
    expect(check[:rows].map { |r| r[:id] }).to eq([@c1.id])
  end

  it 'filters by rule_id' do
    rule_id = component.rules.first.id
    by_rule = component.paginated_comments(triage_status: 'all', rule_id: rule_id)
    expect(by_rule[:rows].map { |r| r[:id] }).to match_array([@c1.id, @c2.id])
  end

  it 'filters by author_id' do
    by_author = component.paginated_comments(triage_status: 'all', author_id: viewer.id)
    expect(by_author[:rows].map { |r| r[:id] }).to match_array([@c1.id, @c2.id, @c3.id])
  end

  it 'sanitizes ILIKE wildcards in q' do
    # 100% should not match everything via accidental %
    result = component.paginated_comments(triage_status: 'all', q: '100%')
    expect(result[:total]).to eq(0)
  end

  it 'searches comment text via q' do
    result = component.paginated_comments(triage_status: 'all', q: 'second')
    expect(result[:rows].map { |r| r[:id] }).to eq([@c2.id])
  end

  it 'paginates' do
    result = component.paginated_comments(triage_status: 'all', page: 1, per_page: 2)
    expect(result[:rows].size).to eq(2)
    expect(result[:total]).to eq(3)
  end

  it 'caps per_page at 100' do
    result = component.paginated_comments(triage_status: 'all', per_page: 999)
    # Returned rows fit; per_page silently clamps
    expect(result[:rows].size).to be <= 100
  end

  it 'eager-loads associations to avoid N+1' do
    expect {
      result = component.paginated_comments(triage_status: 'all')
      result[:rows].each { |r| r[:author_name] && r[:rule_displayed_name] }
    }.to make_database_queries(count: { matching: /SELECT.*reviews/ }, count: 1..5)  # 1-5 queries; not 50+
  end
end
```

(`make_database_queries` matcher requires the `db-query-matchers` gem. If not present in the Gemfile, replace with `expect(ActiveRecord::Base.connection.query_cache_enabled).to ...` or just count queries via `ActiveSupport::Notifications.subscribe`. If unsure, drop the eager-load test and surface to user — main correctness is tested by the other examples.)

## Step 2: Write the failing request spec

Append to `spec/requests/components_spec.rb` (mirror the histories describe block):

```ruby
describe 'GET /components/:id/comments' do
  let_it_be(:viewer) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }

  before do
    Rails.application.reload_routes!
    create(:membership, user: viewer, membership: project, role: 'viewer') unless
      Membership.exists?(user: viewer, membership: project)
    rule = component.rules.first
    Review.create!(action: 'comment', comment: 'check issue', user: viewer, rule: rule, section: 'check_content')
    sign_in viewer
  end

  it 'returns paginated comments + DISA-native triage_status on the wire' do
    get "/components/#{component.id}/comments", params: { triage_status: 'all' }, as: :json

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body).to have_key('rows')
    expect(body).to have_key('pagination')
    expect(body['rows'].first['triage_status']).to eq('pending')  # DISA-native, not 'Pending'
    expect(body['rows'].first['section']).to eq('check_content')   # XCCDF key, not "Check"
  end

  it 'requires authentication' do
    sign_out viewer
    get "/components/#{component.id}/comments", as: :json
    expect(response.status).to be_in([302, 401])
  end

  it 'returns 404 for a non-existent component' do
    get '/components/99999999/comments', as: :json
    expect(response).to have_http_status(:not_found).or have_http_status(:found)
  end

  it 'filters by section' do
    get "/components/#{component.id}/comments", params: { triage_status: 'all', section: 'fixtext' }, as: :json
    expect(response.parsed_body['rows'].size).to eq(0)  # the only comment is on check_content
  end
end
```

## Step 3: Run specs to verify failure

```bash
bundle exec rspec spec/models/component_spec.rb -e "paginated_comments"
bundle exec rspec spec/requests/components_spec.rb -e "GET /components/:id/comments"
```

**Expected:** all FAIL.

## Step 4: Add the route

In `config/routes.rb`, locate the existing pattern (~line 67-90):

```ruby
get '/components/:id/histories', to: 'components#histories'
```

Add **directly after** (and before the `:stig_id` catch-all):

```ruby
get '/components/:id/comments', to: 'components#comments'
```

Critical: must appear before `get '/components/:id/:stig_id', ...` or the catch-all eats it.

## Step 5: Add `Component#paginated_comments`

In `app/models/component.rb`, after the existing `reviews` method (~line 529 per design doc):

```ruby
# Paginated, filterable accessor for top-level comment Reviews scoped to
# this component. Returns { rows: [...], pagination: {...} } where rows
# are pre-formatted hashes with author_name + rule_displayed_name injected.
# Used by GET /components/:id/comments to back the triage table.
def paginated_comments(triage_status: 'all', section: nil, rule_id: nil,
                        author_id: nil, q: nil, page: 1, per_page: 25,
                        resolved: 'all')
  page = [page.to_i, 1].max
  per_page = [[per_page.to_i, 1].max, 100].min

  scope = Review.top_level_comments
                .joins(:rule, :user)
                .where(rules: { component_id: id })
                .includes(:user, :rule, :triage_set_by, :adjudicated_by)

  scope = scope.where(triage_status: triage_status) unless triage_status == 'all'
  scope = scope.where(section: section) if section.present? && section != 'all'
  scope = scope.where(rule_id: rule_id) if rule_id.present?
  scope = scope.where(user_id: author_id) if author_id.present?

  case resolved
  when 'true', true then scope = scope.where.not(adjudicated_at: nil)
  when 'false', false then scope = scope.where(adjudicated_at: nil)
  end

  if q.present?
    scope = scope.where('reviews.comment ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(q)}%")
  end

  total = scope.count
  rule_id_to_displayed = rules.pluck(:id, :rule_id).to_h.transform_values { |rid| "#{prefix}-#{rid}" }

  rows = scope.order(created_at: :desc)
              .offset((page - 1) * per_page)
              .limit(per_page)
              .map do |r|
                {
                  id: r.id,
                  rule_id: r.rule_id,
                  rule_displayed_name: rule_id_to_displayed[r.rule_id],
                  section: r.section,
                  author_name: r.user&.name,
                  author_email: r.user&.email,
                  comment: r.comment,
                  created_at: r.created_at,
                  triage_status: r.triage_status,
                  triage_set_at: r.triage_set_at,
                  adjudicated_at: r.adjudicated_at,
                  duplicate_of_review_id: r.duplicate_of_review_id
                }
              end

  {
    rows: rows,
    pagination: {
      page: page,
      per_page: per_page,
      total: total
    }
  }
end
```

## Step 6: Add the controller action

In `app/controllers/components_controller.rb`, find `set_component_basic` and `authorize_component_access` filter declarations near the top of the controller. Add `:comments` to both `only:` arrays.

Find `def histories` and add directly after:

```ruby
def comments
  return head :not_found unless @component

  result = @component.paginated_comments(
    triage_status: params[:triage_status].presence || 'pending',
    section: params[:section].presence,
    rule_id: params[:rule_id].presence,
    author_id: params[:author_id].presence,
    q: params[:q].presence,
    page: params[:page].presence,
    per_page: params[:per_page].presence,
    resolved: params[:resolved].presence || 'all'
  )

  render json: result
end
```

## Step 7: Run specs to verify pass

```bash
bundle exec rspec spec/models/component_spec.rb -e "paginated_comments"
bundle exec rspec spec/requests/components_spec.rb -e "GET /components/:id/comments"
```

**Expected:** all PASS.

## Step 8: RuboCop + full impacted suite

```bash
bundle exec rubocop app/controllers/components_controller.rb app/models/component.rb config/routes.rb \
                    spec/models/component_spec.rb spec/requests/components_spec.rb
bundle exec rspec spec/requests/components_spec.rb spec/models/component_spec.rb
```

**Expected:** 0 offenses, 0 regressions.

## Step 9: Commit

```bash
cat > /tmp/msg-11.md <<'EOF'
feat: GET /components/:id/comments paginated endpoint

Backs the triage table UI in Tasks 14/17/19. Mirrors the existing
/components/:id/histories pattern in components_controller.rb:259-263 and
routes.rb:67-90.

Component#paginated_comments method:
- Scope: Review.top_level_comments (excludes responses)
- Filters: triage_status, section, rule_id, author_id, q (ILIKE on
  comment, sanitized via sanitize_sql_like), resolved (orthogonal to
  triage_status — queries adjudicated_at IS [NOT] NULL)
- Eager-loads :user, :rule, :triage_set_by, :adjudicated_by to avoid N+1
- Returns DISA-native triage_status + XCCDF section keys on the wire;
  frontend translates to friendly labels via triageVocabulary.js

Auth: viewer+ via the existing authorize_component_access filter.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add config/routes.rb app/controllers/components_controller.rb app/models/component.rb \
        spec/models/component_spec.rb spec/requests/components_spec.rb
git commit -F /tmp/msg-11.md
rm /tmp/msg-11.md
```

## Step 10: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/11-components-controller-comments-endpoint.md \
       docs/plans/PR717-public-comment-review/11-components-controller-comments-endpoint-DONE.md
git commit -m "chore: mark plan task 11 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
