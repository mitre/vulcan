# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }
  let(:application_json) { 'application/json' }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'admin')
  end

  # ==========================================================================
  # REQUIREMENT: UpdateComponentDetailsModal must be able to update basic
  # component fields (name, description, version, etc.) WITHOUT sending
  # advanced_fields. The before_action filter should not require advanced_fields.
  # ==========================================================================
  describe 'PUT /components/:id' do
    context 'when updating basic fields without advanced_fields' do
      it 'updates name successfully' do
        put "/components/#{component.id}", params: {
          component: {
            name: 'Updated Component Name'
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.name).to eq('Updated Component Name')
      end

      it 'updates description successfully' do
        put "/components/#{component.id}", params: {
          component: {
            description: 'Updated description text'
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.description).to eq('Updated description text')
      end

      it 'updates multiple basic fields at once' do
        put "/components/#{component.id}", params: {
          component: {
            name: 'New Name',
            version: '2',
            release: '1',
            title: 'New Title',
            description: 'New description'
          }
        }

        expect(response).to have_http_status(:success)
        component.reload
        expect(component.name).to eq('New Name')
        expect(component.version.to_s).to eq('2')
        expect(component.release.to_s).to eq('1')
        expect(component.title).to eq('New Title')
        expect(component.description).to eq('New description')
      end
    end

    context 'when updating advanced_fields' do
      it 'allows admin to update advanced_fields' do
        # Admin membership already set up in before block
        put "/components/#{component.id}", params: {
          component: {
            advanced_fields: true
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.advanced_fields).to be(true)
      end
    end

    # Task 22: admin form for the public comment-period lifecycle.
    # Component model already validates inclusion of comment_phase in
    # COMMENT_PHASES (draft, open, adjudication, final). The controller
    # must permit the new params or they get silently filtered out.
    context 'when updating the comment-phase fieldset' do
      it 'permits comment_phase and date params' do
        put "/components/#{component.id}", params: {
          component: {
            comment_phase: 'open',
            comment_period_starts_at: '2026-04-29',
            comment_period_ends_at: '2026-05-14'
          }
        }

        expect(response).to have_http_status(:success)
        component.reload
        expect(component.comment_phase).to eq('open')
        expect(component.comment_period_starts_at).not_to be_nil
        expect(component.comment_period_ends_at).not_to be_nil
      end

      it 'rejects invalid comment_phase via the model validator' do
        put "/components/#{component.id}", params: {
          component: { comment_phase: 'not-a-real-phase' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(component.reload.comment_phase).not_to eq('not-a-real-phase')
      end
    end
  end

  # ==========================================================================
  # REQUIREMENT: Component show JSON must include srg_id (from srg_rule
  # association, NOT from nil DB column) and satisfaction relationships
  # for BOTH member and non-member views.
  # ==========================================================================
  describe 'GET /components/:id.json (srg_id and satisfaction data)' do
    let!(:component_with_rules) { create(:component, project: project) }

    context 'as project member' do
      it 'includes srg_id derived from srg_rule.version on each rule' do
        get "/components/#{component_with_rules.id}.json"
        expect(response).to have_http_status(:success)
        json = response.parsed_body
        rule = json['rules'].first
        expect(rule).to have_key('srg_id')
        expect(rule['srg_id']).to be_present
        expect(rule['srg_id']).to start_with('SRG-')
      end

      it 'includes satisfies and satisfied_by arrays on each rule' do
        get "/components/#{component_with_rules.id}.json"
        json = response.parsed_body
        rule = json['rules'].first
        expect(rule).to have_key('satisfies')
        expect(rule).to have_key('satisfied_by')
        expect(rule['satisfies']).to be_an(Array)
        expect(rule['satisfied_by']).to be_an(Array)
      end
    end

    context 'as non-member viewing released component' do
      let(:non_member) { create(:user) }
      let!(:released_component) { create(:component, project: project, released: true) }

      before do
        sign_out user
        sign_in non_member
      end

      it 'includes srg_id derived from srg_rule.version (not nil DB column)' do
        get "/components/#{released_component.id}.json"
        expect(response).to have_http_status(:success)
        json = response.parsed_body
        rule = json['rules'].first
        expect(rule).to have_key('srg_id')
        expect(rule['srg_id']).to be_present
        expect(rule['srg_id']).to start_with('SRG-')
      end

      it 'includes satisfies and satisfied_by arrays' do
        get "/components/#{released_component.id}.json"
        json = response.parsed_body
        rule = json['rules'].first
        expect(rule).to have_key('satisfies')
        expect(rule).to have_key('satisfied_by')
        expect(rule['satisfies']).to be_an(Array)
        expect(rule['satisfied_by']).to be_an(Array)
      end
    end
  end

  # ==========================================================================
  # REQUIREMENT: refreshComponent() in ProjectComponent.vue / RulesCodeEditorView.vue
  # fetches /components/:id.json and Object.assigns the response into the local
  # component prop. The response shape MUST match the initial render's
  # ComponentBlueprint :editor view exactly so refresh doesn't silently degrade
  # the in-memory shape (e.g., memberships losing name/email decoration, or
  # admins ghost field appearing only after refresh).
  # ==========================================================================
  describe 'GET /components/:id.json (editor refresh contract)' do
    let(:other_user) { create(:user, name: 'Other Member', email: 'other@example.com') }

    before do
      Membership.create!(user: other_user, membership: component, role: 'author')
    end

    it 'matches the ComponentBlueprint :editor view shape exactly' do
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:success)

      json_keys = response.parsed_body.keys.sort
      blueprint_keys = ComponentBlueprint.render_as_hash(component, view: :editor).keys.map(&:to_s).sort

      expect(json_keys).to eq(blueprint_keys)
    end

    it 'memberships include name and email (MembershipBlueprint shape)' do
      get "/components/#{component.id}.json"
      memberships = response.parsed_body['memberships']
      member = memberships.find { |m| m['email'] == other_user.email }

      expect(member).to be_present
      expect(member).to have_key('name')
      expect(member).to have_key('email')
      expect(member['name']).to eq(other_user.name)
    end

    it 'does NOT include admins (regression guard for dead field)' do
      get "/components/#{component.id}.json"
      expect(response.parsed_body).not_to have_key('admins')
    end

    it 'does NOT include available_members or all_users (information disclosure regression guard)' do
      get "/components/#{component.id}.json"
      expect(response.parsed_body).not_to have_key('available_members')
      expect(response.parsed_body).not_to have_key('all_users')
    end
  end

  # ==========================================================================
  # REQUIREMENT: Bulk component export must work for released components
  # shown on the ProjectComponents page. The URL pattern must not collide
  # with the single-component export route /components/:id/export/:type.
  # See: docs/disa-process/export-requirements.md Gap 7
  # ==========================================================================
  describe 'GET /components/bulk_export/:type (ProjectComponents export)' do
    let!(:released) { create(:component, project: project, released: true) }

    it 'exports CSV for selected component IDs' do
      get "/components/bulk_export/csv?component_ids=#{released.id}",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
    end

    it 'exports zip for multiple component IDs' do
      released2 = create(:component, project: project, released: true)
      get "/components/bulk_export/csv?component_ids=#{released.id},#{released2.id}",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('application/zip').or include('application/octet-stream')
    end

    it 'rejects unsupported export types' do
      get "/components/bulk_export/banana?component_ids=#{released.id}",
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:bad_request)
    end

    it 'requires component_ids parameter' do
      get '/components/bulk_export/csv',
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ==========================================================================
  # REQUIREMENT: Components index should return optimized JSON with only
  # needed fields for table display. Should NOT include heavy fields.
  # ==========================================================================
  describe 'GET /components (Jbuilder optimization)' do
    let!(:released_component) do
      comp = create(:component, project: project, released: true)
      comp.reload
      comp
    end
    let!(:unreleased_component) { create(:component, project: project, released: false) }

    it_behaves_like 'jbuilder index', {
      path: '/components',
      factory: :component,
      required_fields: %w[id name version release prefix updated_at based_on_title based_on_version],
      excluded_fields: %w[rules reviews memberships histories metadata]
    }

    it 'only returns released components' do
      get '/components', headers: { 'Accept' => application_json }

      json = response.parsed_body
      ids = json.pluck('id')

      expect(ids).to include(released_component.id)
      expect(ids).not_to include(unreleased_component.id)
    end
  end

  # REQUIREMENT: Diff viewer needs to find other components based on the same SRG.
  # The query uses DISTINCT + ORDER BY, which requires ORDER BY columns in SELECT list.
  describe 'GET /components/:id/search/based_on_same_srg' do
    it 'returns components based on the same SRG without 500 error' do
      get "/components/#{component.id}/search/based_on_same_srg",
          headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success).or have_http_status(:not_found)
      # Should never be a 500
      expect(response).not_to have_http_status(:internal_server_error)
    end
  end

  describe 'GET /components/:id/compare/:diff_id' do
    it 'returns diff data for two components' do
      # Create a second component on the same SRG for comparison
      other_component = create(:component, project: project)

      get "/components/#{component.id}/compare/#{other_component.id}",
          headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
    end
  end

  # REQUIREMENT: Activity panel (B5) needs a dedicated histories endpoint
  # so the frontend can re-fetch after rule saves without full page reload.
  describe 'GET /components/:id/histories' do
    it 'requires authentication' do
      sign_out user
      get "/components/#{component.id}/histories",
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end

    it 'returns an array of formatted audit entries' do
      # Create a change to generate an audit
      rule = component.rules.first
      rule.update!(title: 'Updated for history test', audit_comment: 'Test history')

      get "/components/#{component.id}/histories",
          headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to be_an(Array)
      expect(json.length).to be > 0
      # Each entry should have the VulcanAudit.format structure
      entry = json.first
      expect(entry).to have_key('action')
      expect(entry).to have_key('audited_changes')
      expect(entry).to have_key('created_at')
    end

    it 'returns 404 for non-existent component' do
      get '/components/999999/histories',
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /components/:id/comments' do
    before do
      rule = component.rules.first
      Review.create!(action: 'comment', comment: 'check issue', user: user, rule: rule, section: 'check_content')
    end

    it 'returns paginated comments + DISA-native triage_status on the wire' do
      get "/components/#{component.id}/comments", params: { triage_status: 'all' },
                                                  headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to have_key('rows')
      expect(body).to have_key('pagination')
      expect(body['rows'].first['triage_status']).to eq('pending') # DISA-native, not 'Pending'
      expect(body['rows'].first['section']).to eq('check_content') # XCCDF key, not "Check"
    end

    it 'returns 404 for a non-existent component' do
      get '/components/99999999/comments', headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:not_found)
    end

    it 'filters by section' do
      get "/components/#{component.id}/comments",
          params: { triage_status: 'all', section: 'fixtext' },
          headers: { 'Accept' => application_json }
      expect(response.parsed_body['rows'].size).to eq(0)
    end

    # REQUIREMENT: triage rows change moment-to-moment during a public-comment
    # window — every concurrent triager refresh needs the latest data.
    # Browsers/proxies must not cache the JSON response, or one triager will
    # see another's already-handled comment as still-pending and double-act.
    it 'sets Cache-Control: no-store so browsers/proxies cannot cache the queue' do
      get "/components/#{component.id}/comments", headers: { 'Accept' => application_json }
      expect(response.headers['Cache-Control'].to_s).to match(/no-store/i)
    end
  end

  # REQUIREMENT: Delete component must clean up all dependent records
  # without N+1 callbacks. Bulk delete for performance.
  describe 'DELETE /components/:id' do
    it 'destroys component and all dependent records' do
      # Use a fresh component so we don't destroy the shared one
      doomed = create(:component, project: project)
      rule_ids = doomed.rules.pluck(:id)

      delete "/components/#{doomed.id}",
             headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      expect(Component.find_by(id: doomed.id)).to be_nil
      expect(Rule.unscoped.where(id: rule_ids).count).to eq(0)
    end
  end
end
