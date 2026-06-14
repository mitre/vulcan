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

    context 'when user already has this provider linked (JSON)' do
      before do
        create(:identity, user: local_user, provider: 'oidc', uid: 'already-linked')
        sign_in local_user
      end

      it 'returns 422 with error' do
        post '/users/initiate_link',
             params: { provider: 'oidc' },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message')).to include(match(/already have a linked/i))
      end
    end

    context 'when user already has this provider linked (HTML)' do
      before do
        create(:identity, user: local_user, provider: 'oidc', uid: 'already-linked')
        sign_in local_user
      end

      it 'redirects with flash alert' do
        post '/users/initiate_link', params: { provider: 'oidc' }

        expect(response).to have_http_status(:found)
        expect(flash.alert).to match(/already have a linked/i)
      end
    end

    context 'when not authenticated' do
      it 'redirects (Devise auth gate)' do
        post '/users/initiate_link', params: { provider: 'oidc' }

        expect(response).to have_http_status(:found)
      end
    end

    context 'when provider is not registered (JSON)' do
      before { sign_in local_user }

      it 'returns 422 with error for an unregistered provider' do
        post '/users/initiate_link',
             params: { provider: 'nonexistent_provider' },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message')).to include(match(/not enabled/i))
      end
    end
  end
end
