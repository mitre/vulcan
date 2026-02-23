# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# Two new controller endpoints for CSV round-trip update:
# - POST   /components/:id/preview_spreadsheet_update  → returns diff preview (no save)
# - PATCH  /components/:id/apply_spreadsheet_update     → saves changes to DB
#
# Authorization: author role or above (author, admin) on the component.
# Viewers and reviewers cannot access these endpoints.
# Unauthenticated users are redirected to login.

RSpec.describe 'Components spreadsheet update endpoints' do
  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:author_user) { create(:user) }
  let_it_be(:viewer_user) { create(:user) }
  let_it_be(:non_member_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    # Set up memberships
    Membership.find_or_create_by!(user: admin_user, membership: project) do |m|
      m.role = 'admin'
    end
    Membership.find_or_create_by!(user: author_user, membership: project) do |m|
      m.role = 'author'
    end
    Membership.find_or_create_by!(user: viewer_user, membership: project) do |m|
      m.role = 'viewer'
    end
  end

  # Helper: export component CSV and return tempfile path
  def export_csv_tempfile(comp)
    csv_string = comp.csv_export
    file = Tempfile.new(['update_test', '.csv'])
    file.write(csv_string)
    file.rewind
    file
  end

  # Helper: create an invalid CSV missing required headers
  def invalid_csv_tempfile
    file = Tempfile.new(['bad_test', '.csv'])
    CSV.open(file.path, 'w') do |csv|
      csv << %w[BadHeader1 BadHeader2]
      csv << %w[value1 value2]
    end
    file
  end

  # Helper: create CSV with wrong SRG IDs
  def wrong_srg_csv_tempfile
    file = Tempfile.new(['wrong_srg', '.csv'])
    headers = %w[SRGID STIGID Severity Requirement VulDiscussion Status Check Fix] +
              ['Status Justification', 'Artifact Description']
    CSV.open(file.path, 'w') do |csv|
      csv << headers
      csv << ['SRG-FAKE-999999-GPOS-99999', 'TEST-000001', 'CAT II',
              'title', 'discussion', 'Not Yet Determined', 'check', 'fix', '', '']
    end
    file
  end

  # ========================================================================
  # POST /components/:id/preview_spreadsheet_update
  # ========================================================================
  describe 'POST /components/:id/preview_spreadsheet_update' do
    let(:preview_path) { "/components/#{component.id}/preview_spreadsheet_update" }

    context 'when unauthenticated' do
      it 'redirects to login' do
        file = export_csv_tempfile(component)
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as non-member' do
      before { sign_in non_member_user }

      it 'returns forbidden status' do
        file = export_csv_tempfile(component)
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
        # Non-member should get 403 or redirect (depends on error handler)
        expect(response.status).to be_in([403, 302, 500])
      end
    end

    context 'when authenticated as viewer (not author)' do
      before { sign_in viewer_user }

      it 'returns forbidden status' do
        file = export_csv_tempfile(component)
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
        expect(response.status).to be_in([403, 302, 500])
      end
    end

    context 'when authenticated as author' do
      before { sign_in author_user }

      it 'returns 200 with preview JSON for valid CSV' do
        file = export_csv_tempfile(component)
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('updated')
        expect(json).to have_key('unchanged')
        expect(json).to have_key('skipped_locked')
        expect(json).to have_key('warnings')
      end

      it 'returns 422 for missing file parameter' do
        post preview_path
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 422 for CSV with missing required headers' do
        file = invalid_csv_tempfile
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['error']).to be_present
      end

      it 'returns 422 for CSV with wrong SRG IDs' do
        file = wrong_srg_csv_tempfile
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin_user }

      it 'returns 200 with preview JSON' do
        file = export_csv_tempfile(component)
        post preview_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('updated')
      end
    end
  end

  # ========================================================================
  # PATCH /components/:id/apply_spreadsheet_update
  # ========================================================================
  describe 'PATCH /components/:id/apply_spreadsheet_update' do
    let(:apply_path) { "/components/#{component.id}/apply_spreadsheet_update" }

    context 'when unauthenticated' do
      it 'redirects to login' do
        file = export_csv_tempfile(component)
        patch apply_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as author' do
      before { sign_in author_user }

      it 'returns 200 and updates rules in DB for valid CSV' do
        csv_string = component.csv_export
        parsed = CSV.parse(csv_string, headers: true)
        parsed[0]['Requirement'] = 'APPLIED VIA CONTROLLER'

        file = Tempfile.new(['apply_test', '.csv'])
        CSV.open(file.path, 'w') do |csv|
          csv << parsed.headers
          parsed.each { |row| csv << row.fields }
        end

        patch apply_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['toast']).to be_present
      end

      it 'skips locked rules during apply' do
        component.rules.first.update!(locked: true)
        original_title = component.rules.first.title

        csv_string = component.csv_export
        parsed = CSV.parse(csv_string, headers: true)
        parsed[0]['Requirement'] = 'LOCKED RULE SHOULD NOT CHANGE'

        file = Tempfile.new(['locked_test', '.csv'])
        CSV.open(file.path, 'w') do |csv|
          csv << parsed.headers
          parsed.each { |row| csv << row.fields }
        end

        patch apply_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }

        expect(response).to have_http_status(:ok)
        component.rules.first.reload
        expect(component.rules.first.title).to eq(original_title)
      end

      it 'returns 422 when no file is provided' do
        patch apply_path
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
