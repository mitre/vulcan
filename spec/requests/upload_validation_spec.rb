# frozen_string_literal: true

require 'rails_helper'

# Tests for upload size and content-type validation across all upload endpoints.
# REQUIREMENTS:
# - Uploads exceeding max size are rejected with 422
# - Uploads with wrong file extension are rejected with 422
# - Valid uploads pass through to normal processing

RSpec.describe 'Upload validation' do
  let(:admin) { create(:user, admin: true) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # Helper to create an uploaded file of a specific size
  def oversized_file(size_bytes, filename: 'test.xml', content_type: 'application/xml')
    content = 'x' * size_bytes
    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      content_type,
      original_filename: filename
    )
  end

  def small_file(filename: 'test.xml', content_type: 'application/xml', content: '<root/>')
    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      content_type,
      original_filename: filename
    )
  end

  describe 'STIG upload (POST /stigs)' do
    it 'rejects files exceeding 50 MB' do
      file = oversized_file(51.megabytes)
      post '/stigs', params: { file: file }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('exceeds maximum size')
    end

    it 'rejects non-XML files' do
      file = small_file(filename: 'stig.pdf', content_type: 'application/pdf')
      post '/stigs', params: { file: file }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('Invalid file type')
    end
  end

  describe 'SRG upload (POST /srgs)' do
    it 'rejects files exceeding 50 MB' do
      file = oversized_file(51.megabytes)
      post '/srgs', params: { file: file }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('exceeds maximum size')
    end

    it 'rejects non-XML files' do
      file = small_file(filename: 'srg.csv', content_type: 'text/csv')
      post '/srgs', params: { file: file }, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('Invalid file type')
    end
  end

  describe 'Backup import (POST /projects/:id/import_backup)' do
    let(:project) { create(:project) }

    before do
      create(:membership, :admin, user: admin, membership: project)
    end

    it 'rejects files exceeding 100 MB' do
      file = oversized_file(101.megabytes, filename: 'backup.zip', content_type: 'application/zip')
      post "/projects/#{project.id}/import_backup", params: { file: file },
                                                    headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('exceeds maximum size')
    end

    it 'rejects non-ZIP files' do
      file = small_file(filename: 'backup.xml', content_type: 'application/xml')
      post "/projects/#{project.id}/import_backup", params: { file: file },
                                                    headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('Invalid file type')
    end
  end

  describe 'Backup create (POST /projects/create_from_backup)' do
    it 'rejects files exceeding 100 MB' do
      file = oversized_file(101.megabytes, filename: 'backup.zip', content_type: 'application/zip')
      post '/projects/create_from_backup', params: { file: file },
                                           headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('exceeds maximum size')
    end

    it 'rejects non-ZIP files' do
      file = small_file(filename: 'backup.txt', content_type: 'text/plain')
      post '/projects/create_from_backup', params: { file: file },
                                           headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('Invalid file type')
    end
  end

  describe 'Component spreadsheet import (POST /projects/:id/components)' do
    let_it_be(:srg) { create(:security_requirements_guide) }
    let(:project) { create(:project) }

    before do
      create(:membership, :admin, user: admin, membership: project)
    end

    it 'rejects files exceeding 50 MB' do
      file = oversized_file(51.megabytes, filename: 'import.xlsx',
                                          content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      post "/projects/#{project.id}/components",
           params: { component: { file: file, name: 'Test', prefix: 'TEST-00', title: 'Test',
                                  security_requirements_guide_id: srg.id } },
           headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('exceeds maximum size')
    end

    it 'rejects non-spreadsheet files' do
      file = small_file(filename: 'import.xml', content_type: 'application/xml')
      post "/projects/#{project.id}/components",
           params: { component: { file: file, name: 'Test', prefix: 'TEST-00', title: 'Test',
                                  security_requirements_guide_id: srg.id } },
           headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'message')).to include('Invalid file type')
    end
  end
end
