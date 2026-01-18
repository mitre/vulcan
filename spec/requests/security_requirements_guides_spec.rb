# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SecurityRequirementsGuides' do
  before do
    Rails.application.reload_routes!
  end

  let(:srg) { create(:security_requirements_guide) }
  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }

  describe 'GET /srgs' do
    let!(:srg1) { create(:security_requirements_guide, title: 'First SRG') }
    let!(:srg2) { create(:security_requirements_guide, title: 'Second SRG') }

    context 'when authenticated' do
      before { sign_in regular_user }

      it 'returns list of SRGs as JSON' do
        get '/srgs', headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to be_an(Array)
        expect(json.length).to be >= 2
      end

      it 'includes expected fields in response' do
        get '/srgs', headers: { 'Accept' => 'application/json' }

        json = response.parsed_body
        srg_item = json.find { |s| s['id'] == srg1.id }
        expect(srg_item).to include(
          'id' => srg1.id,
          'srg_id' => srg1.srg_id,
          'title' => 'First SRG',
          'version' => srg1.version
        )
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get '/srgs'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /srgs/:id' do
    context 'when authenticated' do
      before { sign_in regular_user }

      it 'returns SRG details as JSON' do
        get "/srgs/#{srg.id}", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(srg.id)
        expect(json['title']).to eq(srg.title)
      end

      it 'includes SRG rules in response' do
        get "/srgs/#{srg.id}", headers: { 'Accept' => 'application/json' }

        json = JSON.parse(response.body)
        expect(json).to have_key('srg_rules')
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get "/srgs/#{srg.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /srgs' do
    let(:xml_file) { File.read('./spec/fixtures/files/U_Web_Server_V2R3_Manual-xccdf.xml') }

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'creates a new SRG from uploaded file' do
        temp_file = Tempfile.new(['test_srg', '.xml'])
        temp_file.write(xml_file)
        temp_file.rewind

        file = Rack::Test::UploadedFile.new(temp_file.path, 'application/xml')

        expect do
          post '/srgs', params: { file: file }
        end.to change(SecurityRequirementsGuide, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['toast']).to include('Successfully created SRG')

        temp_file.close
        temp_file.unlink
      end
    end

    context 'when authenticated as regular user' do
      before { sign_in regular_user }

      it 'denies access' do
        temp_file = Tempfile.new(['test_srg', '.xml'])
        temp_file.write(xml_file)
        temp_file.rewind

        file = Rack::Test::UploadedFile.new(temp_file.path, 'application/xml')

        expect do
          post '/srgs', params: { file: file }
        end.not_to change(SecurityRequirementsGuide, :count)

        temp_file.close
        temp_file.unlink
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        post '/srgs', params: { file: nil }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'DELETE /srgs/:id' do
    let!(:srg_to_delete) { create(:security_requirements_guide) }

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'destroys the SRG' do
        expect do
          delete "/srgs/#{srg_to_delete.id}", as: :json
        end.to change(SecurityRequirementsGuide, :count).by(-1)

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['toast']).to include('Successfully removed SRG')
      end
    end

    context 'when authenticated as regular user' do
      before { sign_in regular_user }

      it 'denies access' do
        expect do
          delete "/srgs/#{srg_to_delete.id}", as: :json
        end.not_to change(SecurityRequirementsGuide, :count)
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        delete "/srgs/#{srg_to_delete.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
