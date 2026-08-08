# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component search and rule picker' do
  include_context 'components request base setup'

  describe 'GET /components/:id/rules_picker.json' do
    it 'returns lightweight rule data with satisfaction IDs' do
      get "/components/#{component.id}/rules_picker.json"
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body).to have_key('rules')
      rule = body['rules'].first
      expect(rule).to have_key('id')
      expect(rule).to have_key('rule_id')
      expect(rule).to have_key('title')
      expect(rule).to have_key('satisfied_by')
      expect(rule).to have_key('satisfies')
      expect(rule).not_to have_key('fixtext')
      expect(rule).not_to have_key('vuln_discussion')
      expect(rule).not_to have_key('checks_attributes')
    end

    it 'requires authentication' do
      sign_out user
      get "/components/#{component.id}/rules_picker.json"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'conceals an unreleased component from a non-member (hidden project → 404)' do
      outsider = create(:user)
      sign_in outsider
      get "/components/#{component.id}/rules_picker.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /components/:id/find' do
    let_it_be(:rule) { component.rules.first || create(:rule, component: component, title: 'Test LIKE injection rule') }
    let_it_be(:check_match_rule) do
      row = create(:rule, component: component, rule_id: '999901',
                          title: 'Rule found only through its check')
      Check.create!(base_rule: row, content: 'Verify the flotsam-marker audit configuration.')
      row
    end

    it 'sanitizes LIKE wildcards in search input' do
      post "/components/#{component.id}/find", params: { find: '%' }, as: :json
      expect(response).to have_http_status(:ok)
      results = response.parsed_body
      expect(results).to be_an(Array)
      expect(results.length).to be < component.rules.count
    end

    it 'returns the matching rule for a title search' do
      post "/components/#{component.id}/find", params: { find: rule.title.first(8) }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to include(rule.id)
    end

    it 'reaches a rule through its check content' do
      post "/components/#{component.id}/find", params: { find: 'flotsam-marker' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to eq([check_match_rule.id])
    end
  end

  # An SRG component stores requirements as authored SrgRules — the Rule STI
  # association is structurally empty for it, so an un-routed find silently
  # returns nothing. The searched columns all live on base_rules and both
  # child tables key on base_rule, so one field list serves both kinds.
  describe 'POST /components/:id/find on an SRG component' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'FIND-00', name: 'Find SRG', title: 'Find SRG')
    end
    let_it_be(:title_match) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                   title: 'Container escape prevention requirement')
    end
    let_it_be(:discussion_match) do
      row = create(:srg_rule, :authored, component: srg_component, rule_id: '000002',
                                         title: 'An unrelated requirement title')
      DisaRuleDescription.create!(base_rule: row, vuln_discussion: 'kernel hardening discussion text')
      row
    end
    let_it_be(:non_match) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000003',
                                   title: 'Nothing searchable here')
    end

    it 'returns authored requirements matching the search text in title' do
      post "/components/#{srg_component.id}/find", params: { find: 'container escape' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('rule_id')).to eq(%w[000001])
    end

    it 'reaches an authored requirement through its description child row' do
      post "/components/#{srg_component.id}/find", params: { find: 'kernel hardening' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('rule_id')).to eq(%w[000002])
    end

    it 'serializes matches in the authored requirement shape, not the Rule shape' do
      post "/components/#{srg_component.id}/find", params: { find: 'container escape' }, as: :json
      row = response.parsed_body.first

      expect(row['srg_id']).to eq(title_match.version)
      expect(row).not_to have_key('satisfies')
      expect(row).not_to have_key('satisfied_by')
    end
  end
end
