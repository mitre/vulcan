# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password change for SSO-created users' do
  before { Rails.application.reload_routes! }

  let(:password) { 'S3cure!#TestPas1' }

  describe 'SSO user (password_automatically_set: true)' do
    let(:sso_user) do
      create(:user, provider: 'okta', uid: 'okta-pw-test',
                    password: Devise.friendly_token,
                    password_automatically_set: true)
    end

    before { sign_in sso_user }

    it 'can set a new password without providing current password' do
      put '/users', params: {
        user: { password: password, password_confirmation: password }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(sso_user.reload.valid_password?(password)).to be(true)
      expect(sso_user.password_automatically_set).to be(false)
    end
  end

  describe 'local user (password_automatically_set: false)' do
    let(:local_user) do
      create(:user, password: password, password_confirmation: password,
                    password_automatically_set: false)
    end

    before { sign_in local_user }

    it 'still requires current password to change password' do
      new_pw = 'N3wS3cure!#Pass2'
      put '/users', params: {
        user: { password: new_pw, password_confirmation: new_pw }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'succeeds with correct current password' do
      new_pw = 'N3wS3cure!#Pass2'
      put '/users', params: {
        user: { password: new_pw, password_confirmation: new_pw,
                current_password: password }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(local_user.reload.valid_password?(new_pw)).to be(true)
    end
  end
end
