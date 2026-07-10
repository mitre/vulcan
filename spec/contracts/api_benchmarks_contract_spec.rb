# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Benchmark latest endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:srg) do
    create(:security_requirements_guide,
           title: 'Web Server Security Requirements Guide',
           srg_id: 'Web_Server_SRG', version: 'V4R4',
           name: 'Web Server SRG - Ver 4, Rel 4')
  end
  let_it_be(:stig) do
    create(:stig, :skip_rules,
           title: 'Red Hat Enterprise Linux 9 Security Technical Implementation Guide',
           stig_id: 'RHEL_9_STIG', version: 'V2R7',
           name: 'RHEL 9 STIG - Ver 2, Rel 7')
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/srgs/latest' do
    it 'matches BenchmarkLatestResponse schema' do
      get '/api/srgs/latest', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows
      row = body['rows'].find { |r| r['srg_id'] == 'Web_Server_SRG' }
      expect(row['version']).to eq('V4R4')
    end

    it 'matches the schema with a query filter applied' do
      get '/api/srgs/latest', params: { q: 'Web Server' }, headers: json_headers
      body = validate_and_parse!

      expect(body['rows'].pluck('srg_id')).to eq(['Web_Server_SRG'])
    end
  end

  describe 'GET /api/stigs/latest' do
    it 'matches BenchmarkLatestResponse schema' do
      get '/api/stigs/latest', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows
      row = body['rows'].find { |r| r['stig_id'] == 'RHEL_9_STIG' }
      expect(row['version']).to eq('V2R7')
    end
  end

  describe 'GET /api/components/latest' do
    let_it_be(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion
    let_it_be(:user) { create(:user) }
    let_it_be(:component) do
      create(:component, :skip_rules, :released_component,
             prefix: 'RHEL-09', name: 'RHEL 9 Hardened Baseline', title: 'Red Hat Enterprise Linux 9',
             version: 2, release: 1)
    end

    it 'matches ComponentLatestResponse schema' do
      sign_in user

      get '/api/components/latest', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows
      row = body['rows'].find { |r| r['prefix'] == 'RHEL-09' }
      expect(row['version']).to eq(2)
      expect(row['release']).to eq(1)
    end

    it 'matches the documented 401 shape when unauthenticated' do
      get '/api/components/latest', headers: json_headers
      body = validate_and_parse!(expected_status: :unauthorized)

      expect(body['error']).to eq('Unauthorized')
    end
  end
end
