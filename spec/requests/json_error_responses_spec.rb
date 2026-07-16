# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: JSON 4xx bodies are never empty — every not-found answer is
# an RFC 9457 problem body (application/problem+json) with the stable
# not_found type, so API clients always get a parseable, explained error.
RSpec.describe 'JSON error responses' do
  include Devise::Test::IntegrationHelpers

  let_it_be(:admin) { create(:user, admin: true) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  def expect_not_found_problem
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq('application/problem+json')
    body = response.parsed_body
    expect(body['type']).to eq('/api/docs/errors#not_found')
    expect(body['title']).to eq('Not found')
    expect(body['status']).to eq(404)
    expect(body['detail']).to eq('The requested resource could not be found.')
  end

  describe '404 Not Found' do
    it 'returns the problem body for a missing project' do
      get '/projects/999999', headers: { 'Accept' => 'application/json' }
      expect_not_found_problem
    end

    it 'returns the problem body for a missing rule' do
      get '/rules/999999', headers: { 'Accept' => 'application/json' }
      expect_not_found_problem
    end

    it 'returns the problem body for a missing SRG' do
      get '/srgs/999999', headers: { 'Accept' => 'application/json' }
      expect_not_found_problem
    end

    it 'returns the problem body for a missing STIG' do
      get '/stigs/999999', headers: { 'Accept' => 'application/json' }
      expect_not_found_problem
    end

    it 'returns the problem body for missing review responses' do
      get '/reviews/999999/responses', headers: { 'Accept' => 'application/json' }
      expect_not_found_problem
    end
  end

  describe '404 via token auth' do
    it 'returns the problem body for a missing resource via API token' do
      token = create(:personal_access_token, user: admin, scopes: %w[read])

      get '/rules/999999',
          headers: { 'Authorization' => "Token #{token.raw_token}", 'Accept' => 'application/json' }

      expect_not_found_problem
    end
  end
end
