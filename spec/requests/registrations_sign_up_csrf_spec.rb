# frozen_string_literal: true

require 'rails_helper'

# Sign-up that signs the new user in rotates the session's authenticity
# token, as every interactive sign-in does.
RSpec.describe 'User Registrations: CSRF token on sign-up' do
  include LoginHelpers

  before do
    Rails.application.reload_routes!
  end

  let(:user1) { build(:user, email: "registration-test-#{SecureRandom.hex(4)}@example.com") }

  context 'email confirmation disabled' do
    before do
      stub_local_login_setting(email_confirmation: false)
    end

    it 'rotates the session CSRF token when sign-up signs the new user in' do
      get '/api/auth/csrf', as: :json
      pre_sign_up_token = session[:_csrf_token]
      expect(pre_sign_up_token).to be_present

      post '/users', params: {
        user: {
          name: user1.name,
          email: user1.email,
          password: user1.password,
          password_confirmation: user1.password
        }
      }
      expect(response).to redirect_to(root_path)

      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:ok)

      get '/api/auth/csrf', as: :json
      expect(session[:_csrf_token]).to be_present
      expect(session[:_csrf_token]).not_to eq(pre_sign_up_token)
    end
  end
end
