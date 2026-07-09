# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Devise auth flow contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, password: 'S3cure!#Pass999') }

  describe 'POST /users/password (request reset)' do
    it 'matches ToastResponse schema on success' do
      post '/users/password',
           params: { user: { email: user.email } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Instructions sent.')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end

    it 'matches ToastResponse schema on blank email error' do
      post '/users/password',
           params: { user: { email: '' } },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include("Email can't be blank")
    end
  end

  describe 'PUT /users/password (execute reset)' do
    it 'matches ToastResponse schema on success' do
      token = user.send_reset_password_instructions

      put '/users/password',
          params: { user: { reset_password_token: token,
                            password: 'N3wS3cure!#Pass',
                            password_confirmation: 'N3wS3cure!#Pass' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Password reset.')
    end

    it 'matches ToastResponse schema on invalid token' do
      put '/users/password',
          params: { user: { reset_password_token: 'badtoken',
                            password: 'N3wS3cure!#Pass',
                            password_confirmation: 'N3wS3cure!#Pass' } },
          headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include('Reset password token is invalid')
    end
  end

  describe 'GET /users/password/edit (validate reset token)' do
    it 'matches valid token schema' do
      token = user.send_reset_password_instructions

      get '/users/password/edit',
          params: { reset_password_token: token },
          headers: json_headers
      body = validate_and_parse!

      expect(body['valid']).to be(true)
      expect(body['minimum_password_length']).to eq(15)
    end

    it 'matches invalid token schema' do
      get '/users/password/edit',
          params: { reset_password_token: 'badtoken' },
          headers: json_headers
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body['valid']).to be(false)
      expect(body['error']).to eq('Reset token is invalid or has expired.')
    end
  end

  describe 'POST /users/confirmation (resend)' do
    it 'matches ToastResponse schema on success' do
      post '/users/confirmation',
           params: { user: { email: user.email } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Instructions sent.')
    end

    it 'matches ToastResponse schema on blank email error' do
      post '/users/confirmation',
           params: { user: { email: '' } },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'POST /users/unlock (request unlock)' do
    it 'matches ToastResponse schema on success' do
      locked = create(:user).tap { |u| u.lock_access!(send_instructions: false) }

      post '/users/unlock',
           params: { user: { email: locked.email } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Instructions sent.')
    end

    it 'matches ToastResponse schema on blank email error' do
      post '/users/unlock',
           params: { user: { email: '' } },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
    end
  end

  describe 'GET /users/edit (profile JSON)' do
    before { sign_in user }

    it 'matches CurrentUserResponse schema' do
      get '/users/edit', headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :id, :name, :email, :admin
      expect(body['id']).to eq(user.id)
      expect(body['email']).to eq(user.email)
    end
  end

  describe 'PUT /users (update profile)' do
    before { sign_in user }

    it 'matches ToastResponse schema' do
      put '/users',
          params: { user: { name: 'Updated Name' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Account updated.')
    end
  end
end
