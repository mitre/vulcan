# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: GET /projects/:id/comments — paginated aggregate triage
# rows across ALL of a project's components. Same row shape as the
# per-component endpoint, plus component_id + component_name on each
# row so the project-scope triage page can show which component each
# comment belongs to. Mirrors the security posture of the component
# endpoint: project-member read scope, no PII (email), no-store cache.
RSpec.describe 'GET /projects/:id/comments' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component_a) { create(:component, project: project, based_on: srg) }
  let_it_be(:component_b) { create(:component, project: project, based_on: srg) }

  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_srg) { create(:security_requirements_guide) }
  let_it_be(:other_component) { create(:component, project: other_project, based_on: other_srg) }

  let_it_be(:viewer) { create(:user, name: 'Industry Reviewer', email: 'pii@example.com') }
  let_it_be(:outsider) { create(:user) }

  before_all do
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
    # Viewer is also a member of other_project so they can post the
    # cross-project comment used to assert query-level isolation below.
    Membership.find_or_create_by!(user: viewer, membership: other_project) { |m| m.role = 'viewer' }

    Review.create!(action: 'comment', user: viewer, rule: component_a.rules.first,
                   comment: 'on a', section: 'check_content')
    Review.create!(action: 'comment', user: viewer, rule: component_b.rules.first,
                   comment: 'on b', section: 'fixtext')
    # Cross-project — must NOT appear in project's aggregate
    Review.create!(action: 'comment', user: viewer, rule: other_component.rules.first,
                   comment: 'cross-project leak attempt', section: nil)
  end

  before { Rails.application.reload_routes! }

  context 'as a project member' do
    before { sign_in viewer }

    it 'returns rows aggregated across all components in this project' do
      get "/projects/#{project.id}/comments", params: { triage_status: 'all' },
                                              headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      comments = body['rows'].pluck('comment')
      expect(comments).to include('on a', 'on b')
    end

    it 'never includes comments from other projects' do
      get "/projects/#{project.id}/comments", params: { triage_status: 'all' },
                                              headers: { 'Accept' => 'application/json' }
      comments = response.parsed_body['rows'].pluck('comment')
      expect(comments).not_to include('cross-project leak attempt')
    end

    it 'tags every row with its component_id and component_name' do
      get "/projects/#{project.id}/comments", params: { triage_status: 'all' },
                                              headers: { 'Accept' => 'application/json' }
      first = response.parsed_body['rows'].first
      expect(first).to have_key('component_id')
      expect(first).to have_key('component_name')
      expect([component_a.name, component_b.name]).to include(first['component_name'])
    end

    it 'never exposes the author email (PII leak)' do
      get "/projects/#{project.id}/comments", params: { triage_status: 'all' },
                                              headers: { 'Accept' => 'application/json' }
      response.parsed_body['rows'].each do |row|
        expect(row).not_to have_key('author_email')
        expect(row.values).not_to include(viewer.email)
      end
    end

    it 'sets Cache-Control: no-store so triagers always see fresh data' do
      get "/projects/#{project.id}/comments", headers: { 'Accept' => 'application/json' }
      expect(response.headers['Cache-Control'].to_s).to match(/no-store/i)
    end

    it 'supports the component_id filter to scope to a single component' do
      get "/projects/#{project.id}/comments",
          params: { triage_status: 'all', component_id: component_a.id },
          headers: { 'Accept' => 'application/json' }
      ids = response.parsed_body['rows'].pluck('component_id').uniq
      expect(ids).to eq([component_a.id])
    end

    it 'returns DISA-native vocabulary on the wire (triage_status / section keys)' do
      get "/projects/#{project.id}/comments", params: { triage_status: 'all' },
                                              headers: { 'Accept' => 'application/json' }
      expect(response.parsed_body['rows'].first['triage_status']).to eq('pending') # not "Pending"
    end
  end

  context 'as a non-member (IDOR)' do
    before { sign_in outsider }

    it 'returns 403' do
      get "/projects/#{project.id}/comments",
          headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # REQUIREMENT: the rule lookup used to decorate each row with
  # rule_displayed_name must scope to JUST the rules referenced by the
  # current page, not every rule across every component in the project.
  # For projects with thousands of rules this materially changes the
  # query profile.
  describe 'rule-lookup scope (perf)' do
    before { sign_in viewer }

    it 'fetches only the rules referenced by the current page' do
      page_size_test = 1
      captured_rule_lookup_sql = nil
      counter = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        # The rule-lookup query is the SELECT against base_rules with
        # specific id list (or component_id list pre-fix). Capture it.
        next unless sql.is_a?(String)
        next unless sql.match?(/FROM\s+"?base_rules"?/i)
        next if sql.match?(/INNER JOIN/i) # row-fetch joins, not the lookup

        captured_rule_lookup_sql = sql
      end
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        get "/projects/#{project.id}/comments",
            params: { triage_status: 'all', per_page: page_size_test, page: 1 },
            headers: { 'Accept' => 'application/json' }
      end
      expect(captured_rule_lookup_sql).to be_present
      # The lookup must filter by id (the page's rule_ids) — NOT by
      # component_id (which would over-fetch every rule in the project).
      # AR may emit `id = $1` for a single page-rule or `id IN (...)`
      # for multiple — accept either, but never `component_id`.
      expect(captured_rule_lookup_sql).to match(/"?base_rules"?\."?id"?\s*(=|IN)/i),
                                          "expected rule lookup to filter by id but got: #{captured_rule_lookup_sql}"
      expect(captured_rule_lookup_sql).not_to match(/component_id\s+IN/i),
                                              'rule lookup is over-fetching by component_id (perf regression)'
    end
  end
end
