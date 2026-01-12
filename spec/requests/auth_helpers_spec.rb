# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth Helper Pages', type: :request do
  before do
    Rails.application.reload_routes!

    # Stub Vite helpers to avoid asset compilation issues in tests
    allow_any_instance_of(ActionView::Base).to receive(:vite_javascript_tag).and_return('')
    allow_any_instance_of(ActionView::Base).to receive(:vite_client_tag).and_return('')
  end

  # These routes must be accessible without authentication
  # They serve the SPA shell which Vue Router then uses to show the appropriate auth forms

  describe 'GET /auth/confirmation' do
    it 'allows unauthenticated access' do
      get '/auth/confirmation'

      expect(response).to have_http_status(:success)
      expect(response.body).to match(/id=['"]app['"]/)
    end
  end

  describe 'GET /auth/unlock' do
    it 'allows unauthenticated access' do
      get '/auth/unlock'

      expect(response).to have_http_status(:success)
      expect(response.body).to match(/id=['"]app['"]/)
    end
  end

  describe 'GET /auth/reset-password' do
    it 'allows unauthenticated access' do
      get '/auth/reset-password'

      expect(response).to have_http_status(:success)
      expect(response.body).to match(/id=['"]app['"]/)
    end
  end
end
