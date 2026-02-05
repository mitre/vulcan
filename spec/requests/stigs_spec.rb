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
