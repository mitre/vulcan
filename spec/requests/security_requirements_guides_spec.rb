# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SecurityRequirementsGuides' do
  let(:content_disposition_header) { 'Content-Disposition' }

  let_it_be(:user) { create(:user, admin: true) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:srg) { create(:security_requirements_guide) }

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
      # Rails URL-encodes special characters in Content-Disposition header
      expected_title = ERB::Util.url_encode(srg.title.tr(' ', '-'))
      expect(filename).to include(expected_title)
    end

    it 'returns error for unsupported export types' do
      sign_in user

      get "/srgs/#{srg.id}/export/inspec", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
      json = response.parsed_body
      expect(json['toast']['message']).to include(a_string_including('Unsupported'))
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
      # Rails URL-encodes special characters in Content-Disposition header
      expected_title = ERB::Util.url_encode(srg.title.tr(' ', '-'))
      expect(filename).to include(expected_title)
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

  # ==========================================================================
  # REQUIREMENT: SRGs index should return optimized JSON (Jbuilder)
  # ==========================================================================
  describe 'GET /srgs (Jbuilder optimization)' do
    let!(:test_srg) { srg } # Ensure SRG exists in database

    before { sign_in user }

    it_behaves_like 'jbuilder index', {
      path: '/srgs',
      factory: :security_requirements_guide,
      required_fields: %w[id srg_id title version release_date],
      excluded_fields: %w[xml description srg_rules]
    }
  end

  describe 'GET /srgs — catalog currency fields (batched)' do
    let_it_be(:cur_v1) { create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-IDX', version: 'V1R1') }
    let_it_be(:cur_v2) { create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-CUR-IDX', version: 'V2R1') }

    before { sign_in user }

    it 'marks the newest release latest and points older releases at it' do
      get '/srgs.json'

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      v1 = body.find { |s| s['id'] == cur_v1.id }
      v2 = body.find { |s| s['id'] == cur_v2.id }
      expect(v2).to include('is_latest' => true, 'latest_available_version' => nil, 'latest_available_id' => nil)
      expect(v1).to include('is_latest' => false, 'latest_available_version' => 'V2R1', 'latest_available_id' => cur_v2.id)
    end
  end
end
