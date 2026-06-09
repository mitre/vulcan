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
  end

  describe 'POST /components/:id/find' do
    let_it_be(:rule) { component.rules.first || create(:rule, component: component, title: 'Test LIKE injection rule') }

    it 'sanitizes LIKE wildcards in search input' do
      post "/components/#{component.id}/find", params: { find: '%' }, as: :json
      expect(response).to have_http_status(:ok)
      results = response.parsed_body
      expect(results).to be_an(Array)
      expect(results.length).to be < component.rules.count
    end

    it 'returns matching rules for normal search' do
      post "/components/#{component.id}/find", params: { find: rule.title.first(8) }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
