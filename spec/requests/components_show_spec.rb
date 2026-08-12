# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component show' do
  include_context 'components request base setup'

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
      blueprint_keys = ComponentBlueprint.render_as_json(component, view: :editor).keys.sort

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

  describe 'effective_permissions in JSON response' do
    it 'includes effective_permissions=admin for project admin' do
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['effective_permissions']).to eq('admin')
    end

    it 'includes effective_permissions=viewer for viewer member' do
      viewer = create(:user)
      Membership.create!(user: viewer, membership: project, role: 'viewer')
      sign_in viewer
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['effective_permissions']).to eq('viewer')
    end

    it 'conceals the component from a non-member (hidden project → 404, no effective_permissions exposed)' do
      outsider = create(:user)
      sign_in outsider
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'reviews in editor JSON — ReviewBlueprint shape' do
    before do
      Review.create!(action: 'comment', comment: 'Blueprint shape test',
                     section: nil, user: user, rule: component.rules.first)
    end

    it 'reviews include commenter_display_name from ReviewBlueprint' do
      get "/components/#{component.id}.json"
      reviews = response.parsed_body['reviews']
      review = reviews.find { |r| r['comment'] == 'Blueprint shape test' }
      expect(review).to be_present
      expect(review).to have_key('commenter_display_name')
      expect(review['commenter_display_name']).to eq(user.name)
    end

    it 'reviews do NOT expose user_id (privacy)' do
      get "/components/#{component.id}.json"
      reviews = response.parsed_body['reviews']
      review = reviews.find { |r| r['comment'] == 'Blueprint shape test' }
      expect(review).not_to have_key('user_id')
    end

    it 'reviews include commentable_type' do
      get "/components/#{component.id}.json"
      reviews = response.parsed_body['reviews']
      review = reviews.find { |r| r['comment'] == 'Blueprint shape test' }
      expect(review).to have_key('commentable_type')
    end

    # The component-level reviews feed serves BOTH kinds. The show path
    # eager-loads :rules (the stig STI class), which on an srg component is an
    # empty-but-loaded association — the cached fast path must not swallow
    # reviews that live on authored requirements.
    it 'serves reviews on an srg component\'s authored requirements' do
      srg = create(:component, :skip_rules, project: project, document_type: 'srg',
                                            prefix: 'RVWD-00', name: 'Reviewed SRG',
                                            title: 'Reviewed SRG')
      requirement = create(:srg_rule, :authored, component: srg, rule_id: '000001')
      Review.create!(action: 'comment', comment: 'SRG feed test',
                     section: nil, user: user, commentable: requirement)

      get "/components/#{srg.id}.json"

      expect(response).to have_http_status(:success)
      reviews = response.parsed_body['reviews']
      review = reviews.find { |r| r['comment'] == 'SRG feed test' }
      expect(review).to be_present
      expect(review['rule_displayed_name']).to eq('RVWD-00-000001')
    end
  end

  describe 'GET /components/:id (reaction scoping)' do
    it 'show does not load reactions for non-displayed reviews' do
      rule = component.rules.first
      Review.transaction do
        110.times do |i|
          Review.insert!({
                           rule_id: rule.id,
                           commentable_type: 'BaseRule', commentable_id: rule.id,
                           user_id: user.id, action: 'comment',
                           comment: "scoping-test #{i}",
                           created_at: Time.current, updated_at: Time.current
                         })
        end
      end

      captured = nil
      allow(Reaction).to receive(:summary).and_wrap_original do |orig, ids, *rest|
        captured = ids
        orig.call(ids, *rest)
      end

      get "/components/#{component.id}", headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:ok)

      expect(captured).not_to be_nil, 'Reaction.summary was not called'
      expect(captured.size).to be <= 100,
                               "expected ≤ 100 review ids passed to Reaction.summary; got #{captured.size}"
    end
  end

  context 'when unauthenticated' do
    before { sign_out user }

    it 'redirects to sign-in' do
      get "/components/#{component.id}", headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:unauthorized)
        .or redirect_to(new_user_session_path)
    end
  end

  context 'as non-member on unreleased component' do
    let(:outsider) { create(:user) }

    before { sign_in outsider }

    it 'conceals it (hidden project → 404)' do
      get "/components/#{component.id}", headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:not_found)
    end
  end

  # The count badge and editor header read rules_count from the component
  # payload. The wire key stays, the value is kind-aware: srg components
  # report their authored-row count, not the class-Rule counter cache
  # (which is structurally 0 for them).
  describe 'editor payload requirement count' do
    it 'serves the authored requirement count for an srg-kind component under rules_count' do
      counted_srg = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                    prefix: 'CNTD-00', name: 'Counted SRG',
                                                    title: 'Counted SRG')
      create(:srg_rule, :authored, component: counted_srg, rule_id: '000001')
      create(:srg_rule, :authored, component: counted_srg, rule_id: '000002')

      get "/components/#{counted_srg.id}.json"

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['rules_count']).to eq(2)
    end
  end

  # The rule deep-link (/components/:id/:stig_id) resolves through set_rule.
  # The deep-linked row is an authored SrgRule on srg components and a Rule
  # on stig components — a Rule-branch lookup silently missed authored rows,
  # flashing "could not be found" for every srg deep-link (the exact links
  # the triage table renders). Found = 200 render; missed = 302 redirect.
  describe 'GET /components/:id/:stig_id (rule deep-link)' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'SHDL-00', name: 'Deep-link SRG',
                                      title: 'Deep-link SRG')
    end
    let_it_be(:authored_requirement) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001')
    end

    it 'resolves a stig component deep-link to its rule' do
      rule = component.rules.first
      get "/components/#{component.id}/#{component.prefix}-#{rule.rule_id}"
      expect(response).to have_http_status(:ok)
    end

    it 'resolves an srg component deep-link to its authored requirement' do
      get "/components/#{srg_component.id}/SHDL-00-000001"
      expect(response).to have_http_status(:ok)
    end

    it 'redirects with a flash for an unknown rule id' do
      get "/components/#{component.id}/#{component.prefix}-999999"
      expect(response).to have_http_status(:found)
    end
  end
end
