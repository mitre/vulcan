# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
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

    it 'returns 403 for non-member (no effective_permissions exposed)' do
      outsider = create(:user)
      sign_in outsider
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
