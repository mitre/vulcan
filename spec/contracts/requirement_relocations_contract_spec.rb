# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Requirement relocations endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELCON', version: 'V1R1')
  end
  let_it_be(:project) { create(:project, name: 'Relocations Contract Project') }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: core_srg, prefix: 'RCON-00', name: 'Relocation Contract SRG',
                                    title: 'Relocation Contract SRG')
  end
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
      m.role = 'admin'
    end
  end

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  def authored_row(rule_id)
    create(:srg_rule, :authored, component: srg_component, rule_id: rule_id)
  end

  describe 'POST /rules/:ruleId/relocations (JSON)' do
    it 'returns ToastResponse when marking' do
      source = authored_row('920001')

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'CTR' } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Requirement marked for relocation.')
    end

    it 'returns ToastResponse 422 on a duplicate pending marker' do
      source = authored_row('920002')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR')

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'GPOS' } },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'GET /requirement_relocations (JSON)' do
    it 'returns RequirementRelocationSummary rows for the token' do
      source = authored_row('920003')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'RCON',
                                    requested_by: admin)

      get '/requirement_relocations', params: { target_technology_token: 'RCON' },
                                      headers: json_headers
      body = validate_and_parse!

      expect(body.size).to eq(1)
      row = body.first
      assert_fields_present row, :id, :source_rule_id, :target_technology_token,
                            :source_displayed_name, :component_id, :component_name,
                            :requested_by_name, :created_at
      expect(row['source_displayed_name']).to eq('RCON-00-920003')
      expect(row['component_id']).to eq(srg_component.id)
    end
  end

  describe 'DELETE /requirement_relocations/:id (JSON)' do
    it 'returns ToastResponse when un-marking' do
      source = authored_row('920004')
      record = RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR')

      delete "/requirement_relocations/#{record.id}", headers: json_headers
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(RequirementRelocation.exists?(record.id)).to be false
    end
  end

  describe 'POST /requirement_relocations/:id/dry_run (JSON)' do
    it 'returns RequirementRelocationDryRun for a valid preview' do
      source = authored_row('920005')
      record = RequirementRelocation.create!(source_rule: source, target_technology_token: 'RCTG')
      target = create(:component, :skip_rules, project: project, document_type: 'srg',
                                               based_on: core_srg, prefix: 'RCTG-00',
                                               name: 'Relocation Contract Target',
                                               title: 'Relocation Contract Target')

      post "/requirement_relocations/#{record.id}/dry_run",
           params: { target_component_id: target.id }, headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body['valid']).to be true
      expect(body['errors']).to eq([])
      expect(body['source_displayed_name']).to eq('RCON-00-920005')
      expect(body['would_tombstone_source']).to be true
    end
  end

  describe 'POST /requirement_relocations/:id/execute (JSON)' do
    it 'returns ToastResponse when executing the move' do
      source = authored_row('920006')
      record = RequirementRelocation.create!(source_rule: source, target_technology_token: 'RCTH')
      target = create(:component, :skip_rules, project: project, document_type: 'srg',
                                               based_on: core_srg, prefix: 'RCTH-00',
                                               name: 'Relocation Contract Target Two',
                                               title: 'Relocation Contract Target Two')

      post "/requirement_relocations/#{record.id}/execute",
           params: { target_component_id: target.id }, headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(record.reload.executed_at).to be_present
      expect(target.authored_srg_rules.count).to eq(1)
    end
  end
end
