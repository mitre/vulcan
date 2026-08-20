# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Settings endpoint contract', type: :request do
  include OpenAPIContractHelpers

  before { Rails.application.reload_routes! }

  describe 'GET /api/settings (public, no auth required)' do
    it 'matches SettingsResponse schema' do
      get '/api/settings', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :banner, :consent, :local_login,
                            :user_registration, :ldap, :oidc, :smtp, :password, :lockout
      expect(body['banner']['enabled']).to be(true).or be(false)
      expect(body['password']['min_length']).to be_a(Integer)
    end
  end
end
