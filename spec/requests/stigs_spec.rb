# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stigs', type: :request do
  before do
    Rails.application.reload_routes!
  end

  let(:stig) { create(:stig) }
  let(:user) { create(:user, admin: true) }
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
  end
end
