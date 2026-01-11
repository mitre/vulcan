# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::Projects', type: :request do
  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/projects/:id/search_users' do
    let(:admin_user) { create(:user, admin: true) }
    let(:member_user) { create(:user, email: 'member@example.com', name: 'Member User') }
    let(:other_user) { create(:user, email: 'other@example.com', name: 'Other User') }
    let(:existing_member) { create(:user, email: 'existing@example.com', name: 'Existing Member') }
    let(:project) { create(:project) }

    before do
      # Add existing_member to the project
      create(:membership, membership: project, user: existing_member, role: 'viewer')
    end

    context 'when not authenticated' do
      it 'returns 401 Unauthorized' do
        get "/api/projects/#{project.id}/search_users", params: { q: 'test' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as non-admin project member' do
      before do
        # Add member to project so authorization check can happen
        create(:membership, membership: project, user: member_user, role: 'viewer')
        sign_in member_user
      end

      it 'returns 403 forbidden' do
        get "/api/projects/#{project.id}/search_users", params: { q: 'test' }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as project admin' do
      before do
        create(:membership, membership: project, user: admin_user, role: 'admin')
        sign_in admin_user
      end

      it 'searches users by email' do
        # Force lazy load to create users
        other_user

        get "/api/projects/#{project.id}/search_users", params: { q: 'other@' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(/application\/json/)

        json = JSON.parse(response.body)
        expect(json['users']).to be_an(Array)
        expect(json['users'].length).to eq(1)
        expect(json['users'].first['email']).to eq('other@example.com')
      end

      it 'searches users by name' do
        # Force lazy load
        other_user

        get "/api/projects/#{project.id}/search_users", params: { q: 'Other' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['users'].first['name']).to eq('Other User')
      end

      it 'excludes existing project members' do
        # Force lazy load
        existing_member

        get "/api/projects/#{project.id}/search_users", params: { q: 'existing' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['users']).to be_empty
      end

      it 'shows first 10 users on empty query (Slack model)' do
        # Create some users
        5.times do |i|
          create(:user, email: "user#{i}@example.com", name: "User #{i}")
        end

        get "/api/projects/#{project.id}/search_users", params: { q: '' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['users'].length).to eq(5)
      end

      it 'shows first 10 users on short query (< 2 chars)' do
        # Create some users
        3.times do |i|
          create(:user, email: "abc#{i}@example.com", name: "ABC User #{i}")
        end

        get "/api/projects/#{project.id}/search_users", params: { q: 'a' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Should show all 3 users (not filtering, just showing first 10)
        expect(json['users'].length).to eq(3)
      end

      it 'limits results to 10' do
        # Create 15 users with valid emails
        15.times do |i|
          create(:user, email: "testuser#{i}@example.com", name: "Test User #{i}")
        end

        get "/api/projects/#{project.id}/search_users", params: { q: 'test' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['users'].length).to eq(10)
      end

      it 'returns user id, name, and email' do
        # Force lazy load
        other_user

        get "/api/projects/#{project.id}/search_users", params: { q: 'other' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        user = json['users'].first
        expect(user).to have_key('id')
        expect(user).to have_key('name')
        expect(user).to have_key('email')
      end
    end

    context 'when authenticated as global admin (non-member)' do
      before do
        sign_in admin_user
      end

      it 'allows search (global admins can manage all projects)' do
        get "/api/projects/#{project.id}/search_users", params: { q: 'other' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
