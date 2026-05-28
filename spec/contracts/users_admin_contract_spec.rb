# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'

RSpec.describe 'Users admin endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:target_user) { create(:user, name: 'Target User', email: 'target@example.com') }

  let(:vulcan_api) { OpenapiFirst::Test.definitions[:vulcan] }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  def validate_response!(req, resp)
    validated = vulcan_api.validate_response(req, resp, raise_error: false)
    return if validated.valid?

    raise "Contract violation on #{req.method} #{req.path} (#{resp.status}):\n#{validated.error.message}"
  end

  describe 'POST /users/admin_create' do
    it 'matches AdminCreateResponse schema with password provided' do
      post '/users/admin_create',
           params: { user: { name: 'New Admin', email: "newadmin-#{SecureRandom.hex(4)}@example.com",
                             admin: false, password: 'TestPassword1234!@#$' } },
           headers: json_headers, as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('toast')
      expect(body).to have_key('user')
      expect(body['user']).to have_key('id')
      expect(body['user']).to have_key('email')
    end

    it 'matches AdminCreateResponse schema without password (no SMTP)' do
      allow(Settings.smtp).to receive(:enabled).and_return(false)
      post '/users/admin_create',
           params: { user: { name: 'No Pass User', email: "nopass-#{SecureRandom.hex(4)}@example.com" } },
           headers: json_headers, as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('reset_url')
      expect(body['reset_url']).to include('/users/password/edit?reset_password_token=')
    end
  end

  describe 'POST /users/:id/send_password_reset' do
    it 'returns 422 when SMTP is disabled' do
      allow(Settings.smtp).to receive(:enabled).and_return(false)
      post "/users/#{target_user.id}/send_password_reset", headers: json_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'POST /users/:id/generate_reset_link' do
    it 'matches ResetLinkResponse schema' do
      post "/users/#{target_user.id}/generate_reset_link", headers: json_headers, as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('toast')
      expect(body).to have_key('reset_url')
      expect(body['reset_url']).to include('/users/password/edit?reset_password_token=')
      expect(body.dig('toast', 'variant')).to eq('success')
    end
  end

  describe 'POST /users/:id/set_password' do
    it 'matches ToastResponse schema on success' do
      post "/users/#{target_user.id}/set_password",
           params: { user: { password: 'NewPass1234!@#$' } },
           headers: json_headers, as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
    end

    it 'returns 422 when password is blank' do
      post "/users/#{target_user.id}/set_password",
           params: { user: { password: '' } },
           headers: json_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'POST /users/:id/lock' do
    it 'matches UserToastResponse schema' do
      post "/users/#{target_user.id}/lock", headers: json_headers, as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('toast')
      expect(body).to have_key('user')
      expect(body['user']['locked_at']).not_to be_nil
    end

    it 'returns 422 when locking self' do
      post "/users/#{admin.id}/lock", headers: json_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'POST /users/:id/unlock' do
    before { target_user.lock_access!(send_instructions: false) }

    it 'matches UserToastResponse schema' do
      post "/users/#{target_user.id}/unlock", headers: json_headers, as: :json
      expect(response).to have_http_status(:ok)
      validate_response!(request, response)

      body = response.parsed_body
      expect(body).to have_key('toast')
      expect(body).to have_key('user')
      expect(body['user']['locked_at']).to be_nil
    end
  end
end
