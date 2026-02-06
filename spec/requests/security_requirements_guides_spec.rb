# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SecurityRequirementsGuides', type: :request do
  before do
    Rails.application.reload_routes!
  end

  let!(:user) { create(:user, admin: true) }
  let(:user2) { create(:user) }
  let(:srg) { create(:security_requirements_guide) }

  describe 'GET /srgs/:id/export/:type' do
    it 'exports XCCDF XML for logged-in user' do
      sign_in user

      get "/srgs/#{srg.id}/export/xccdf"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('application/xml')
      expect(response.headers['Content-Disposition']).to include('.xml')
      expect(response.body).to eq(srg.xml)
    end

    it 'includes srg title in filename' do
      sign_in user

      get "/srgs/#{srg.id}/export/xccdf"

      filename = response.headers['Content-Disposition']
      expect(filename).to include(srg.title.tr(' ', '-'))
    end

    it 'returns error for unsupported export types' do
      sign_in user

      get "/srgs/#{srg.id}/export/csv", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
      json = response.parsed_body
      expect(json['toast']['message']).to include('Unsupported')
    end

    it 'requires authentication' do
      get "/srgs/#{srg.id}/export/xccdf"

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not require admin access' do
      sign_in user2

      get "/srgs/#{srg.id}/export/xccdf"

      expect(response).to have_http_status(:ok)
    end

    it 'validates ahead of time with JSON format' do
      sign_in user

      get "/srgs/#{srg.id}/export/xccdf", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('ok')
    end

    it 'returns error for non-existent srg' do
      sign_in user

      get '/srgs/99999/export/xccdf'

      # ApplicationController rescues StandardError (including RecordNotFound)
      expect(response).not_to have_http_status(:ok)
    end
  end
end
