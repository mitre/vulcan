# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Dashboard stats endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:member) { create(:user) }
  let_it_be(:project) { create(:project, name: 'Dashboard Contract Project', visibility: :hidden) }
  let_it_be(:membership) { create(:membership, :viewer, user: member, membership: project) }
  let_it_be(:component) do
    create(:component, :skip_rules, project: project, prefix: 'DCON-01', name: 'Dashboard Contract Component')
  end
  let_it_be(:rule) do
    create(:rule, component: component, status: 'Applicable - Configurable', rule_severity: 'high', locked: true)
  end
  let_it_be(:pending_comment) { create(:review, :comment, rule: rule, user: member) }

  before do
    Rails.application.reload_routes!
    sign_in member
  end

  describe 'GET /api/components/:id/stats' do
    it 'matches ComponentStatsResponse schema' do
      get "/api/components/#{component.id}/stats", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rules_by_status, :rules_by_severity, :rule_count,
                            :completion_pct, :lock_pct
      expect(body['rule_count']).to eq(1)
      expect(body['completion_pct']).to eq(100.0)
    end
  end

  describe 'GET /api/components/:id/workflow_state' do
    it 'matches ComponentWorkflowStateResponse schema' do
      get "/api/components/#{component.id}/workflow_state", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :authoring, :locks, :reviews, :comment, :triage, :export
      expect(body.dig('locks', 'all_locked')).to be(true)
      expect(body.dig('comment', 'pending_comments')).to eq(1)
    end
  end

  describe 'GET /api/components/:id/triage_summary' do
    it 'matches TriageSummaryResponse schema' do
      get "/api/components/#{component.id}/triage_summary", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :by_triage_status, :total, :adjudicated, :adjudication_pct
      expect(body['total']).to eq(1)
      expect(body.dig('by_triage_status', 'pending')).to eq(1)
    end
  end

  describe 'GET /api/projects/:id/stats' do
    it 'matches ProjectStatsResponse schema' do
      get "/api/projects/#{project.id}/stats", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :aggregate, :components
      expect(body.dig('aggregate', 'rule_count')).to eq(1)
      expect(body['components'].first['prefix']).to eq('DCON-01')
    end

    it 'matches the documented 403 shape for a non-member' do
      sign_in create(:user)

      get "/api/projects/#{project.id}/stats", headers: json_headers
      body = validate_and_parse!(expected_status: :forbidden)

      expect(body['error']).to match(/not authorized/)
    end
  end

  describe 'GET /api/projects/:id/triage_summary' do
    it 'matches TriageSummaryResponse schema' do
      get "/api/projects/#{project.id}/triage_summary", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :by_triage_status, :total, :adjudicated, :adjudication_pct
      expect(body['total']).to eq(1)
    end

    it 'matches the documented 401 shape when unauthenticated' do
      sign_out member

      get "/api/projects/#{project.id}/triage_summary", headers: json_headers
      body = validate_and_parse!(expected_status: :unauthorized)

      expect(body['error']).to eq('Unauthorized')
    end
  end
end
