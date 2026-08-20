# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devise Confirmations JSON', openapi: false do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }

  let(:json_headers) { { 'Accept' => 'application/json' } }

  describe 'POST /users/confirmation (resend confirmation)' do
    it 'returns 200 with toast for any email (paranoid mode)' do
      post '/users/confirmation',
           params: { user: { email: 'anyone@example.com' } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to be_present
    end

    it 'returns 422 when email param is blank' do
      post '/users/confirmation',
           params: { user: { email: '' } },
           headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include("Email can't be blank")
    end
  end
end
