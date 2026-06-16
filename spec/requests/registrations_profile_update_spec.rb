# frozen_string_literal: true

require 'rails_helper'

# Profile updates via PUT /users (Users::RegistrationsController#update).
#
# POLICY (Devise design + OWASP ASVS re-auth-for-sensitive-changes +
# GitHub/GitLab/Discourse practice):
# - Non-sensitive fields (name, slack_user_id): no password required.
# - Email is the login identifier — changing it REQUIRES the current
#   password, server-enforced.
# - With email confirmation enabled (VULCAN_ENABLE_EMAIL_CONFIRMATION),
#   Devise reconfirmable holds the new address in unconfirmed_email until
#   the confirmation link is followed; with it disabled (no SMTP), the
#   change applies immediately — the accepted fallback.
# - Provider-managed users (OIDC/LDAP): the IdP owns email — the param is
#   ignored; non-sensitive fields still save without a password.
RSpec.describe 'Profile updates' do
  before do
    Rails.application.reload_routes!
  end

  let(:password) { generate(:password) }
  let(:user) { create(:user, password: password) }

  def put_profile(attrs)
    put '/users', params: { user: attrs }, as: :json
  end

  context 'when changing non-sensitive fields as a local user' do
    before { sign_in user }

    it 'updates the name without a current password' do
      put_profile(name: 'Renamed User')

      expect(response).to have_http_status(:ok)
      expect(user.reload.name).to eq('Renamed User')
      expect(response.parsed_body.dig('toast', 'title')).to eq('Account updated.')
    end

    it 'updates the slack_user_id without a current password' do
      put_profile(name: user.name, slack_user_id: 'U123456')

      expect(response).to have_http_status(:ok)
      expect(user.reload.slack_user_id).to eq('U123456')
    end
  end

  context 'when changing the email as a local user' do
    before { sign_in user }

    it 'rejects the change without a current password' do
      put_profile(name: user.name, email: 'new-address@example.com')

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.email).not_to eq('new-address@example.com')
      expect(response.parsed_body.dig('toast', 'title')).to eq('Could not update profile.')
      expect(response.parsed_body.dig('toast', 'message')).to include("Current password can't be blank")
    end

    it 'rejects the change with a wrong current password' do
      put_profile(name: user.name, email: 'new-address@example.com', current_password: 'wrong-password')

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.email).not_to eq('new-address@example.com')
      expect(response.parsed_body.dig('toast', 'message')).to include('Current password is invalid')
    end

    it 'applies the change immediately with the correct password when email confirmation is off' do
      put_profile(name: user.name, email: 'new-address@example.com', current_password: password)

      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq('new-address@example.com')
      expect(user.unconfirmed_email).to be_nil
      expect(response.parsed_body.dig('toast', 'message')).to eq(['Profile updated successfully.'])
    end

    it 'holds the change in unconfirmed_email when email confirmation is on' do
      allow(Settings.local_login).to receive(:email_confirmation).and_return(true)

      put_profile(name: user.name, email: 'new-address@example.com', current_password: password)

      expect(response).to have_http_status(:ok)
      expect(user.reload.email).not_to eq('new-address@example.com')
      expect(user.unconfirmed_email).to eq('new-address@example.com')
      expect(response.parsed_body.dig('toast', 'message'))
        .to include(a_string_including('confirmation link has been sent to new-address@example.com'))
    end

    it 'treats an unchanged email value as a non-sensitive save (no password needed)' do
      put_profile(name: 'Renamed Again', email: user.email)

      expect(response).to have_http_status(:ok)
      expect(user.reload.name).to eq('Renamed Again')
    end
  end

  context 'when the user is provider-managed (OIDC/LDAP)' do
    let(:user) { create(:user, provider: 'oidc', uid: 'okta-abc') }

    before { sign_in user }

    it 'ignores email changes — the identity provider owns the email' do
      original_email = user.email
      put_profile(name: user.name, email: 'hijack@example.com')

      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq(original_email)
      expect(user.unconfirmed_email).to be_nil
    end

    it 'still updates non-sensitive fields without a password' do
      put_profile(name: 'Provider User Renamed')

      expect(response).to have_http_status(:ok)
      expect(user.reload.name).to eq('Provider User Renamed')
    end
  end
end
