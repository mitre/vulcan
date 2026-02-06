# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stigs', type: :request do
  before do
    Rails.application.reload_routes!
  end

  let(:stig) { create(:stig) }
  # Use let! to ensure admin user is created first (before user2)
  # This prevents user2 from being promoted to admin by first-user-admin callback
  let!(:user) { create(:user, admin: true) }
  let(:user2) { create(:user) }

  describe 'GET /stigs/:id/export/:type' do
    it 'exports XCCDF XML for logged-in user' do
      sign_in user

      get "/stigs/#{stig.id}/export/xccdf"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('application/xml')
      expect(response.headers['Content-Disposition']).to include('.xml')
      expect(response.body).to eq(stig.xml)
    end

    it 'includes stig title in filename' do
      sign_in user

      get "/stigs/#{stig.id}/export/xccdf"

      filename = response.headers['Content-Disposition']
      expect(filename).to include(stig.title.tr(' ', '-'))
    end

    it 'returns error for unsupported export types' do
      sign_in user

      get "/stigs/#{stig.id}/export/inspec", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
      json = response.parsed_body
      expect(json['toast']['message']).to include('Unsupported')
    end

    it 'exports CSV for logged-in user' do
      sign_in user
      create(:stig_rule, stig: stig)

      get "/stigs/#{stig.id}/export/csv"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('.csv')
    end

    it 'includes stig title in CSV filename' do
      sign_in user

      get "/stigs/#{stig.id}/export/csv"

      filename = response.headers['Content-Disposition']
      expect(filename).to include(stig.title.tr(' ', '-'))
    end

    it 'respects column selection for CSV export' do
      sign_in user
      create(:stig_rule, stig: stig)

      get "/stigs/#{stig.id}/export/csv", params: { columns: 'rule_id,version,rule_severity' }

      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to eq(['Rule ID', 'STIG ID', 'Severity'])
    end

    it 'requires authentication' do
      get "/stigs/#{stig.id}/export/xccdf"

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'does not require admin access' do
      sign_in user2

      get "/stigs/#{stig.id}/export/xccdf"

      expect(response).to have_http_status(:ok)
    end

    it 'validates ahead of time with JSON format' do
      sign_in user

      get "/stigs/#{stig.id}/export/xccdf", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('ok')
    end

    it 'returns 404 for non-existent stig' do
      sign_in user

      get '/stigs/99999/export/xccdf'

      expect(response).to redirect_to(stigs_path)
    end
  end

  describe 'POST /stigs' do
    it 'allows admin to create a new Stig' do
      sign_in user

      # Create a temp file with STIG XML content
      temp_file = Tempfile.new(['test_stig', '.xml'])
      temp_file.write(stig.xml)
      temp_file.rewind

      # Use Rack::Test::UploadedFile for file upload
      file = Rack::Test::UploadedFile.new(temp_file.path, 'application/xml')

      expect do
        post '/stigs', params: { file: file }
      end.to change(Stig, :count).by(1)

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json['toast']).to include('Successfully added')

      temp_file.close
      temp_file.unlink
    end
  end

  describe 'DELETE /stigs/:id' do
    let!(:stig2) do
      stig_obj = Stig.from_mapping(Xccdf::Benchmark.parse(stig.xml))
      stig_obj.xml = stig.xml
      stig_obj.name = stig.name
      stig_obj.save!
      stig_obj
    end

    it 'allows admin to destroy the stig' do
      sign_in user

      expect do
        delete "/stigs/#{stig2.id}"
      end.to change(Stig, :count).by(-1)

      expect(response).to redirect_to(stigs_path)
      follow_redirect!
      expect(response.body).to include('Successfully removed')
    end

    it 'does not allow non admin to destroy the stig' do
      sign_in user2

      expect do
        delete "/stigs/#{stig2.id}"
      end.not_to change(Stig, :count)
    end

    context 'with JSON format' do
      let(:json_headers) { { 'Accept' => 'application/json' } }

      it 'returns JSON response on success' do
        sign_in user

        expect do
          delete "/stigs/#{stig2.id}", headers: json_headers
        end.to change(Stig, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
        json = response.parsed_body
        expect(json['toast']).to include('Successfully removed')
      end

      it 'returns JSON error response on failure' do
        sign_in user
        allow_any_instance_of(Stig).to receive(:destroy).and_return(false)
        allow_any_instance_of(Stig).to receive_message_chain(:errors, :full_messages).and_return(['Cannot delete'])

        delete "/stigs/#{stig2.id}", headers: json_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include('application/json')
        json = response.parsed_body
        expect(json['toast']['title']).to include('Could not remove')
      end
    end
  end
end
