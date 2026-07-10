# frozen_string_literal: true

require 'rails_helper'

# Self-delete (Devise registrations#destroy) hardening requirements:
# - Re-authentication with current_password for local-credential users
#   (OWASP ASVS 3.7.1 — matches the unlink_identity pattern)
# - Provider-managed / auto-password users delete without a password
#   (the identity provider owns their re-authentication)
# - The last system admin can never self-delete
# - Deleting must not 500 when session limits are enabled
#   (devise-security logout hook vs destroyed record)
RSpec.describe 'Devise Registrations self-delete', openapi: false do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }

  let(:json_headers) { { 'Accept' => 'application/json' } }
  let(:password) { 'S3lfD3l3te!#Pass' }

  describe 'local-credential user' do
    let!(:user) { create(:user, password: password) }

    before { sign_in user }

    it 'deletes the account with the correct current_password' do
      delete '/users',
             params: { user: { current_password: password } },
             headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Account deleted.')
      expect(User.exists?(user.id)).to be(false)
    end

    it 'rejects deletion with a wrong password and increments failed_attempts' do
      delete '/users',
             params: { user: { current_password: 'WrongP@ssw0rd!!' } },
             headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message')).to include(
        'Incorrect password. Please enter your current password to delete your account.'
      )
      expect(User.exists?(user.id)).to be(true)
      expect(user.reload.failed_attempts).to eq(1)
    end

    it 'rejects deletion with no password' do
      delete '/users', headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(user.id)).to be(true)
    end

    it 'returns locked status when repeated wrong passwords lock the account mid-request' do
      # maximum_attempts is 3 in test config — the third wrong attempt trips
      # the lock inside valid_for_authentication? and the response reports it.
      2.times do
        delete '/users',
               params: { user: { current_password: 'WrongP@ssw0rd!!' } },
               headers: json_headers, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      delete '/users',
             params: { user: { current_password: 'WrongP@ssw0rd!!' } },
             headers: json_headers, as: :json

      expect(response).to have_http_status(:locked)
      expect(response.parsed_body.dig('toast', 'message').join).to include('locked')
      expect(User.exists?(user.id)).to be(true)
      expect(user.reload.access_locked?).to be(true)
    end
  end

  describe 'provider-managed user' do
    let!(:sso_user) { create(:ldap_user) }

    before { sign_in sso_user }

    it 'deletes without a password — the provider owns re-authentication' do
      delete '/users', headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Account deleted.')
      expect(User.exists?(sso_user.id)).to be(false)
    end
  end

  describe 'auto-password user (SSO-created local record)' do
    let!(:auto_user) do
      create(:user).tap { |u| u.update_column(:password_automatically_set, true) }
    end

    before { sign_in auto_user }

    it 'deletes without a password' do
      delete '/users', headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(User.exists?(auto_user.id)).to be(false)
    end
  end

  describe 'last system admin' do
    it 'blocks self-delete when no other admin exists' do
      # anchor_admin is the ONLY admin in this group
      sign_in anchor_admin

      delete '/users',
             params: { user: { current_password: anchor_admin.password } },
             headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message').join).to include('only administrator')
      expect(User.exists?(anchor_admin.id)).to be(true)
    end

    it 'allows an admin to self-delete when another admin exists' do
      second_admin = create(:user, :admin, password: password)
      sign_in second_admin

      delete '/users',
             params: { user: { current_password: password } },
             headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(User.exists?(second_admin.id)).to be(false)
      expect(User.exists?(anchor_admin.id)).to be(true)
    end
  end
end
