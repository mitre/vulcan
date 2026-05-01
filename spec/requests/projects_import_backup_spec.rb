# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: POST /projects/:id/import_backup restores a JSON archive
# backup into a project. Requires admin role. Supports dry_run and
# include_reviews params. Returns JSON with toast message, summary, warnings.
# ==========================================================================
IMPORT_ZIP_CONTENT_TYPE = 'application/zip'

RSpec.describe 'Project Import Backup' do
  let(:admin_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:non_member_user) { create(:user) }
  let(:project) { create(:project) }
  let(:source_project) { create(:project) }
  let(:source_component) { create(:component, project: source_project) }

  let(:backup_zip_data) do
    Export::Base.new(
      exportable: source_component,
      mode: :backup,
      format: :json_archive
    ).call.data
  end

  let(:uploaded_file) do
    Rack::Test::UploadedFile.new(
      StringIO.new(backup_zip_data),
      IMPORT_ZIP_CONTENT_TYPE,
      true,
      original_filename: 'backup.zip'
    )
  end

  before do
    Rails.application.reload_routes!
    Membership.create!(user: admin_user, membership: project, role: 'admin')
    Membership.create!(user: viewer_user, membership: project, role: 'viewer')
  end

  # ---------- Authorization ----------

  describe 'authorization' do
    it 'requires authentication' do
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects non-members' do
      sign_in non_member_user
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }
      expect(response).to have_http_status(:found) # redirected
    end

    it 'rejects viewers (non-admin members)' do
      sign_in viewer_user
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }
      expect(response).to have_http_status(:found) # redirected
    end

    it 'allows admin members' do
      sign_in admin_user
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }
      expect(response).to have_http_status(:success)
    end
  end

  # ---------- Parameter handling ----------

  describe 'parameter handling' do
    before { sign_in admin_user }

    it 'returns 400 when no file provided' do
      post "/projects/#{project.id}/import_backup"
      expect(response).to have_http_status(:bad_request)

      body = response.parsed_body
      expect(body['toast']['title']).to eq('Import error')
      expect(body['toast']['message']).to eq('No file provided')
    end
  end

  # ---------- Successful import ----------

  describe 'successful import' do
    before { sign_in admin_user }

    it 'returns 200 with toast and summary' do
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['toast']).to eq('Backup restored successfully.')
      expect(body['summary']['components_imported']).to eq(1)
      expect(body['summary']['rules_imported']).to eq(source_component.rules.count)
    end

    it 'creates the component in the target project' do
      expect do
        post "/projects/#{project.id}/import_backup",
             params: { file: uploaded_file }
      end.to change(project.components, :count).by(1)
    end
  end

  # ---------- Dry run ----------

  describe 'dry run' do
    before do
      sign_in admin_user
      # Force eager evaluation to avoid source_component creation inside expect{}
      uploaded_file
    end

    it 'creates no records when dry_run=true' do
      expect do
        post "/projects/#{project.id}/import_backup",
             params: { file: uploaded_file, dry_run: 'true' }
      end.not_to change(Component, :count)
    end

    it 'returns dry run toast message' do
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file, dry_run: 'true' }

      body = response.parsed_body
      expect(body['toast']).to eq('Dry run complete. No records were created.')
      expect(body['summary']['dry_run']).to be true
    end
  end

  # ---------- Include reviews parameter ----------

  describe 'include_reviews parameter' do
    before do
      sign_in admin_user
      # Add a review to the source component
      rule = source_component.rules.first
      Review.create!(user: admin_user, rule: rule, action: 'request_review', comment: 'Test')
    end

    it 'includes reviews by default' do
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }

      body = response.parsed_body
      expect(body['summary']['reviews_imported']).to eq(1)
    end

    it 'excludes reviews when include_reviews=false' do
      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file, include_reviews: 'false' }

      body = response.parsed_body
      expect(body['summary']['reviews_imported']).to eq(0)
    end
  end

  # ---------- Include memberships parameter ----------

  describe 'include_memberships parameter' do
    let(:member_user) { create(:user) }

    let(:project_backup_zip_data) do
      Membership.create!(user: member_user, membership: source_project, role: 'author')
      source_component # ensure exists
      Export::Base.new(
        exportable: source_project,
        mode: :backup,
        format: :json_archive,
        zip_filename: 'test-backup.zip'
      ).call.data
    end

    let(:project_uploaded_file) do
      Rack::Test::UploadedFile.new(
        StringIO.new(project_backup_zip_data),
        IMPORT_ZIP_CONTENT_TYPE,
        true,
        original_filename: 'project-backup.zip'
      )
    end

    before { sign_in admin_user }

    it 'skips memberships by default' do
      post "/projects/#{project.id}/import_backup",
           params: { file: project_uploaded_file }

      body = response.parsed_body
      expect(body['summary']['memberships_imported']).to eq(0)
    end

    it 'imports memberships when include_memberships=true' do
      post "/projects/#{project.id}/import_backup",
           params: { file: project_uploaded_file, include_memberships: 'true' }

      body = response.parsed_body
      expect(body['summary']['memberships_imported']).to eq(1)
    end
  end

  # ---------- Error responses ----------

  describe 'error handling' do
    before { sign_in admin_user }

    it 'returns 422 with error toast for invalid ZIP' do
      invalid_file = Rack::Test::UploadedFile.new(
        StringIO.new('not a zip'),
        IMPORT_ZIP_CONTENT_TYPE,
        true,
        original_filename: 'bad.zip'
      )

      post "/projects/#{project.id}/import_backup",
           params: { file: invalid_file }

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body['toast']['title']).to eq('Import failed')
      expect(body['toast']['variant']).to eq('danger')
    end

    it 'returns 422 when component name conflicts' do
      # Create a component with same name as source
      create(:component, project: project, name: source_component.name,
                         based_on: source_component.based_on)

      post "/projects/#{project.id}/import_backup",
           params: { file: uploaded_file }

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body['toast']['message']).to match(/already exists/)
    end
  end
end
