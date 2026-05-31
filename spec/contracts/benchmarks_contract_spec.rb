# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Benchmarks endpoint contracts (SRGs + STIGs)', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:stig) { Stig.first || create(:stig) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # ── GET /srgs ──

  describe 'GET /srgs (JSON)' do
    it 'returns SrgSummary array with all fields from seed data' do
      get '/srgs', headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body.size).to be >= 1

      first_srg = body.find { |s| s['id'] == srg.id }
      expect(first_srg).not_to be_nil, "SRG #{srg.id} not found in response"
      assert_fields_present first_srg, :id, :srg_id, :name, :title, :version, :release_date, :severity_counts
      expect(first_srg['srg_id']).to eq(srg.srg_id)
      expect(first_srg['name']).to eq(srg.name)
      expect(first_srg['severity_counts']).to be_a(Hash)
      assert_fields_present first_srg['severity_counts'], :high, :medium, :low

      assert_fields_absent first_srg, :stig_id, :benchmark_date, :xml
    end
  end

  # ── GET /srgs/:id ──

  describe 'GET /srgs/:id (JSON)' do
    it 'returns SrgDetailResponse with nested srg_rules array' do
      get "/srgs/#{srg.id}", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :id, :srg_id, :name, :title, :version, :release_date, :severity_counts, :srg_rules
      expect(body['id']).to eq(srg.id)
      expect(body['srg_id']).to eq(srg.srg_id)
      expect(body['srg_rules']).to be_an(Array)
      expect(body['srg_rules'].size).to be >= 1

      assert_fields_absent body, :xml, :stig_id, :benchmark_date

      first_rule = body['srg_rules'].first
      assert_fields_present first_rule, :id, :rule_id, :title, :version, :rule_severity
      assert_fields_present first_rule, :disa_rule_descriptions_attributes, :checks_attributes
    end
  end

  # ── DELETE /srgs/:id ──

  describe 'DELETE /srgs/:id (JSON)' do
    let!(:deletable_srg) do
      parsed = Xccdf::Benchmark.parse(srg.xml)
      new_srg = SecurityRequirementsGuide.from_mapping(parsed)
      new_srg.srg_id = "Deletable_SRG_#{SecureRandom.hex(4)}"
      new_srg.xml = srg.xml
      new_srg.parsed_benchmark = parsed
      new_srg.save!
      new_srg
    end

    it 'returns ToastResponse on success' do
      delete "/srgs/#{deletable_srg.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to include('removed')
    end
  end

  # ── GET /stigs ──

  describe 'GET /stigs (JSON)' do
    it 'returns StigSummary array with all fields from seed data' do
      get '/stigs', headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body.size).to be >= 1

      first_stig = body.find { |s| s['id'] == stig.id }
      expect(first_stig).not_to be_nil, "STIG #{stig.id} not found in response"
      assert_fields_present first_stig, :id, :stig_id, :name, :title, :version, :benchmark_date, :severity_counts
      expect(first_stig['stig_id']).to eq(stig.stig_id)
      expect(first_stig['name']).to eq(stig.name)
      expect(first_stig['severity_counts']).to be_a(Hash)

      assert_fields_absent first_stig, :srg_id, :release_date, :xml
    end
  end

  # ── GET /stigs/:id ──

  describe 'GET /stigs/:id (JSON)' do
    it 'returns StigDetailResponse with description and nested stig_rules' do
      get "/stigs/#{stig.id}", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :id, :stig_id, :name, :title, :version, :benchmark_date,
                            :severity_counts, :description, :stig_rules
      expect(body['id']).to eq(stig.id)
      expect(body['stig_id']).to eq(stig.stig_id)
      expect(body['stig_rules']).to be_an(Array)
      expect(body['stig_rules'].size).to be >= 1

      assert_fields_absent body, :xml, :srg_id, :release_date

      first_rule = body['stig_rules'].first
      assert_fields_present first_rule, :id, :rule_id, :title, :version, :rule_severity, :srg_id
      assert_fields_present first_rule, :disa_rule_descriptions_attributes, :checks_attributes
    end
  end

  # ── DELETE /stigs/:id ──

  describe 'DELETE /stigs/:id (JSON)' do
    let!(:deletable_stig) do
      new_stig = Stig.new(
        stig_id: "Deletable_STIG_#{SecureRandom.hex(4)}",
        name: 'Deletable Test STIG',
        title: 'Deletable Test STIG',
        version: 'V1R1',
        benchmark_date: Time.zone.today,
        xml: stig.xml
      )
      new_stig.save!
      new_stig
    end

    it 'returns ToastResponse on success' do
      delete "/stigs/#{deletable_stig.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to include('removed')
    end
  end
end
