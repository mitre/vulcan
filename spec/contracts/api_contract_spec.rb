# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'API endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:admin) { create(:user, admin: true) }

  describe 'GET /api/version (public, no auth required)' do
    it 'returns all 5 fields matching VersionResponse schema' do
      get '/api/version', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :name, :version, :rails, :ruby, :environment
      expect(body['name']).to eq('Vulcan')
      expect(body['version']).to be_a(String)
      expect(body['rails']).to eq(Rails.version)
      expect(body['ruby']).to eq(RUBY_VERSION)
      expect(body['environment']).to eq('test')
    end
  end

  describe 'GET /api/version (unauthenticated)' do
    it 'returns full VersionResponse without authentication (security: [] override)' do
      get '/api/version', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :name, :version, :rails, :ruby, :environment
      expect(body['name']).to eq('Vulcan')
      expect(body['rails']).to eq(Rails.version)
      expect(body['ruby']).to eq(RUBY_VERSION)
      expect(body['environment']).to eq('test')
    end
  end

  describe 'GET /api/search/global' do
    before { sign_in admin }

    let_it_be(:project) { create(:project, name: 'SearchTest Project') }

    it 'returns all 7 result arrays matching GlobalSearchResponse schema' do
      get '/api/search/global', params: { q: 'SearchTest' }, headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :projects, :components, :rules, :srgs, :stigs, :stig_rules, :srg_rules

      expect(body['projects']).to be_an(Array)
      expect(body['components']).to be_an(Array)
      expect(body['rules']).to be_an(Array)
      expect(body['srgs']).to be_an(Array)
      expect(body['stigs']).to be_an(Array)
      expect(body['stig_rules']).to be_an(Array)
      expect(body['srg_rules']).to be_an(Array)

      if body['projects'].any?
        project_result = body['projects'].first
        assert_fields_present project_result, :id, :name, :description, :components_count
      end
    end

    it 'returns all 7 empty arrays for short queries' do
      get '/api/search/global', params: { q: 'x' }, headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :projects, :components, :rules, :srgs, :stigs, :stig_rules, :srg_rules
      %w[projects components rules srgs stigs stig_rules srg_rules].each do |key|
        expect(body[key]).to eq([]), "Expected #{key} to be empty for short query"
      end
    end
  end

  describe 'GET /api/users/search' do
    before { sign_in admin }

    let_it_be(:project) { Project.first || create(:project) }
    let_it_be(:membership) do
      Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
        m.role = 'admin'
      end
    end

    it 'returns users array with id, name, email only' do
      get '/api/users/search',
          params: { q: 'Demo', membership_type: 'Project', membership_id: project.id },
          headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :users
      expect(body['users']).to be_an(Array)

      if body['users'].any?
        user_result = body['users'].first
        assert_fields_present user_result, :id, :name, :email
        assert_fields_absent user_result, :provider, :admin, :last_sign_in_at,
                             :failed_attempts, :locked_at
      end
    end

    it 'returns empty users array with correct wrapper for short queries' do
      get '/api/users/search',
          params: { q: 'x', membership_type: 'Project', membership_id: project.id },
          headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :users
      expect(body['users']).to eq([])
      expect(body.keys).to contain_exactly('users')
    end
  end
end
