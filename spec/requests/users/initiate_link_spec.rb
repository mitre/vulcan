# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::RegistrationsController#initiate_link' do
  before do
    Rails.application.reload_routes!
  end

  let(:password) { 'S3cure!#TestPas1' }
  let(:local_user) do
    create(:user, email: 'local@example.com', password: password,
                  password_confirmation: password, provider: nil, uid: nil)
  end

  describe 'POST /users/initiate_link' do
    context 'when OIDC is enabled and user has no linked provider' do
      before do
        sign_in local_user
        allow(Settings.oidc).to receive(:enabled).and_return(true)
      end

      it 'redirects to OmniAuth provider path' do
        post '/users/initiate_link', params: { provider: 'oidc' }

        expect(response).to have_http_status(:found)
        expect(response.location).to include('/users/auth/oidc')
      end
    end

    context 'when user already has a linked provider (JSON)' do
      before do
        local_user.update_columns(provider: 'oidc', uid: 'already-linked')
        sign_in local_user
      end

      it 'returns 422 with error' do
        post '/users/initiate_link',
             params: { provider: 'oidc' },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message')).to include(match(/already has a linked identity/i))
      end
    end

    context 'when user already has a linked provider (HTML)' do
      before do
        local_user.update_columns(provider: 'oidc', uid: 'already-linked')
        sign_in local_user
      end

      it 'redirects with flash alert' do
        post '/users/initiate_link', params: { provider: 'oidc' }

        expect(response).to have_http_status(:found)
        expect(flash.alert).to match(/already has a linked identity/i)
      end
    end

    context 'when not authenticated' do
      it 'redirects (Devise auth gate)' do
        post '/users/initiate_link', params: { provider: 'oidc' }

        expect(response).to have_http_status(:found)
      end
    end

    context 'when provider is not enabled (JSON)' do
      before do
        sign_in local_user
        allow(Settings.oidc).to receive(:enabled).and_return(false)
        allow(Settings.ldap).to receive(:enabled).and_return(false)
      end

      it 'returns 422 with error' do
        post '/users/initiate_link',
             params: { provider: 'oidc' },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message')).to include(match(/not enabled/i))
      end
    end
  end
end
