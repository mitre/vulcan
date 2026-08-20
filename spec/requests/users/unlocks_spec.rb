# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devise Unlocks JSON', openapi: false do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:locked_user) { create(:user).tap { |u| u.lock_access!(send_instructions: false) } }

  let(:json_headers) { { 'Accept' => 'application/json' } }

  describe 'POST /users/unlock (request unlock instructions)' do
    it 'returns 200 with toast for locked user email' do
      post '/users/unlock',
           params: { user: { email: locked_user.email } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to be_present
    end

    it 'returns 200 with toast for unknown email (paranoid mode)' do
      post '/users/unlock',
           params: { user: { email: 'nonexistent@example.com' } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
    end

    it 'returns 422 when email param is blank' do
      post '/users/unlock',
           params: { user: { email: '' } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include("Email can't be blank")
    end
  end
end
