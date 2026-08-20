# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Link Existing Account on cold-match' do
  let(:password) { 'S3cure!#TestPas1' }
  let(:provider_name) { Devise.omniauth_providers.first }
  let!(:local_user) do
    create(:user, email: 'local-link@example.com', password: password,
                  password_confirmation: password, provider: nil, uid: nil)
  end

  before do
    Rails.application.reload_routes!
    allow(Settings).to receive(:auto_link_user).and_return(false)
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.each_key { |k| OmniAuth.config.mock_auth[k] = nil }
  end

  describe 'conflict handler redirects with link_pending' do
    it 'redirects to sign-in with link_pending=true on cold-match' do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider_name] = OmniAuth::AuthHash.new(
        provider: provider_name.to_s, uid: 'cold-uid',
        info: { email: local_user.email, name: 'Cold Match' },
        credentials: { id_token: 'fake' }, extra: { raw_info: {} }
      )
      post "/users/auth/#{provider_name}"
      follow_redirect!

      expect(response.location).to include('link_pending=true')
    end
  end

  describe 'POST /users/complete_link' do
    it 'rejects when no pending link is in the session' do
      post '/users/complete_link', params: { current_password: password }

      expect(response).to redirect_to(new_user_session_path)
    end

    # Full complete_link integration (session persistence across OmniAuth redirects)
    # is verified via Playwright live test — ActiveRecord session store + OmniAuth
    # mock redirects don't preserve session in RSpec request specs.
  end

  describe 'User#link_identity! (model layer — the core of complete_link)' do
    it 'creates an identity when called with valid args' do
      local_user.link_identity!(provider: 'login_gov', uid: 'model-test-uid',
                                email: local_user.email, audit_reason: 'complete_link test')

      expect(local_user.identities.find_by(provider: 'login_gov').uid).to eq('model-test-uid')
    end

    it 'refuses when (provider, uid) belongs to another user' do
      other = create(:user, email: 'other@example.com')
      create(:identity, user: other, provider: 'login_gov', uid: 'taken')

      expect do
        local_user.link_identity!(provider: 'login_gov', uid: 'taken', email: local_user.email)
      end.to raise_error(User::ProviderConflictError)
    end
  end
end
