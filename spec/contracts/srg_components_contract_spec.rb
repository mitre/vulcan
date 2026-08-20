# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

# Contract coverage for SRG-kind components: the authored-requirement
# branches of the kind-routed oneOf schemas must validate against REAL
# responses, not pass vacuously via empty arrays.
RSpec.describe 'SRG component endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:membership) { Membership.create!(user: admin, membership: project, role: 'admin') }
  let_it_be(:component) do
    create(:component, :skip_rules, project: project, document_type: 'srg', prefix: 'SRGT-00',
                                    name: 'Contract SRG', title: 'Contract SRG')
  end
  let_it_be(:authored) do
    create(:srg_rule, :authored, component: component, rule_id: '000001', status: 'Applicable')
  end
  let_it_be(:comment) do
    create(:review, :comment, user: admin, rule: nil, commentable: authored,
                              comment: 'Contract comment', section: 'fixtext')
  end

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  it 'GET /components/:id (editor) validates the authored-requirement branch with real rows' do
    get "/components/#{component.id}.json"
    body = validate_and_parse!

    expect(body['document_type']).to eq('srg')
    expect(body['rules'].length).to eq(1)
    expect(body['rules'].first['derived_from_version']).to be_nil
    expect(body['status_counts']).to eq('not_yet_determined' => 0, 'applicable' => 1,
                                        'not_applicable' => 0)
  end

  it 'GET /rules/:id validates an individual authored requirement' do
    get "/rules/#{authored.id}", headers: { 'Accept' => 'application/json' }
    body = validate_and_parse!

    expect(body['id']).to eq(authored.id)
    expect(body['status']).to eq('Applicable')
  end

  it 'GET /api/components/:id/stats validates the SRG bucket branch with real counts' do
    get "/api/components/#{component.id}/stats"
    body = validate_and_parse!

    expect(body['document_type']).to eq('srg')
    expect(body['rules_by_status']).to eq('not_yet_determined' => 0, 'applicable' => 1,
                                          'not_applicable' => 0)
  end

  it 'GET /api/components/:id/workflow_state carries the profile key' do
    get "/api/components/#{component.id}/workflow_state"
    body = validate_and_parse!

    expect(body['document_type']).to eq('srg')
    expect(body.dig('authoring', 'rules_total')).to eq(1)
  end
end
