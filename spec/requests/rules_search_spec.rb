# frozen_string_literal: true

require 'rails_helper'

# GET /search/rules — the global requirement lookup: paste a requirement
# version id, get back compact [id, rule_id, component_id, prefix] tuples.
#
# REQUIREMENTS:
# - Finds live requirement rows of BOTH document kinds by version id:
#   stig-kind Rules, and authored SRG requirements (whose version is the
#   core requirement id they derive from).
# - Access-scoped: project membership, direct component membership, or a
#   released component. Admins unrestricted. Discoverable-but-not-joined
#   projects grant existence, not content — their rules stay hidden.
# - Tombstoned (soft-deleted) rows never surface.
RSpec.describe 'Rules search' do
  include_context 'components request base setup'

  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    prefix: 'RSRC-00', name: 'Search SRG', title: 'Search SRG')
  end
  let_it_be(:authored_requirement) do
    create(:srg_rule, :authored, component: srg_component,
                                 rule_id: '000001', version: 'SRG-APP-000901')
  end

  describe 'kind coverage (as member)' do
    it 'finds a stig rule by its version id' do
      rule = component.rules.first

      get '/search/rules', params: { q: rule.version }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rules'])
        .to include([rule.id, rule.rule_id, component.id, component.prefix])
    end

    it 'finds an authored SRG requirement by its version id' do
      get '/search/rules', params: { q: 'SRG-APP-000901' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rules'])
        .to include([authored_requirement.id, '000001', srg_component.id, 'RSRC-00'])
    end

    it 'does not surface tombstoned requirements' do
      create(:srg_rule, :authored, component: srg_component,
                                   rule_id: '000002', version: 'SRG-APP-000902',
                                   deleted_at: Time.current)

      get '/search/rules', params: { q: 'SRG-APP-000902' }

      expect(response.parsed_body['rules']).to be_empty
    end
  end

  describe 'result order' do
    it 'returns matches in a deterministic order — component then rule id' do
      late_component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                       prefix: 'RSRD-00', name: 'Order SRG',
                                                       title: 'Order SRG')
      # Insert the higher-sorting rows FIRST so physical row order differs
      # from the deterministic contract — an unordered limit would return
      # these in insertion order.
      late_two = create(:srg_rule, :authored, component: late_component,
                                              rule_id: '000902', version: 'SRG-APP-000955')
      late_one = create(:srg_rule, :authored, component: late_component,
                                              rule_id: '000901', version: 'SRG-APP-000955')
      early = create(:srg_rule, :authored, component: srg_component,
                                           rule_id: '000900', version: 'SRG-APP-000955')

      get '/search/rules', params: { q: 'SRG-APP-000955' }

      expect(response.parsed_body['rules']).to eq([
                                                    [early.id, '000900', srg_component.id, 'RSRC-00'],
                                                    [late_one.id, '000901', late_component.id, 'RSRD-00'],
                                                    [late_two.id, '000902', late_component.id, 'RSRD-00']
                                                  ])
    end
  end

  describe 'access scoping' do
    let(:outsider) { create(:user) }

    before do
      sign_out user
      sign_in outsider
    end

    it 'conceals rules of projects the user is not a member of, even discoverable ones' do
      discoverable_project = create(:project, visibility: :discoverable)
      unreleased = create(:component, project: discoverable_project)
      rule = unreleased.rules.first

      get '/search/rules', params: { q: rule.version }

      expect(response.parsed_body['rules']).to be_empty
    end

    it 'returns rules of released components, and only those, to a non-member' do
      released = create(:component, project: create(:project), released: true)
      rule = released.rules.first

      get '/search/rules', params: { q: rule.version }

      tuples = response.parsed_body['rules']
      expect(tuples).to include([rule.id, rule.rule_id, released.id, released.prefix])
      # The member-only component carries the same SRG versions; it must
      # stay hidden in the same response that serves the released match.
      expect(tuples.pluck(2)).not_to include(component.id)
    end

    it 'returns authored requirements of a component the user holds a direct component membership on' do
      Membership.create!(user: outsider, membership: srg_component, role: 'viewer')

      get '/search/rules', params: { q: 'SRG-APP-000901' }

      expect(response.parsed_body['rules'])
        .to include([authored_requirement.id, '000001', srg_component.id, 'RSRC-00'])
    end
  end

  describe 'as admin' do
    let(:admin) { create(:user, admin: true) }

    before do
      sign_out user
      sign_in admin
    end

    it 'finds requirements across all projects without membership' do
      get '/search/rules', params: { q: 'SRG-APP-000901' }

      expect(response.parsed_body['rules'])
        .to include([authored_requirement.id, '000001', srg_component.id, 'RSRC-00'])
    end
  end

  context 'when unauthenticated' do
    before { sign_out user }

    it 'redirects to sign-in' do
      get '/search/rules', params: { q: 'SRG-APP-000901' }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
