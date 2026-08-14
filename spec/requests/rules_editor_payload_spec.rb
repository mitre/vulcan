# frozen_string_literal: true

require 'rails_helper'

# The omit-keys convention, pinned: authored SRG requirement payloads
# carry only the keys their kind serves. The editor view includes the
# content collections and omits the satisfaction graph; the navigator
# and picker views omit every Rule-only array. Frontend consumers read
# these keys through the shared ruleArray accessor — this spec makes
# the payload side of that contract executable, so shape drift fails a
# test instead of a page.
RSpec.describe 'Authored SRG requirement payload shape' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg')
  end
  let_it_be(:authored) { create(:srg_rule, :authored, component: srg_component) }
  let_it_be(:author) do
    Membership.find_or_create_by!(user: create(:user, name: 'Payload Author'), membership: project) do |m|
      m.role = 'author'
    end.user
  end

  before { Rails.application.reload_routes! }

  describe 'GET /rules/:id (editor view)' do
    before { sign_in author }

    it 'includes the content collections and omits the satisfaction graph' do
      get "/rules/#{authored.id}", as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to include('checks_attributes', 'disa_rule_descriptions_attributes',
                                   'rule_descriptions_attributes', 'status', 'title', 'srg_id')
      expect(body['checks_attributes']).to be_an(Array)
      expect(body['disa_rule_descriptions_attributes']).to be_an(Array)
      expect(body.keys).not_to include('satisfies', 'satisfied_by')
    end
  end

  describe 'navigator and picker views (blueprint contract)' do
    it 'omits every Rule-only array key' do
      %i[navigator picker].each do |view|
        keys = JSON.parse(AuthoredSrgRuleBlueprint.render(authored, view: view)).keys
        expect(keys).not_to include('satisfies', 'satisfied_by',
                                    'checks_attributes', 'disa_rule_descriptions_attributes'),
                            "#{view} view leaked a Rule-only array key"
      end
    end
  end
end
