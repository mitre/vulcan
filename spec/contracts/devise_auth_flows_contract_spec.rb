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

  describe 'DELETE /users (self-delete)' do
    it 'matches ToastResponse schema and destroys the account' do
      doomed = create(:user, password: 'S3lfD3l3te!#Pass')
      sign_in doomed

      delete '/users',
             params: { user: { current_password: 'S3lfD3l3te!#Pass' } },
             headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Account deleted.')
      expect(body.dig('toast', 'message')).to eq(['Account deleted successfully.'])
      expect(User.exists?(doomed.id)).to be(false)
    end

    it 'matches ToastResponse schema on wrong-password rejection' do
      keeper = create(:user, password: 'S3lfD3l3te!#Pass')
      sign_in keeper

      delete '/users',
             params: { user: { current_password: 'WrongP@ssw0rd!!' } },
             headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to eq('Cannot delete account.')
      expect(User.exists?(keeper.id)).to be(true)
    end

    it 'matches ToastResponse schema on last-admin rejection' do
      sign_in anchor_admin

      delete '/users', headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'message').join).to include('only administrator')
      expect(User.exists?(anchor_admin.id)).to be(true)
    end

    it 'matches ToastResponse schema on sole-project-admin rejection' do
      blocked = create(:user, password: 'S3lfD3l3te!#Pass')
      orphan_risk = create(:project, name: 'Contract Orphan Project')
      create(:membership, user: blocked, membership: orphan_risk, role: 'admin')
      sign_in blocked

      delete '/users',
             params: { user: { current_password: 'S3lfD3l3te!#Pass' } },
             headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'message').join)
        .to include("You are the only admin of: 'Contract Orphan Project'")
      expect(User.exists?(blocked.id)).to be(true)
    end

    it 'matches ToastResponse schema on mid-request lockout (423)' do
      lockable = create(:user, password: 'S3lfD3l3te!#Pass')
      sign_in lockable

      2.times do
        delete '/users', params: { user: { current_password: 'WrongP@ssw0rd!!' } },
                         headers: json_headers, as: :json
      end
      delete '/users', params: { user: { current_password: 'WrongP@ssw0rd!!' } },
                       headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :locked)

      expect(body.dig('toast', 'message').join).to include('locked')
      expect(User.exists?(lockable.id)).to be(true)
    end
  end
end
