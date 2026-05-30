# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Personal Access Tokens endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:admin) { create(:user, admin: true, password: 'ADMin99!!testpw') }

  before { sign_in admin }

  # ── GET /personal_access_tokens ──

  describe 'GET /personal_access_tokens (JSON)' do
    it 'returns personal_access_tokens array matching schema' do
      create(:personal_access_token, user: admin, name: 'Contract List Test')

      get '/personal_access_tokens', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :personal_access_tokens
      expect(body['personal_access_tokens']).to be_an(Array)
      expect(body['personal_access_tokens']).not_to be_empty

      token = body['personal_access_tokens'].first
      assert_fields_present token, :id, :name, :token_prefix, :scopes, :created_at
      assert_fields_absent token, :token_digest
    end
  end

  # ── POST /personal_access_tokens ──

  describe 'POST /personal_access_tokens (JSON)' do
    it 'returns raw token + PersonalAccessTokenSummary on creation' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'Contract Create Test',
               scopes: %w[read write],
               expires_at: 30.days.from_now.to_date.to_s,
               current_password: 'ADMin99!!testpw'
             }
           },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :created)

      assert_fields_present body, :token, :personal_access_token
      expect(body['token']).to start_with('vulcan_')
      expect(body['personal_access_token']['name']).to eq('Contract Create Test')
      expect(body['personal_access_token']['scopes']).to eq(%w[read write])
      assert_fields_absent body['personal_access_token'], :token_digest
    end

    it 'returns 401 with incorrect password' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'Bad pw',
               scopes: %w[read],
               current_password: 'wrong'
             }
           },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── DELETE /personal_access_tokens/:id ──

  describe 'DELETE /personal_access_tokens/:id (JSON)' do
    it 'returns ToastResponse on revocation' do
      token = create(:personal_access_token, user: admin, name: 'Contract Revoke')

      delete "/personal_access_tokens/#{token.id}", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(token.reload.revoked_at).to be_present
    end
  end

  # ── DELETE /personal_access_tokens/:id/admin_revoke ──

  describe 'DELETE /personal_access_tokens/:id/admin_revoke (JSON)' do
    let_it_be(:other_user) { create(:user) }

    it 'returns ToastResponse on admin revocation' do
      other_token = create(:personal_access_token, user: other_user, name: 'Admin Revoke Contract')

      delete "/personal_access_tokens/#{other_token.id}/admin_revoke",
             params: { audit_comment: 'Contract test admin revoke' },
             headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(other_token.reload.revoked_at).to be_present
    end
  end
end
