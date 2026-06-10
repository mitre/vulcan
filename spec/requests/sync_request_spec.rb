# frozen_string_literal: true

require 'rails_helper'
require 'active_job/test_helper'

# POST /components/:id/merge enqueues a MergeJob, returns job_id.
# GET /components/:id/merge_status returns the latest ComponentSyncEvent
# (status + diagnostics).
RSpec.describe 'Sync (component merge)' do
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

  describe 'POST /components/:id/merge' do
    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'enqueues MergeJob and returns job_id + queued status' do
        expect do
          post "/components/#{component.id}/merge",
               params: { file: zip_upload('fake zip bytes') }
        end.to have_enqueued_job(MergeJob).with(
          hash_including(component_id: component.id, actor_id: admin.id)
        )

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['component_id']).to eq(component.id)
        expect(body['status']).to eq('queued')
        expect(body['job_id']).to be_present
      end

      it 'rejects requests without a file' do
        post "/components/#{component.id}/merge"
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to match(/No file provided/i)
      end

      it 'forwards strategy_overrides JSON to the MergeJob' do
        overrides = { 'rule' => { 'fixtext' => 'theirs' } }
        expect do
          post "/components/#{component.id}/merge",
               params: { file: zip_upload('fake'), strategy_overrides: overrides.to_json }
        end.to have_enqueued_job(MergeJob).with(
          hash_including(strategy_overrides: { rule: { fixtext: 'theirs' } })
        )
      end

      it 'rejects malformed strategy_overrides JSON with 400' do
        post "/components/#{component.id}/merge",
             params: { file: zip_upload('fake'), strategy_overrides: '{not json' }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to match(/strategy_overrides/i)
      end

      it 'returns 404 for an unknown component id' do
        post '/components/999999/merge', params: { file: zip_upload('fake') }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated as a viewer (non-admin)' do
      before { sign_in viewer }

      it 'is forbidden from triggering a merge' do
        post "/components/#{component.id}/merge",
             params: { file: zip_upload('fake') },
             headers: { 'ACCEPT' => 'application/json' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'redirects to sign in' do
        post "/components/#{component.id}/merge", params: { file: zip_upload('fake') }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /components/:id/merge_status' do
    before { sign_in admin }

    it 'returns 404 when the component has never been synced' do
      get "/components/#{component.id}/merge_status"
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['status']).to eq('no_sync_yet')
    end

    it 'returns the latest sync event with its status + diagnostics' do
      event = ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'pending'
      )

      get "/components/#{component.id}/merge_status", headers: { 'ACCEPT' => 'application/json' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['sync_event_id']).to eq(event.id)
      expect(body['status']).to eq('pending')
      expect(body['sync_id']).to eq(event.sync_id)
    end

    it 'surfaces failure_diagnostics_json on a failed event' do
      ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'pending'
      ).update!(
        status: 'failed',
        failure_diagnostics_json: { 'exception_class' => 'PreconditionError', 'exception_message' => 'phase open' }
      )

      get "/components/#{component.id}/merge_status", headers: { 'ACCEPT' => 'application/json' }

      expect(response.parsed_body['failure_diagnostics']).to include(
        'exception_class' => 'PreconditionError'
      )
    end
  end
end
