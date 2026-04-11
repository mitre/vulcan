# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API User Search' do
  let_it_be(:admin) { create(:user, admin: false) }
  let_it_be(:viewer) { create(:user, admin: false) }
  let_it_be(:project) { create(:project) }
  let_it_be(:searchable_user) { create(:user, name: 'Jane Findable', email: 'jane.findable@example.com') }
  let_it_be(:other_user) { create(:user, name: 'Bob Visible', email: 'bob.visible@example.com') }

  before_all do
    Membership.create!(user: admin, membership: project, role: 'admin')
    Membership.create!(user: viewer, membership: project, role: 'viewer')
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/users/search' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/users/search', params: { q: 'jane', membership_type: 'Project', membership_id: project.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as project viewer (not admin)' do
      before { sign_in viewer }

      it 'returns 403' do
        get '/api/users/search', params: { q: 'jane', membership_type: 'Project', membership_id: project.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as project admin' do
      before { sign_in admin }

      it 'returns matching users by name' do
        get '/api/users/search', params: { q: 'Findable', membership_type: 'Project', membership_id: project.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        emails = json['users'].pluck('email')
        expect(emails).to include('jane.findable@example.com')
      end

      it 'returns matching users by email' do
        get '/api/users/search', params: { q: 'bob.visible', membership_type: 'Project', membership_id: project.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        emails = json['users'].pluck('email')
        expect(emails).to include('bob.visible@example.com')
      end

      it 'excludes users who are already project members' do
        get '/api/users/search', params: { q: admin.email.split('@').first, membership_type: 'Project', membership_id: project.id }

        json = response.parsed_body
        ids = json['users'].pluck('id')
        expect(ids).not_to include(admin.id)
        expect(ids).not_to include(viewer.id)
      end

      it 'returns empty array for queries shorter than 2 characters' do
        get '/api/users/search', params: { q: 'j', membership_type: 'Project', membership_id: project.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['users']).to eq([])
      end

      it 'respects the limit parameter' do
        get '/api/users/search', params: { q: 'example', membership_type: 'Project', membership_id: project.id, limit: 1 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['users'].length).to be <= 1
      end

      it 'returns 404 for non-existent project' do
        get '/api/users/search', params: { q: 'jane', membership_type: 'Project', membership_id: 999_999 }

        expect(response).to have_http_status(:not_found)
      end

      it 'only returns id, name, and email' do
        get '/api/users/search', params: { q: 'Findable', membership_type: 'Project', membership_id: project.id }

        json = response.parsed_body
        user = json['users'].find { |u| u['email'] == 'jane.findable@example.com' }
        expect(user.keys).to contain_exactly('id', 'name', 'email')
      end
    end

    context 'when authenticated as site admin' do
      let_it_be(:site_admin) { create(:user, admin: true) }

      before { sign_in site_admin }

      it 'can search for any project' do
        get '/api/users/search', params: { q: 'Findable', membership_type: 'Project', membership_id: project.id }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['users']).not_to be_empty
      end
    end

    context 'with scope=members' do
      before { sign_in admin }

      it 'returns only existing project members matching the query' do
        get '/api/users/search', params: {
          q: admin.name.split.first,
          membership_type: 'Project',
          membership_id: project.id,
          scope: 'members'
        }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        ids = json['users'].map { |u| u['id'] }
        # admin and viewer are members — should find admin
        expect(ids).to include(admin.id)
        # searchable_user is NOT a member — should be excluded
        expect(ids).not_to include(searchable_user.id)
      end

      it 'does not return non-members even if name matches' do
        get '/api/users/search', params: {
          q: 'Findable',
          membership_type: 'Project',
          membership_id: project.id,
          scope: 'members'
        }

        json = response.parsed_body
        ids = json['users'].map { |u| u['id'] }
        expect(ids).not_to include(searchable_user.id)
      end

      it 'allows any project member to search members (not just admins)' do
        sign_in viewer

        get '/api/users/search', params: {
          q: admin.name.split.first,
          membership_type: 'Project',
          membership_id: project.id,
          scope: 'members'
        }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
