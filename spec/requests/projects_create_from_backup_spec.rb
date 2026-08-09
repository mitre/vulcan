# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: POST /projects/create_from_backup creates a new project from
# a JSON archive backup. Requires create permission (admin or
# create_permission_enabled). Supports dry_run for preview. Returns redirect
# URL on success, summary, and project_defaults from the archive.
# ==========================================================================
BACKUP_ENDPOINT = '/projects/create_from_backup'
BACKUP_ZIP_CONTENT_TYPE = 'application/zip'
BACKUP_RESTORED_NAME = 'Restored Project'

RSpec.describe 'Project Create From Backup' do
  # Expensive setup — created once via test-prof savepoints
  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:source_project) { create(:project) }
  let_it_be(:source_component) { create(:component, project: source_project) }

  let_it_be(:project_backup_zip_data) do
    Export::Base.new(
      exportable: source_project,
      mode: :backup,
      format: :json_archive,
      zip_filename: 'test-backup.zip'
    ).call.data
  end

  let(:uploaded_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new(project_backup_zip_data),
      BACKUP_ZIP_CONTENT_TYPE,
      true,
      original_filename: 'test-backup.zip'
    )
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'POST /projects/create_from_backup' do
    context 'when not authenticated' do
      it 'redirects to login' do
        post BACKUP_ENDPOINT, params: { file: uploaded_file }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'creates a project with given name' do
        expect do
          post BACKUP_ENDPOINT, params: {
            file: uploaded_file,
            project_name: 'My Restored Project',
            project_description: 'Restored from backup',
            project_visibility: 'discoverable'
          }
        end.to change(Project, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['redirect_url']).to be_present
        # canonical {title, message, variant} toast shape.
        expect(json['toast']).to be_a(Hash)
        expect(json['toast']['message'].join).to match(/successfully/i)
      end

      it 'imports all components from archive' do
        post BACKUP_ENDPOINT, params: {
          file: uploaded_file,
          project_name: BACKUP_RESTORED_NAME
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['summary']['components_imported']).to eq(1)
      end

      it 'creates current user as admin member' do
        post BACKUP_ENDPOINT, params: {
          file: uploaded_file,
          project_name: BACKUP_RESTORED_NAME
        }

        project = Project.find_by(name: BACKUP_RESTORED_NAME)
        membership = project.memberships.find_by(user: admin_user)
        expect(membership).to be_present
        expect(membership.role).to eq('admin')
      end

      it 'returns project_defaults in dry_run' do
        post BACKUP_ENDPOINT, params: {
          file: uploaded_file,
          dry_run: 'true'
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['project_defaults']).to be_present
        expect(json['project_defaults']['name']).to eq(source_project.name)
        expect(json['summary']).to be_present
      end

      it 'creates nothing in dry_run' do
        expect do
          post BACKUP_ENDPOINT, params: {
            file: uploaded_file,
            dry_run: 'true'
          }
        end.not_to change(Project, :count)
      end

      it 'rolls back project on import failure' do
        bad_zip = modify_manifest_srg(project_backup_zip_data, 'NONEXISTENT-SRG')
        bad_file = Rack::Test::UploadedFile.new(
          StringIO.new(bad_zip), BACKUP_ZIP_CONTENT_TYPE, true, original_filename: 'bad.zip'
        )

        expect do
          post BACKUP_ENDPOINT, params: {
            file: bad_file,
            project_name: 'Should Not Exist'
          }
        end.not_to change(Project, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'requires project_name for real import' do
        post BACKUP_ENDPOINT, params: { file: uploaded_file }
        expect(response).to have_http_status(:unprocessable_content)
      end

      # The pre-import defaults probe reads project.json from the raw
      # upload before any importer budget runs — an archive whose central
      # directory under-declares entry sizes must hit the capped reader
      # and fall through to the rescue's defaults instead of inflating
      # unbounded, then fail the real import loudly.
      it 'survives an archive whose central directory lies about sizes' do
        data = project_backup_zip_data.dup.force_encoding(Encoding::BINARY)
        # Patch the central-directory record for rules.json — a known-large
        # entry — to declare 16 bytes (uncompressed size is 4 bytes LE at
        # +24; name length at +28; name at +46 of the PK\x01\x02 record).
        target = nil
        scan = 0
        while (idx = data.index("PK\x01\x02".b, scan))
          name_len = data[idx + 28, 2].unpack1('v')
          target = idx if data[idx + 46, name_len].end_with?('rules.json')
          scan = idx + 4
        end
        raise 'fixture assumption broken: no rules.json central-directory record' unless target

        data[target + 24, 4] = [16].pack('V')
        lying_file = Rack::Test::UploadedFile.new(
          StringIO.new(data), BACKUP_ZIP_CONTENT_TYPE, true, original_filename: 'lying.zip'
        )

        expect do
          post BACKUP_ENDPOINT, params: { file: lying_file, project_name: 'Lying Archive' }
        end.not_to change(Project, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns 400 when no file provided' do
        post BACKUP_ENDPOINT
        expect(response).to have_http_status(:bad_request)
      end

      it 'handles include_reviews param' do
        Review.create!(user: admin_user, rule: source_component.rules.first,
                       action: 'request_review', comment: 'Test')

        zip = Export::Base.new(
          exportable: source_project,
          mode: :backup,
          format: :json_archive,
          zip_filename: 'test.zip'
        ).call.data
        file = Rack::Test::UploadedFile.new(
          StringIO.new(zip), BACKUP_ZIP_CONTENT_TYPE, true, original_filename: 'test.zip'
        )

        post BACKUP_ENDPOINT, params: {
          file: file,
          project_name: 'With Reviews',
          include_reviews: 'false'
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['summary']['reviews_imported']).to eq(0)
      end
    end

    context 'when authenticated as non-admin with create permission disabled' do
      before do
        allow(Settings.project).to receive(:create_permission_enabled).and_return(false)
        sign_in regular_user
      end

      it 'redirects to root (unauthorized)' do
        post BACKUP_ENDPOINT, params: {
          file: uploaded_file,
          project_name: 'Should Fail'
        }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  private

  def modify_manifest_srg(zip_data, new_srg_id)
    new_zip = Zip::OutputStream.write_buffer do |zio|
      Zip::File.open_buffer(StringIO.new(zip_data)) do |zip|
        zip.each do |entry|
          zio.put_next_entry(entry.name)
          content = zip.read(entry.name)
          if entry.name == 'manifest.json'
            manifest = JSON.parse(content)
            manifest['components'].each { |c| c['srg_id'] = new_srg_id }
            zio.write(JSON.generate(manifest))
          else
            zio.write(content)
          end
        end
      end
    end
    new_zip.string
  end
end
