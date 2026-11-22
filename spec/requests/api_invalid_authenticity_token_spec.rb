# frozen_string_literal: true

require 'rails_helper'

# Requirement: an /api/* endpoint answers a failed authenticity check with the
# 422 invalid_authenticity_token problem whatever Accept header the caller
# sends. curl sends Accept: */* by default and many HTTP clients send none, so
# a caller must never be handed an HTML flash and a 302 to the home page.
# HTML pages keep their flash and redirect.
RSpec.describe 'Failed authenticity check' do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  # config/environments/test.rb disables forgery protection suite-wide, so
  # these examples turn it on for their duration.
  around do |example|
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, password: 'S3cure!#Pass999') }

  let(:login_body) { { email: user.email, password: 'S3cure!#Pass999' }.to_json }

  describe 'on an API endpoint' do
    {
      'Accept: */*' => { 'Accept' => '*/*' },
      'no Accept header' => {},
      'Accept: application/json' => { 'Accept' => 'application/json' }
    }.each do |label, accept|
      it "answers 422 problem+json with #{label}" do
        post '/api/auth/login', params: login_body, headers: accept.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq('application/problem+json')
        expect(response.headers['Location']).to be_nil
        expect(response.parsed_body).to include(
          'type' => '/docs/api/errors#invalid_authenticity_token',
          'title' => 'Invalid authenticity token',
          'status' => 422
        )
        expect(response.parsed_body['detail']).to include('GET /api/auth/csrf')
      end
    end

    it 'leaves the caller signed out' do
      post '/api/auth/login', params: login_body, headers: { 'Accept' => '*/*', 'Content-Type' => 'application/json' }

      get '/api/auth/me', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'on an HTML page' do
    before { sign_in user }

    it 'keeps the flash alert and the redirect for a browser form post' do
      post '/projects', params: { project: { name: 'No token' } }, headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to eq('Your form session expired. Reload the page and try again.')
    end
  end
end
