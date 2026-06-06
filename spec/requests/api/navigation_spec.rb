# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Navigation' do
  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:project) { create(:project) }

  before_all do
    Membership.create!(user: regular_user, membership: project, role: 'viewer')
  end

  describe 'GET /api/navigation' do
    context 'when authenticated' do
      before { sign_in regular_user }

      it 'returns nav links array' do
        get '/api/navigation', as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['nav_links']).to be_an(Array)
        expect(body['nav_links'].first).to have_key('name')
        expect(body['nav_links'].first).to have_key('link')
      end

      it 'includes Projects, Released Components, STIGs, SRGs, Resources' do
        get '/api/navigation', as: :json

        names = response.parsed_body['nav_links'].pluck('name')
        expect(names).to include('Projects', 'Released Components', 'STIGs', 'SRGs', 'Resources')
      end

      it 'returns empty access_requests for non-admin' do
        get '/api/navigation', as: :json

        expect(response.parsed_body['access_requests']).to eq([])
      end

      it 'returns empty locked_users for non-admin' do
        get '/api/navigation', as: :json

        expect(response.parsed_body['locked_users']).to eq([])
      end
    end

    context 'when authenticated as admin' do
      before { sign_in anchor_admin }

      it 'returns access_requests for projects where admin' do
        Membership.find_or_create_by!(user: anchor_admin, membership: project, role: 'admin')
        requester = create(:user)
        ar = ProjectAccessRequest.create!(user: requester, project: project)

        get '/api/navigation', as: :json

        body = response.parsed_body
        expect(body['access_requests']).to be_an(Array)
        request_ids = body['access_requests'].pluck('id')
        expect(request_ids).to include(ar.id)
      end

      it 'returns locked_users when lockout enabled' do
        locked = create(:user)
        locked.lock_access!(send_instructions: false)

        get '/api/navigation', as: :json

        body = response.parsed_body
        expect(body['locked_users']).to be_an(Array)
        locked_ids = body['locked_users'].pluck('id')
        expect(locked_ids).to include(locked.id)
      end
    end

    context 'when not authenticated' do
      it 'returns 401' do
        get '/api/navigation', as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
