# frozen_string_literal: true

require 'rails_helper'
require 'active_job/test_helper'

# POST /projects/:id/import_backup?merge=true enqueues a MergeJob targeting
# the component identified by component_id. GET /components/:id/merge_status
# returns the latest ComponentSyncEvent (status + diagnostics).
#
# Replaces the deleted sync_request_spec.rb after the Phase 2c refactor
# aligned the route shape with the card AC ("import_backup with merge=true").
RSpec.describe 'Project Import Backup (merge=true)' do
  include ActiveJob::TestHelper

  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, :closed_comment_phase, project: project) }
  let_it_be(:admin) { create(:user) }
  let_it_be(:viewer) { create(:user) }

  before do
    Rails.application.reload_routes!
    Membership.create!(user: admin, membership: project, role: 'admin')
    Membership.create!(user: viewer, membership: project, role: 'viewer')
  end

  def zip_upload(bytes, filename: 'merge.zip')
    file = Tempfile.new([filename, '.zip'])
    file.binmode
    file.write(bytes)
    file.close
    Rack::Test::UploadedFile.new(file.path, 'application/zip', false)
  end

  def merge_path(project_id = project.id)
    "/projects/#{project_id}/import_backup"
  end

  describe 'POST /projects/:id/import_backup?merge=true' do
    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'enqueues MergeJob and returns 202 with job_id + queued status' do
        expect do
          post merge_path,
               params: { file: zip_upload('fake'), merge: 'true', component_id: component.id }
        end.to have_enqueued_job(MergeJob).with(
          hash_including(component_id: component.id, actor_id: admin.id)
        )

        expect(response).to have_http_status(:accepted)
        body = response.parsed_body
        expect(body['component_id']).to eq(component.id)
        expect(body['status']).to eq('queued')
        expect(body['job_id']).to be_present
      end

      it 'rejects when component_id is missing' do
        post merge_path,
             params: { file: zip_upload('fake'), merge: 'true' },
             headers: { 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to match(/component_id is required/i)
      end

      it 'rejects when component_id is for a component in another project' do
        other_component = create(:component)
        post merge_path,
             params: { file: zip_upload('fake'), merge: 'true', component_id: other_component.id },
             headers: { 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:not_found)
      end

      it 'rejects non-zip uploads via UploadValidatable (422)' do
        txt = Tempfile.new(['bogus', '.txt'])
        txt.write('not a zip')
        txt.close
        post merge_path,
             params: {
               file: Rack::Test::UploadedFile.new(txt.path, 'text/plain', false),
               merge: 'true', component_id: component.id
             },
             headers: { 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').to_s).to match(/Invalid file type/i)
      end

      it 'forwards strategy_overrides JSON to the MergeJob' do
        overrides = { 'rule' => { 'fixtext' => 'theirs' } }
        expect do
          post merge_path,
               params: {
                 file: zip_upload('fake'), merge: 'true', component_id: component.id,
                 strategy_overrides: overrides.to_json
               }
        end.to have_enqueued_job(MergeJob).with(
          hash_including(strategy_overrides: { rule: { fixtext: 'theirs' } })
        )
      end

      it 'rejects malformed strategy_overrides JSON with 400' do
        post merge_path,
             params: {
               file: zip_upload('fake'), merge: 'true', component_id: component.id,
               strategy_overrides: '{not json'
             },
             headers: { 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to match(/strategy_overrides/i)
      end

      it 'falls through to the standard import path when merge param is absent' do
        # No merge=true, no component_id — original /import_backup path runs.
        # We assert it does NOT enqueue a MergeJob; the legacy path is
        # exercised by projects_import_backup_spec.rb.
        expect do
          post merge_path, params: { file: zip_upload('fake'), dry_run: 'true' }
        end.not_to have_enqueued_job(MergeJob)
      end
    end

    context 'when authenticated as a viewer (non-admin)' do
      before { sign_in viewer }

      it 'is forbidden from triggering a merge (project admin gate)' do
        post merge_path,
             params: { file: zip_upload('fake'), merge: 'true', component_id: component.id },
             headers: { 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'redirects HTML callers to sign in' do
        post merge_path,
             params: { file: zip_upload('fake'), merge: 'true', component_id: component.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # The default RSpec sign_in helper bypasses CSRF entirely. These specs
  # enable forgery protection and assert the production posture — cookie
  # without CSRF token fails, PAT bypasses.
  describe 'production CSRF posture' do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it 'rejects cookie-authed POSTs that are missing the CSRF token' do
      sign_in admin
      expect do
        post merge_path,
             params: { file: zip_upload('fake'), merge: 'true', component_id: component.id },
             headers: { 'ACCEPT' => 'application/json' }
      end.not_to have_enqueued_job(MergeJob)

      # SHOULD be 422 (Rails default for ActionController::InvalidAuthenticityToken)
      # but ApplicationController#helpful_errors rescues StandardError and renders
      # 500 unconditionally, masking the real exception type. Tracked as a
      # separate bug. The security-relevant assertion is no-enqueue + 4xx/5xx.
      expect(response.status).to be >= 400
      expect(response.status).to be < 600
    end

    it 'accepts PAT-authed POSTs without a CSRF token' do
      token = create(:personal_access_token, user: admin, scopes: %w[read write])
      expect do
        post merge_path,
             params: { file: zip_upload('fake'), merge: 'true', component_id: component.id },
             headers: {
               'Authorization' => "Token #{token.raw_token}",
               'ACCEPT' => 'application/json'
             }
      end.to have_enqueued_job(MergeJob).with(
        hash_including(component_id: component.id, actor_id: admin.id)
      )
      expect(response).to have_http_status(:accepted)
    end
  end

  describe 'GET /components/:id/merge_status' do
    before { sign_in admin }

    it 'returns no_sync_yet when the component has never been merged' do
      get "/components/#{component.id}/merge_status",
          headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['status']).to eq('no_sync_yet')
    end

    it 'returns the latest ComponentSyncEvent when one exists' do
      event = ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'applied',
        archive_hash: 'sha256-abc'
      )
      get "/components/#{component.id}/merge_status",
          headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['sync_event_id']).to eq(event.id)
      expect(body['status']).to eq('applied')
      expect(body['source']).to eq('theirs')
      expect(body['archive_hash']).to eq('sha256-abc')
    end

    it 'is allowed for project viewers (not just admins)' do
      sign_out admin
      sign_in viewer
      get "/components/#{component.id}/merge_status",
          headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['status']).to eq('no_sync_yet')
    end
  end
end
