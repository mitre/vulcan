# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SecurityRequirementsGuides', type: :request do
  let(:content_disposition_header) { 'Content-Disposition' }
  let!(:user) { create(:user, admin: true) }
  let(:user2) { create(:user) }
  let(:srg) { create(:security_requirements_guide) }

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /srgs/:id/export/:type' do
    it 'exports XCCDF XML for logged-in user' do
      sign_in user

      get "/srgs/#{srg.id}/export/xccdf"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('application/xml')
      expect(response.headers[content_disposition_header]).to include('.xml')
      expect(response.body).to eq(srg.xml)
    end

    it 'includes srg title in filename' do
      sign_in user

      get "/srgs/#{srg.id}/export/xccdf"

      filename = response.headers[content_disposition_header]
      expect(filename).to include(srg.title.tr(' ', '-'))
    end

    it 'returns error for unsupported export types' do
      sign_in user

      get "/srgs/#{srg.id}/export/inspec", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
      json = response.parsed_body
      expect(json['toast']['message']).to include('Unsupported')
    end

    it 'exports CSV for logged-in user' do
      sign_in user
      create(:srg_rule, security_requirements_guide: srg)

      get "/srgs/#{srg.id}/export/csv"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers[content_disposition_header]).to include('.csv')
    end

    it 'includes srg title in CSV filename' do
      sign_in user

      get "/srgs/#{srg.id}/export/csv"

      filename = response.headers[content_disposition_header]
      expect(filename).to include(srg.title.tr(' ', '-'))
    end

    it 'respects column selection for CSV export' do
      sign_in user
      create(:srg_rule, security_requirements_guide: srg)

      get "/srgs/#{srg.id}/export/csv", params: { columns: 'rule_id,version' }

      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to eq(['Rule ID', 'SRG ID'])
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
