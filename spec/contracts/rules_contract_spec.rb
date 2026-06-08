# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Rules endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:project) { create(:project, name: 'Rules Contract Project') }
  let_it_be(:component) do
    create(:component, project: project, based_on: srg, name: 'Rules Contract Comp', prefix: 'RCON-01')
  end
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
      m.role = 'admin'
    end
  end
  let_it_be(:rule) { component.rules.first || create(:rule, component: component) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # ── GET /rules/:id ──

  describe 'GET /rules/:id (JSON)' do
    it 'returns RuleEditorResponse with 38 fields from Blueprint :editor' do
      get "/rules/#{rule.id}", headers: json_headers
      body = validate_and_parse!

      expect(body['id']).to eq(rule.id)
      expect(body['rule_id']).to eq(rule.rule_id)

      assert_fields_present body, :id, :rule_id, :title, :version, :status, :rule_severity,
                            :locked, :review_requestor_id, :changes_requested, :comment_summary,
                            :rule_weight, :fixtext, :ident, :component_id,
                            :locked_fields, :nist_control_family, :srg_id,
                            :disa_rule_descriptions_attributes, :checks_attributes,
                            :satisfies, :satisfied_by, :reviews,
                            :rule_descriptions_attributes, :additional_answers_attributes,
                            :srg_rule_attributes, :srg_info

      expect(body['comment_summary']).to be_a(Hash)
      assert_fields_present body['comment_summary'], :open, :total
      expect(body['disa_rule_descriptions_attributes']).to be_an(Array)
      expect(body['checks_attributes']).to be_an(Array)
      expect(body['reviews']).to be_an(Array)
      expect(body['locked_fields']).to be_a(Hash)
    end
  end

  # ── GET /components/:componentId/rules ──

  describe 'GET /components/:componentId/rules (JSON)' do
    it 'returns RuleEditorResponse array' do
      get "/components/#{component.id}/rules", headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body.size).to be >= 1

      first_rule = body.find { |r| r['id'] == rule.id }
      expect(first_rule).not_to be_nil, "Rule #{rule.id} not in response"
      assert_fields_present first_rule, :id, :rule_id, :title, :version, :status, :rule_severity,
                            :locked, :comment_summary, :component_id, :locked_fields,
                            :checks_attributes, :disa_rule_descriptions_attributes,
                            :satisfies, :satisfied_by, :reviews, :srg_rule_attributes
      expect(first_rule['component_id']).to eq(component.id)
    end
  end

  # ── POST /components/:componentId/rules (create) ──

  describe 'POST /components/:componentId/rules (JSON)' do
    it 'returns RuleCreateResponse with toast + data containing new rule' do
      post "/components/#{component.id}/rules",
           params: { rule: { id: rule.id, duplicate: true } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :data
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to include('created')
      expect(body['data']).to be_a(Hash)
      assert_fields_present body['data'], :id, :rule_id, :status, :component_id
      expect(body['data']['component_id']).to eq(component.id)
    end
  end

  # ── GET /components/:componentId/rules/picker ──

  describe 'GET /components/:componentId/rules/picker (JSON)' do
    it 'returns rules wrapped in { rules: RulePickerResponse[] }' do
      get "/components/#{component.id}/rules_picker", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rules
      expect(body['rules']).to be_an(Array)
      expect(body['rules'].size).to be >= 1

      first_rule = body['rules'].first
      assert_fields_present first_rule, :id, :rule_id, :title, :displayed_name, :satisfies, :satisfied_by
      expect(first_rule['displayed_name']).to start_with(component.prefix)
    end
  end

  # ── PUT /rules/:id ──

  describe 'PUT /rules/:id (JSON)' do
    it 'returns ToastResponse with success variant and control updated title' do
      put "/rules/#{rule.id}",
          params: { rule: { vendor_comments: 'Contract test vendor comment' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Control updated.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :rule, :data
    end
  end

  # ── DELETE /rules/:id ──

  describe 'DELETE /rules/:id (JSON)' do
    let!(:deletable_rule) do
      component.rules.create!(
        rule_id: '999999',
        status: 'Not Yet Determined',
        rule_severity: 'medium',
        rule_weight: '10.0',
        version: rule.version,
        srg_rule: rule.srg_rule
      )
    end

    it 'returns ToastResponse with deleted confirmation' do
      delete "/rules/#{deletable_rule.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Control deleted.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :rule, :data
    end
  end

  # ── POST /rules/:ruleId/reviews ──

  describe 'POST /rules/:ruleId/reviews (JSON)' do
    it 'returns ToastResponse with posted confirmation' do
      post "/rules/#{rule.id}/reviews",
           params: { review: { action: 'comment', comment: 'Rules contract test comment',
                               section: 'fixtext', component_id: component.id } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Comment posted.')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end
  end

  # ── GET /rules/:id/search/related_rules ──

  describe 'GET /rules/:id/search/related_rules (JSON)' do
    it 'returns { rules: [], parents: [] } with correct structure' do
      get "/rules/#{rule.id}/search/related_rules", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rules, :parents
      expect(body['rules']).to be_an(Array)
      expect(body['parents']).to be_an(Array)
      expect(body.keys).to contain_exactly('rules', 'parents')
    end
  end

  # ── POST /rules/:id/revert ──

  describe 'POST /rules/:id/revert (JSON)' do
    include_context 'with auditing'
    before(:all) { Audited.auditing_enabled = true }
    after(:all) { Audited.auditing_enabled = false }

    let_it_be(:audit) do
      rule.update!(vendor_comments: 'Before revert')
      rule.update!(vendor_comments: 'After revert')
      VulcanAudit.where(auditable: rule, action: 'update').order(:id).last
    end

    it 'returns ToastResponse with revert confirmation' do
      post "/rules/#{rule.id}/revert",
           params: { audit_id: audit.id, fields: ['vendor_comments'] },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('History reverted.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :rule, :data
    end
  end

  # ── PATCH /rules/:id/section_locks ──

  describe 'PATCH /rules/:id/section_locks (JSON)' do
    it 'returns RuleSectionLockResponse with rule + toast' do
      patch "/rules/#{rule.id}/section_locks",
            params: { section: 'Fix', locked: true, comment: 'Contract test lock' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :rule, :toast
      expect(body['rule']['id']).to eq(rule.id)
      expect(body['rule']['locked_fields']).to be_a(Hash)
      expect(body['rule']['locked_fields']['Fix']).to be(true)
      expect(body.dig('toast', 'variant')).to eq('success')
    end
  end

  # ── PATCH /rules/:id/bulk_section_locks ──

  describe 'PATCH /rules/:id/bulk_section_locks (JSON)' do
    it 'returns RuleSectionLockResponse with rule + toast' do
      patch "/rules/#{rule.id}/bulk_section_locks",
            params: { sections: %w[Fix Check], locked: false, comment: 'Contract bulk unlock' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :rule, :toast
      expect(body['rule']['id']).to eq(rule.id)
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end
  end

  # ── GET /search/rules ──

  describe 'GET /search/rules (JSON)' do
    it 'returns rules as compact 4-element tuples matching test data' do
      get '/search/rules', params: { q: rule.version }, headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rules
      expect(body['rules']).to be_an(Array)
      expect(body.keys).to contain_exactly('rules')
      expect(body['rules']).not_to be_empty, "Expected search for '#{rule.version}' to find at least one rule"

      first_tuple = body['rules'].first
      expect(first_tuple).to be_an(Array)
      expect(first_tuple.size).to eq(4)
    end
  end
end
